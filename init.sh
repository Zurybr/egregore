#!/bin/bash
#
# Egregore - Hive Mind Memory System Init Script
# Initializes and starts the SSE MCP server
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

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Banner
print_banner() {
    echo ""
    echo -e "${MAGENTA}${BOLD}"
    echo "    ███████╗ ██████╗ ██████╗ ███████╗ ██████╗  ██████╗ ██████╗ ███████╗"
    echo "    ██╔════╝██╔════╝ ██╔══██╗██╔════╝██╔═══██╗██╔═══██╗██╔══██╗██╔════╝"
    echo "    █████╗  ██║  ███╗██████╔╝█████╗  ██║   ██║██║   ██║██████╔╝█████╗  "
    echo "    ██╔══╝  ██║   ██║██╔══██╗██╔══╝  ██║   ██║██║   ██║██╔══██╗██╔══╝  "
    echo "    ███████╗╚██████╔╝██║  ██║███████╗╚██████╔╝╚██████╔╝██║  ██║███████╗"
    echo "    ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚══════╝"
    echo -e "${NC}"
    echo -e "${CYAN}         Hive Mind Memory System - SSE Server${NC}"
    echo -e "${CYAN}         Centralized brain for all Claude Code instances${NC}"
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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running in the correct directory
check_project_directory() {
    if [ ! -f "pyproject.toml" ]; then
        error "pyproject.toml not found. Please run this script from the project root."
        exit 1
    fi

    if ! grep -q "egregore" pyproject.toml 2>/dev/null; then
        error "This doesn't appear to be the Egregore project directory."
        exit 1
    fi
}

# Check Python virtual environment
check_venv() {
    if [ ! -d ".venv" ]; then
        error "Virtual environment not found. Please run install.sh first."
        echo ""
        echo "Run: ./install.sh"
        exit 1
    fi

    if [ ! -f ".venv/bin/python" ]; then
        error "Virtual environment is corrupted."
        exit 1
    fi
}

# Check if Docker services are running
check_docker_services() {
    step "Checking Infrastructure Services"

    local services_ok=true

    # Check Memgraph
    if docker ps | grep -q "memgraph"; then
        success "Memgraph is running"
    else
        warn "Memgraph is not running"
        services_ok=false
    fi

    # Check Qdrant
    if docker ps | grep -q "qdrant"; then
        success "Qdrant is running"
    else
        warn "Qdrant is not running"
        services_ok=false
    fi

    if [ "$services_ok" = false ]; then
        echo ""
        info "Starting Docker services..."
        docker compose up -d

        info "Waiting for services to be ready..."
        sleep 10

        # Check again
        if docker ps | grep -q "memgraph" && docker ps | grep -q "qdrant"; then
            success "Services started successfully"
        else
            error "Failed to start services. Check with: docker compose logs"
            exit 1
        fi
    fi
}

# Check server status
check_server_status() {
    if command_exists egregore-server; then
        egregore-server status
    else
        info "Server CLI not in PATH. Using direct check..."

        if [ -f "/tmp/egregore.pid" ]; then
            local pid
            pid=$(cat /tmp/egregore.pid)
            if ps -p "$pid" > /dev/null 2>&1; then
                success "Egregore server is running (PID: $pid)"
                return 0
            else
                warn "Stale PID file found. Cleaning up..."
                rm -f /tmp/egregore.pid /tmp/egregore.lock
                return 1
            fi
        else
            warn "Egregore server is not running"
            return 1
        fi
    fi
}

# Start the SSE server
start_server() {
    step "Starting Egregore SSE Server"

    # Check if already running
    if [ -f "/tmp/egregore.pid" ]; then
        local pid
        pid=$(cat /tmp/egregore.pid 2>/dev/null)
        if ps -p "$pid" > /dev/null 2>&1; then
            success "Server is already running (PID: $pid)"
            return 0
        fi
    fi

    # Activate virtual environment
    source .venv/bin/activate

    # Start the server
    info "Starting Egregore SSE server..."

    if command_exists egregore-server; then
        egregore-server start
    else
        # Fallback: start directly
        export EGREGORE_HOST="${EGREGORE_HOST:-0.0.0.0}"
        export EGREGORE_PORT="${EGREGORE_PORT:-9000}"

        nohup python -m src.server > /tmp/egregore.log 2>&1 &
        local pid=$!

        # Wait a moment and check if it's still running
        sleep 2

        if ps -p "$pid" > /dev/null 2>&1; then
            echo "$pid" > /tmp/egregore.pid
            success "Server started (PID: $pid)"
        else
            error "Server failed to start. Check logs: /tmp/egregore.log"
            exit 1
        fi
    fi
}

# Configure MCP client
configure_mcp() {
    step "Configuring Claude Code MCP Client"

    local settings
    settings=$(get_settings)
    local host
    host=$(echo "$settings" | grep EREGORE_HOST | cut -d= -f2)
    local port
    port=$(echo "$settings" | grep EREGORE_PORT | cut -d= -f2)

    # Default values if not set
    host="${host:-0.0.0.0}"
    port="${port:-9000}"

    # Build the URL
    # If host is 0.0.0.0, use localhost for the client
    local client_host
    if [ "$host" = "0.0.0.0" ]; then
        client_host="localhost"
    else
        client_host="$host"
    fi
    local url="http://${client_host}:${port}/sse"

    info "MCP Server URL: $url"

    # Configure ~/.claude.json
    local claude_config="$HOME/.claude.json"
    local claude_backup="$HOME/.claude.json.backup"

    # Backup existing config
    if [ -f "$claude_config" ]; then
        cp "$claude_config" "$claude_backup"
    fi

    # Create/update config
    if command_exists jq; then
        if [ ! -f "$claude_config" ] || [ ! -s "$claude_config" ]; then
            echo "{\"mcpServers\":{\"egregore\":{\"type\":\"sse\",\"url\":\"$url\"}}}" | jq '.' > "$claude_config"
        else
            jq --arg url "$url" \
                '.mcpServers.egregore = {"type": "sse", "url": $url}' \
                "$claude_config" > "${claude_config}.tmp" && mv "${claude_config}.tmp" "$claude_config"
        fi
    else
        # Fallback: use python
        python3 << PYTHON_EOF
import json
import os

config_file = "$claude_config"
url = "$url"

if os.path.exists(config_file):
    with open(config_file, 'r') as f:
        config = json.load(f)
else:
    config = {}

if 'mcpServers' not in config:
    config['mcpServers'] = {}

config['mcpServers']['egregore'] = {
    'type': 'sse',
    'url': url
}

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
PYTHON_EOF
    fi

    if [ -f "$claude_config" ]; then
        success "MCP client configured in ~/.claude.json"

        # Clean up backup
        if [ -f "$claude_backup" ]; then
            rm "$claude_backup"
        fi
    else
        error "Failed to configure MCP client"
        return 1
    fi
}

# Get settings from config
get_settings() {
    if [ -f ".env" ]; then
        cat .env
    else
        echo "EGREGORE_HOST=0.0.0.0"
        echo "EGREGORE_PORT=9000"
    fi
}

# Show final status and instructions
show_status() {
    step "Egregore Server Status"

    local settings
    settings=$(get_settings)
    local port
    port=$(echo "$settings" | grep EREGORE_PORT | cut -d= -f2)
    port="${port:-9000}"

    echo ""
    echo -e "${GREEN}${BOLD}✨ Egregore SSE Server is ready!${NC}"
    echo ""

    # Check server status
    check_server_status

    echo ""
    echo -e "${BOLD}Connection URL:${NC}"
    echo "  http://localhost:${port}/sse"
    echo ""

    echo -e "${BOLD}Management Commands:${NC}"
    echo "  egregore-server status     - Check server status"
    echo "  egregore-server stop       - Stop the server"
    echo "  egregore-server restart    - Restart the server"
    echo "  egregore-server logs       - View server logs"
    echo ""

    echo -e "${BOLD}Dashboard:${NC}"
    echo "  egregore-dashboard         - Start web dashboard"
    echo "  http://localhost:8501      - Dashboard URL"
    echo ""

    echo -e "${BOLD}Multi-Instance Support:${NC}"
    echo "  Multiple Claude Code instances can now connect to:"
    echo "  http://<server-ip>:${port}/sse"
    echo ""

    echo -e "${CYAN}Happy coding with your centralized hive mind! 🐝${NC}"
    echo ""
}

# Main function
main() {
    print_banner

    check_project_directory
    check_venv
    check_docker_services

    # Start the server if not running
    if ! check_server_status > /dev/null 2>&1; then
        start_server
    fi

    # Configure MCP client
    configure_mcp

    # Show final status
    show_status
}

# Handle command line arguments
case "${1:-}" in
    --status)
        check_server_status
        ;;
    --start)
        check_project_directory
        check_venv
        check_docker_services
        start_server
        ;;
    --stop)
        if command_exists egregore-server; then
            egregore-server stop
        elif [ -f "/tmp/egregore.pid" ]; then
            kill "$(cat /tmp/egregore.pid)" 2>/dev/null || true
            rm -f /tmp/egregore.pid /tmp/egregore.lock
            success "Server stopped"
        else
            warn "Server is not running"
        fi
        ;;
    --restart)
        check_project_directory
        check_venv
        if command_exists egregore-server; then
            egregore-server restart
        else
            $0 --stop
            sleep 2
            $0 --start
        fi
        ;;
    --logs)
        if command_exists egregore-server; then
            egregore-server logs -f
        elif [ -f "/tmp/egregore.log" ]; then
            tail -f /tmp/egregore.log
        else
            warn "No log file found"
        fi
        ;;
    ""|--help|-h)
        main
        ;;
    *)
        error "Unknown option: $1"
        echo ""
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  (no option)  Initialize and start everything"
        echo "  --status     Check server status"
        echo "  --start      Start the server"
        echo "  --stop       Stop the server"
        echo "  --restart    Restart the server"
        echo "  --logs       View server logs"
        echo "  --help       Show this help message"
        exit 1
        ;;
esac
