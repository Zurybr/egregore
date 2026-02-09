#!/bin/bash
#
# Egregore - Hive Mind Memory System Uninstall Script
# Completely removes Egregore from the system
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
    echo -e "${RED}${BOLD}              Uninstall Script${NC}"
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
    echo -e "${YELLOW}${BOLD}⚠️  WARNING: This will completely remove Egregore${NC}"
    echo ""
    echo "This script will:"
    echo "  1. Stop the Egregore SSE server"
    echo "  2. Stop Docker containers (Memgraph + Qdrant)"
    echo "  3. Remove MCP configuration from ~/.claude.json"
    echo "  4. Optionally delete all memory data (graph + vectors)"
    echo "  5. Optionally remove the virtual environment"
    echo ""
    echo -e "${RED}This action cannot be undone!${NC}"
    echo ""

    read -rp "Are you sure you want to uninstall Egregore? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Uninstall cancelled."
        exit 0
    fi
}

# Stop the SSE server
stop_server() {
    step "Stopping Egregore SSE Server"

    if command -v egregore-server >/dev/null 2>&1; then
        info "Stopping server via CLI..."
        egregore-server stop 2>/dev/null || true
    fi

    # Kill any remaining processes
    if [ -f "/tmp/egregore.pid" ]; then
        local pid
        pid=$(cat /tmp/egregore.pid 2>/dev/null)
        if [ -n "$pid" ]; then
            info "Killing process $pid..."
            kill "$pid" 2>/dev/null || true
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
        fi
        rm -f /tmp/egregore.pid
    fi

    # Remove lock file
    rm -f /tmp/egregore.lock

    success "Server stopped"
}

# Stop Docker containers
stop_docker() {
    step "Stopping Docker Infrastructure"

    if [ -f "docker-compose.yml" ]; then
        info "Stopping containers..."
        docker compose down 2>/dev/null || true
        success "Containers stopped"
    else
        warn "docker-compose.yml not found"
    fi
}

# Remove MCP configuration
remove_mcp_config() {
    step "Removing MCP Configuration"

    local claude_config="$HOME/.claude.json"
    local claude_backup="$HOME/.claude.json.backup"

    if [ -f "$claude_config" ]; then
        info "Removing Egregore from ~/.claude.json..."

        if command -v jq >/dev/null 2>&1; then
            # Remove egregore from mcpServers
            jq 'del(.mcpServers.egregore)' "$claude_config" > "${claude_config}.tmp" 2>/dev/null || true

            if [ -f "${claude_config}.tmp" ]; then
                # Check if mcpServers is now empty
                local mcp_count
                mcp_count=$(jq '.mcpServers | length' "${claude_config}.tmp")

                if [ "$mcp_count" = "0" ]; then
                    # Remove mcpServers entirely if empty
                    jq 'del(.mcpServers)' "${claude_config}.tmp" > "$claude_config"
                else
                    mv "${claude_config}.tmp" "$claude_config"
                fi

                rm -f "${claude_config}.tmp"
            fi
        else
            # Fallback: use Python
            python3 << PYTHON_EOF 2>/dev/null || true
import json
import os

config_file = "$claude_config"

if os.path.exists(config_file):
    with open(config_file, 'r') as f:
        config = json.load(f)

    if 'mcpServers' in config and 'egregore' in config['mcpServers']:
        del config['mcpServers']['egregore']

        # Remove mcpServers if empty
        if not config['mcpServers']:
            del config['mcpServers']

        with open(config_file, 'w') as f:
            json.dump(config, f, indent=2)
PYTHON_EOF
        fi

        # Remove backup if exists
        rm -f "$claude_backup"

        success "MCP configuration removed"
    else
        warn "No ~/.claude.json found"
    fi
}

# Optionally remove data volumes
remove_data() {
    step "Data Removal"

    echo ""
    echo -e "${YELLOW}Do you want to delete all memory data?${NC}"
    echo "  This includes:"
    echo "    - All stored memories (graph data in Memgraph)"
    echo "    - All vector embeddings (in Qdrant)"
    echo "    - Docker volumes"
    echo ""

    read -rp "Delete all memory data? [y/N]: " delete_data

    if [[ "$delete_data" =~ ^[Yy]$ ]]; then
        info "Removing Docker volumes..."
        docker compose down -v 2>/dev/null || true

        # Also try to remove named volumes directly
        docker volume rm memoria_memgraph-data memoria_qdrant-storage 2>/dev/null || true

        success "All memory data deleted"
    else
        info "Memory data preserved"
        echo "  You can delete it later with: docker compose down -v"
    fi
}

# Optionally remove virtual environment
remove_venv() {
    step "Virtual Environment"

    if [ -d ".venv" ]; then
        echo ""
        read -rp "Remove Python virtual environment (.venv)? [y/N]: " remove_venv

        if [[ "$remove_venv" =~ ^[Yy]$ ]]; then
            info "Removing .venv..."
            rm -rf .venv
            success "Virtual environment removed"
        else
            info "Virtual environment preserved"
        fi
    else
        warn "No virtual environment found"
    fi
}

# Clean up temporary files
cleanup_temp() {
    step "Cleaning Up Temporary Files"

    rm -f /tmp/egregore.pid
    rm -f /tmp/egregore.lock
    rm -f /tmp/egregore.log

    success "Temporary files removed"
}

# Remove .env file
remove_env() {
    step "Configuration Files"

    if [ -f ".env" ]; then
        echo ""
        read -rp "Remove configuration file (.env)? [y/N]: " remove_env

        if [[ "$remove_env" =~ ^[Yy]$ ]]; then
            rm -f .env
            success ".env removed"
        else
            info ".env preserved"
        fi
    fi
}

# Show final message
show_completion() {
    echo ""
    echo -e "${GREEN}${BOLD}✓ Egregore has been uninstalled${NC}"
    echo ""
    echo "The following were removed:"
    echo "  ✓ SSE server stopped"
    echo "  ✓ Docker containers stopped"
    echo "  ✓ MCP configuration removed"
    echo "  ✓ Temporary files cleaned"
    echo ""

    if [ -d ".venv" ]; then
        echo "Preserved (can be removed manually):"
        echo "  • Virtual environment (.venv/)"
    fi

    if [ -f ".env" ]; then
        echo "  • Configuration file (.env)"
    fi

    # Check if data volumes still exist
    if docker volume ls | grep -q "memoria_"; then
        echo "  • Memory data volumes"
        echo "    (Delete with: docker compose down -v)"
    fi

    echo ""
    echo -e "${CYAN}To completely remove the project directory, run:${NC}"
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
    remove_mcp_config
    remove_data
    remove_venv
    cleanup_temp
    remove_env

    show_completion
}

# Run main function
main "$@"
