#!/bin/bash
#
# Egregore - Complete Uninstall Script
# Removes everything except Docker images
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Banner
print_banner() {
    echo ""
    echo -e "${RED}${BOLD}"
    echo "    ███████╗ ██████╗ ██████╗ ███████╗ ██████╗  ██████╗ ██████╗ ███████╗"
    echo "    ██╔════╝██╔════╝ ██╔══██╗██╔════╝██╔═══██╗██╔═══██╗██╔══██╗██╔════╝"
    echo "    █████╗  ██║  ███╗██████╔╝█████╗  ██║   ██║██║   ██║██████╔╝█████╗  "
    echo "    ██╔══╝  ██║   ██║██╔══██╗██╔══╝  ██║   ██║██║   ██║██╔══██╗██╔══╝  "
    echo "    ███████╗╚██████╔╝██║  ██║███████╗╚██████╔╝╚██████╔╝██║  ██║███████╗"
    echo "    ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚══════╝"
    echo -e "${NC}"
    echo -e "${RED}${BOLD}              Complete Uninstall${NC}"
    echo ""
}

# Helper functions
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

step() {
    echo ""
    echo -e "${CYAN}${BOLD}▶ $1${NC}"
}

# Confirm uninstallation
confirm_uninstall() {
    echo ""
    echo -e "${YELLOW}${BOLD}⚠️  WARNING: This will COMPLETELY REMOVE Egregore${NC}"
    echo ""
    echo "This script will delete:"
    echo "  • SSE server processes (new and old stdio versions)"
    echo "  • Docker containers (not images)"
    echo "  • MCP configuration from ~/.claude.json (both stdio and sse)"
    echo "  • All memory data (Qdrant volumes + Kuzu DB)"
    echo "  • EGREGORE section from CLAUDE.md (preserves rest of file)"
    echo "  • ~/.claude/memory/MEMORY.md"
    echo "  • Python virtual environment (.venv)"
    echo "  • Configuration file (.env)"
    echo "  • Temporary files and logs"
    echo ""
    echo -e "${GREEN}Docker images will NOT be deleted${NC}"
    echo ""
    echo -e "${RED}This action cannot be undone!${NC}"
    echo ""

    read -rp "Are you sure you want to completely uninstall Egregore? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Uninstall cancelled."
        exit 0
    fi
}

# Stop all Egregore processes (SSE and old stdio)
stop_server() {
    step "Stopping All Egregore Processes"

    # Try CLI first (new SSE version)
    if command -v egregore-server >/dev/null 2>&1; then
        info "Stopping server via CLI..."
        egregore-server stop 2>/dev/null || true
    fi

    # Kill any SSE server processes by PID file
    if [ -f "/tmp/egregore.pid" ]; then
        local pid
        pid=$(cat /tmp/egregore.pid 2>/dev/null)
        if [ -n "$pid" ]; then
            info "Killing SSE server process $pid..."
            kill "$pid" 2>/dev/null || true
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
        fi
        rm -f /tmp/egregore.pid
    fi

    # Kill any old stdio processes (search for server.py with egregore)
    info "Searching for old stdio server processes..."
    local old_pids
    old_pids=$(ps aux | grep -E "egregore.*server\.py|server\.py.*egregore" | grep -v grep | awk '{print $2}' || true)
    if [ -n "$old_pids" ]; then
        echo "$old_pids" | while read -r pid; do
            if [ -n "$pid" ]; then
                info "Killing old stdio process $pid..."
                kill -9 "$pid" 2>/dev/null || true
            fi
        done
    fi

    # Remove lock and log files
    rm -f /tmp/egregore.lock
    rm -f /tmp/egregore.log

    success "All Egregore processes stopped"
}

# Stop and remove Docker containers (keep images)
stop_docker() {
    step "Removing Docker Containers"

    if [ -f "docker-compose.yml" ]; then
        # Stop and remove containers, but NOT volumes yet
        docker compose down 2>/dev/null || true
        success "Docker containers stopped"
    else
        warn "docker-compose.yml not found"
    fi

    # Also remove any egregore containers if they exist
    docker rm -f egregore-qdrant egregore-memgraph 2>/dev/null || true
}

