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
    echo "  • SSE server processes"
    echo "  • Docker containers (not images)"
    echo "  • MCP configuration from ~/.claude.json"
    echo "  • All memory data (Qdrant volumes)"
    echo "  • Kuzu database files"
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

# Stop the SSE server
stop_server() {
    step "Stopping SSE Server"

    # Try CLI first
    if command -v egregore-server >/dev/null 2>&1; then
        egregore-server stop 2>/dev/null || true
    fi

    # Kill any remaining processes
    if [ -f "/tmp/egregore.pid" ]; then
        local pid
        pid=$(cat /tmp/egregore.pid 2>/dev/null)
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null || true
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
        fi
        rm -f /tmp/egregore.pid
    fi

    # Remove lock and log files
    rm -f /tmp/egregore.lock
    rm -f /tmp/egregore.log

    success "Server stopped and temp files removed"
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
    docker rm -f egregore-qdrant 2>/dev/null || true
}

# Remove all data volumes
remove_all_data() {
    step "Removing All Data"

    # Remove Docker volumes
    info "Removing Docker volumes..."
    docker compose down -v 2>/dev/null || true
    docker volume rm egregore_qdrant_data 2>/dev/null || true

    # Remove Kuzu database
    info "Removing Kuzu database..."
    rm -rf /tmp/egregore_kuzu.db 2>/dev/null || true

    success "All data removed (memories, vectors, graph data)"
}

# Remove MCP configuration
remove_mcp_config() {
    step "Removing MCP Configuration"

    local claude_config="$HOME/.claude.json"

    if [ -f "$claude_config" ]; then
        if command -v jq >/dev/null 2>&1; then
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
        success "MCP configuration removed"
    else
        warn "No ~/.claude.json found"
    fi

    # Also remove backup if exists
    rm -f "$HOME/.claude.json.backup"
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

    success "Cleanup complete"
}

# Show final message
show_completion() {
    echo ""
    echo -e "${GREEN}${BOLD}✓ Egregore has been completely uninstalled${NC}"
    echo ""
    echo -e "${BOLD}Removed:${NC}"
    echo "  ✓ SSE server processes"
    echo "  ✓ Docker containers"
    echo "  ✓ All memory data (Qdrant volumes + Kuzu DB)"
    echo "  ✓ MCP configuration"
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
    remove_venv
    remove_env
    cleanup_remaining

    show_completion
}

# Run main function
main "$@"