# Remove all data volumes
remove_all_data() {
    step "Removing All Data"

    # Remove Docker volumes
    info "Removing Docker volumes..."
    docker compose down -v 2>/dev/null || true
    docker volume rm egregore_qdrant_data egregore_memgraph_data 2>/dev/null || true

    # Remove Kuzu database
    info "Removing Kuzu database..."
    rm -rf /tmp/egregore_kuzu.db 2>/dev/null || true

    success "All data removed (memories, vectors, graph data)"
}

# Remove MCP configuration (both stdio and sse versions)
remove_mcp_config() {
    step "Removing MCP Configuration"

    local claude_config="$HOME/.claude.json"

    if [ -f "$claude_config" ]; then
        if command -v jq >/dev/null 2>&1; then
            # Remove egregore from mcpServers (handles both stdio and sse)
            jq 'del(.mcpServers.egregore)' "$claude_config" > "${claude_config}.tmp" 2>/dev/null && \
                mv "${claude_config}.tmp" "$claude_config"

            # If mcpServers is empty, remove it entirely
            local mcp_count
            mcp_count=$(jq '.mcpServers | length' "$claude_config" 2>/dev/null || echo "0")
            if [ "$mcp_count" = "0" ]; then
                jq 'del(.mcpServers)' "$claude_config" > "${claude_config}.tmp" && \
                    mv "${claude_config}.tmp" "$claude_config"
            fi
        else
            python3 << PYTHON_EOF 2>/dev/null || true
import json
import os

config_file = "$claude_config"

if os.path.exists(config_file):
    with open(config_file, 'r') as f:
        config = json.load(f)

    if 'mcpServers' in config and 'egregore' in config['mcpServers']:
        del config['mcpServers']['egregore']

        if not config['mcpServers']:
            del config['mcpServers']

        with open(config_file, 'w') as f:
            json.dump(config, f, indent=2)
PYTHON_EOF
        fi
        success "MCP configuration removed (both stdio and sse)"
    else
        warn "No ~/.claude.json found"
    fi

    # Also remove backup if exists
    rm -f "$HOME/.claude.json.backup"
}

# Remove EGREGORE section from CLAUDE.md (preserve rest of file)
clean_claude_md() {
    step "Cleaning CLAUDE.md"

    local claude_md="$HOME/.claude/CLAUDE.md"
    local project_claude_md="CLAUDE.md"

    # Function to remove EGREGORE section from a file
    remove_egregore_section() {
        local file="$1"
        if [ ! -f "$file" ]; then
            return
        fi

        # Check if file contains EGREGORE PROTOCOL
        if ! grep -q "EGREGORE PROTOCOL" "$file"; then
            info "No EGREGORE section found in $file"
            return
        fi

        # Create temporary file
        local tmp_file="${file}.tmp"

        # Use Python to remove just the EGREGORE section
        python3 << PYTHON_EOF 2>/dev/null || true
import re

file_path = "$file"
tmp_path = "$tmp_file"

try:
    with open(file_path, 'r') as f:
        content = f.read()

    # Pattern to match EGREGORE PROTOCOL section (from heading to next major heading or end)
    # Matches from "# EGREGORE PROTOCOL" until next "# " or end of file
    pattern = r'# EGREGORE PROTOCOL.*?\n(?=# [^#]|\Z)'

    # Alternative: remove from EGREGORE heading to empty line before next section
    lines = content.split('\n')
    result_lines = []
    in_egregore = False
    egregore_started = False

    for i, line in enumerate(lines):
        # Check if this is the start of EGREGORE section
        if line.strip().startswith('# EGREGORE PROTOCOL'):
            in_egregore = True
            egregore_started = True
            continue

        # Check if we're in EGREGORE section and hit next major section
        if in_egregore:
            # If we hit a new main heading (single #), stop skipping
            if line.strip().startswith('# ') and not line.strip().startswith('##'):
                in_egregore = False
            # If we hit a blank line followed by a main section, stop
            elif i + 1 < len(lines) and line.strip() == '' and lines[i + 1].strip().startswith('# ') and not lines[i + 1].strip().startswith('##'):
                in_egregore = False
                continue

        if not in_egregore:
            result_lines.append(line)

    # Remove trailing empty lines
    while result_lines and result_lines[-1].strip() == '':
        result_lines.pop()

    new_content = '\n'.join(result_lines)

    # Clean up multiple consecutive blank lines
    new_content = re.sub(r'\n{3,}', '\n\n', new_content)

    with open(tmp_path, 'w') as f:
        f.write(new_content)

    import shutil
    shutil.move(tmp_path, file_path)
    print(f"Removed EGREGORE section from {file_path}")
except Exception as e:
    print(f"Error processing {file_path}: {e}")
PYTHON_EOF

        if [ -f "$tmp_file" ]; then
            rm -f "$tmp_file"
        fi
    }

    # Clean both files
    remove_egregore_section "$claude_md"
    remove_egregore_section "$project_claude_md"

    success "CLAUDE.md cleaned (EGREGORE section removed)"
}

# Remove MEMORY.md from .claude/memory/
remove_memory_md() {
    step "Removing MEMORY.md"

    local memory_md="$HOME/.claude/memory/MEMORY.md"

    if [ -f "$memory_md" ]; then
        rm -f "$memory_md"
        success "MEMORY.md removed"
    else
        info "No MEMORY.md found"
    fi

    # Also try to remove the directory if empty
    rmdir "$HOME/.claude/memory" 2>/dev/null || true
}

# Remove virtual environment
remove_venv() {
    step "Removing Virtual Environment"

    if [ -d ".venv" ]; then
        rm -rf .venv
        success "Virtual environment removed (.venv)"
    else
        warn "No virtual environment found"
    fi
}

# Remove .env file
remove_env() {
    step "Removing Configuration Files"

    if [ -f ".env" ]; then
        rm -f .env
        success ".env removed"
    else
        warn "No .env file found"
    fi
}

# Clean up any remaining files
cleanup_remaining() {
    step "Final Cleanup"

    # Remove uv.lock if it exists
    rm -f uv.lock

    # Remove __pycache__ directories
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true

    # Remove .pytest_cache
    rm -rf .pytest_cache 2>/dev/null || true

    # Remove old egregore directories if they exist in home
    rm -rf "$HOME/.egregore" 2>/dev/null || true

    success "Cleanup complete"
}

# Show final message
show_completion() {
    echo ""
    echo -e "${GREEN}${BOLD}✓ Egregore has been completely uninstalled${NC}"
    echo ""
    echo -e "${BOLD}Removed:${NC}"
    echo "  ✓ All Egregore server processes (stdio and SSE)"
    echo "  ✓ Docker containers"
    echo "  ✓ All memory data (Qdrant volumes + Kuzu DB)"
    echo "  ✓ MCP configuration (stdio and sse)"
    echo "  ✓ EGREGORE section from CLAUDE.md"
    echo "  ✓ MEMORY.md"
    echo "  ✓ Python virtual environment"
    echo "  ✓ Configuration files (.env)"
    echo "  ✓ Temporary files"
    echo ""
    echo -e "${BOLD}Preserved (Docker images):${NC}"
    echo "  • qdrant/qdrant:latest (can be removed with: docker image prune)"
    echo ""
    echo -e "${CYAN}To finish removal, delete this directory:${NC}"
    echo "  cd .. && rm -rf $(basename "$PWD")"
    echo ""
}

# Main function
main() {
    print_banner
    confirm_uninstall

    # Check if in project directory
    if [ ! -f "pyproject.toml" ]; then
        warn "pyproject.toml not found. Make sure you're in the Egregore project directory."
        exit 1
    fi

    stop_server
    stop_docker
    remove_all_data
    remove_mcp_config
    clean_claude_md
    remove_memory_md
    remove_venv
    remove_env
    cleanup_remaining

    show_completion
}

# Run main function
main "$@"
