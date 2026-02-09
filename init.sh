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

# Mode flag
SERVER_ONLY=false

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
        if docker ps | grep -q "qdrant"; then
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

# Configure MCP client (LOCAL MACHINE)
configure_mcp() {
    step "Configuring Claude Code MCP Client (LOCAL)"

    local settings
    settings=$(get_settings)
    local host
    host=$(echo "$settings" | grep EREGORE_HOST | cut -d= -f2)
    local port
    port=$(echo "$settings" | grep EREGORE_PORT | cut -d= -f2)

    # Default values if not set
    host="${host:-0.0.0.0}"
    port="${port:-9000}"

    # Get server IP for remote connection
    info "Detecting server IP..."
    local server_ip
    server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    server_ip="${server_ip:-$(curl -s ifconfig.me 2>/dev/null || echo "localhost")}"

    # Build the URL with server IP
    local url="http://${server_ip}:${port}/sse"

    info "MCP Server URL: $url"
    echo ""
    echo -e "${YELLOW}If connecting from a different machine, replace the IP above.${NC}"
    echo ""

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

# Configure MEMORY.md (LOCAL MACHINE)
configure_memory_md() {
    step "Configuring Memory Protocol (LOCAL)"

    local memory_dir="$HOME/.claude/memory"
    local memory_file="$memory_dir/MEMORY.md"

    # Create directory if it doesn't exist
    mkdir -p "$memory_dir"

    # Check if file already exists
    if [ -f "$memory_file" ]; then
        info "MEMORY.md already exists at $memory_file"
        info "Skipping creation (edit manually to update)"
        return 0
    fi

    # Create MEMORY.md with Egregore protocol
    cat > "$memory_file" << 'EOF'
# EGREGORE PROTOCOL (Hive Mind Memory)

## ⚠️ MANDATORY - Before Starting ANY Work
**ALWAYS use `recall_memory(query)` before ANY task.** This is not optional.

Query examples:
- User's name, preferences, or context
- Project-specific information
- Previous bugs fixed or patterns discovered
- Architecture decisions made

## Store Memories When:
- Fixing a bug → problem + solution (context="bugfix")
- Making an architecture decision (context="architecture")
- Discovering a reusable pattern (context="learning")
- Completing a feature (context="preference")
- Learning user preferences (context="preference")

**Required parameters:** `data`, `context`, and `tags` (comma-separated)

### Available Tools
- `health_check` - Check memory system status
- `recall_memory(query, limit)` - Search the hive mind
- `store_memory(data, context, tags)` - Teach the collective

→ Full documentation: https://github.com/Zurybr/egregore
EOF

    success "MEMORY.md created at $memory_file"
}

# Configure CLAUDE.md (LOCAL MACHINE)
configure_claude_md() {
    step "Configuring CLAUDE.md (LOCAL)"

    local claude_md="$HOME/.claude/CLAUDE.md"

    # Check if EGREGORE section already exists
    if [ -f "$claude_md" ] && grep -q "EGREGORE PROTOCOL" "$claude_md"; then
        info "EGREGORE PROTOCOL already exists in CLAUDE.md"
        info "Skipping (edit manually to update)"
        return 0
    fi

    # Append EGREGORE section to CLAUDE.md
    cat >> "$claude_md" << 'EOF'


---

# EGREGORE PROTOCOL (Hive Mind Memory)

## ⚠️ MANDATORY - Before Starting ANY Work
**ALWAYS use `recall_memory(query)` before ANY task.** This is not optional.

Query examples:
- User's name, preferences, or context
- Project-specific information
- Previous bugs fixed or patterns discovered
- Architecture decisions made

## Store Memories When:
- Fixing a bug → problem + solution (context="bugfix")
- Making an architecture decision (context="architecture")
- Discovering a reusable pattern (context="learning")
- Completing a feature (context="preference")
- Learning user preferences (context="preference")

**Required parameters:** `data`, `context`, and `tags` (comma-separated)

### Available Tools
- `health_check` - Check memory system status
- `recall_memory(query, limit)` - Search the hive mind
- `store_memory(data, context, tags)` - Teach the collective

→ Full documentation: https://github.com/Zurybr/egregore
EOF

    success "EGREGORE PROTOCOL added to CLAUDE.md"
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

# Show client setup instructions (for remote/standalone setup)
show_client_setup_instructions() {
    step "Local Client Setup Instructions"

    local settings
    settings=$(get_settings)
    local port
    port=$(echo "$settings" | grep EREGORE_PORT | cut -d= -f2)
    port="${port:-9000}"

    # Get server IP
    local server_ip
    server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    server_ip="${server_ip:-<your-server-ip>}"

    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  CLIENT SETUP INSTRUCTIONS (Run on your LOCAL machine)${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    echo -e "${BOLD}1. MCP Configuration (~/.claude.json)${NC}"
    echo ""
    echo "  Add this to your ~/.claude.json:"
    echo ""
    echo -e "${GREEN}{${NC}"
    echo -e "${GREEN}  \"mcpServers\": {${NC}"
    echo -e "${GREEN}    \"egregore\": {${NC}"
    echo -e "${GREEN}      \"type\": \"sse\",${NC}"
    echo -e "${GREEN}      \"url\": \"http://${server_ip}:${port}/sse\"${NC}"
    echo -e "${GREEN}    }${NC}"
    echo -e "${GREEN}  }${NC}"
    echo -e "${GREEN}}${NC}"
    echo ""

    echo -e "${BOLD}2. Memory Protocol (~/.claude/memory/MEMORY.md)${NC}"
    echo ""
    echo "  Create the file with:"
    echo ""
    echo "  ${CYAN}mkdir -p ~/.claude/memory${NC}"
    echo "  ${CYAN}cat > ~/.claude/memory/MEMORY.md << 'EOF'${NC}"
    echo "  # EGREGORE PROTOCOL (Hive Mind Memory)"
    echo ""
    echo "  ## ⚠️ MANDATORY - Before Starting ANY Work"
    echo "  **ALWAYS use \`recall_memory(query)\` before ANY task.**"
    echo ""
    echo "  [rest of protocol...]"
    echo "  EOF"
    echo ""

    echo -e "${BOLD}3. CLAUDE.md Protocol (Optional)${NC}"
    echo ""
    echo "  Add EGREGORE section to your project CLAUDE.md files"
    echo "  See: https://github.com/Zurybr/egregore#usage"
    echo ""

    echo -e "${BOLD}4. CLI Tool (Optional - cooler interface!)${NC}"
    echo ""
    echo "  On your local machine:"
    echo ""
    echo "  ${CYAN}cd /path/to/egregore/skill-egregore${NC}"
    echo "  ${CYAN}uv pip install -e .${NC}"
    echo "  ${CYAN}export EGREGORE_URL=\"http://${server_ip}:${port}\"${NC}"
    echo "  ${CYAN}egregore interactive  # Start interactive mode${NC}"
    echo ""

    echo -e "${BOLD}5. Test Connection${NC}"
    echo ""
    echo "  From your local machine, test:"
    echo ""
    echo "  ${CYAN}curl http://${server_ip}:${port}/sse${NC}"
    echo ""
    echo "  Should return: text/event-stream response"
    echo ""

    echo -e "${YELLOW}Note: Replace '${server_ip}' with your actual server IP${NC}"
    echo ""
}

# Show final status and instructions
show_status() {
    step "Egregore Server Status"

    local settings
    settings=$(get_settings)
    local port
    port=$(echo "$settings" | grep EREGORE_PORT | cut -d= -f2)
    port="${port:-9000}"

    # Get server IP
    local server_ip
    server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    server_ip="${server_ip:-localhost}"

    echo ""
    echo -e "${GREEN}${BOLD}✨ Egregore SSE Server is ready!${NC}"
    echo ""

    # Check server status
    check_server_status

    echo ""
    echo -e "${BOLD}Connection URLs:${NC}"
    echo "  Local:  http://localhost:${port}/sse"
    echo "  Remote: http://${server_ip}:${port}/sse"
    echo ""

    echo -e "${BOLD}Server Management:${NC}"
    echo "  egregore-server status     - Check server status"
    echo "  egregore-server stop       - Stop the server"
    echo "  egregore-server restart    - Restart the server"
    echo "  egregore-server logs -f    - View server logs"
    echo ""

    echo -e "${BOLD}Dashboard:${NC}"
    echo "  egregore-dashboard         - Start web dashboard"
    echo "  http://localhost:8501      - Dashboard URL"
    echo ""

    echo -e "${CYAN}Happy coding with your centralized hive mind! 🐝${NC}"
    echo ""
}

# Main function
main() {
    print_banner

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --server-only)
                SERVER_ONLY=true
                shift
                ;;
            *)
                # Unknown argument will be handled by the case at the end
                break
                ;;
        esac
    done

    check_project_directory
    check_venv
    check_docker_services

    # Start the server if not running
    if ! check_server_status > /dev/null 2>&1; then
        start_server
    fi

    if [ "$SERVER_ONLY" = true ]; then
        # Show client setup instructions instead of configuring locally
        show_client_setup_instructions
        show_status

        echo ""
        echo -e "${YELLOW}${BOLD}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}${BOLD}  SERVER-ONLY MODE: Local MCP not configured${NC}"
        echo -e "${YELLOW}${BOLD}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${CYAN}Run the client setup steps above on your local machine.${NC}"
        echo ""

        # Pass any remaining arguments to the case statement
        if [ $# -gt 0 ]; then
            case "${1:-}" in
                --status)
                    check_server_status
                    ;;
                --start)
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
            esac
        fi
    else
        # Configure MCP client (local setup)
        configure_mcp

        # Configure MEMORY.md
        configure_memory_md

        # Configure CLAUDE.md
        configure_claude_md

        # Show final status
        show_status
    fi
}

# Handle command line arguments (for legacy/single command usage)
if [ "$SERVER_ONLY" = false ]; then
    case "${1:-}" in
        --server-only)
            # Re-run main with server-only flag
            main "$@"
            exit $?
            ;;
    esac
fi

# Handle standalone flags (without full init)
handle_standalone_flag() {
    case "${1:-}" in
        --status)
            check_project_directory
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
            print_banner
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  (no option)     Initialize everything (server + local client)"
            echo "  --server-only   Start server only (for remote server setup)"
            echo "  --status        Check server status"
            echo "  --start         Start the server"
            echo "  --stop          Stop the server"
            echo "  --restart       Restart the server"
            echo "  --logs          View server logs (tail -f)"
            echo "  --help          Show this help message"
            exit 0
            ;;
        *)
            # Unknown option - might be a flag for main()
            return 1
            ;;
    esac
    return 0
}

# Try to handle as standalone flag first
if ! handle_standalone_flag "$@"; then
    # If not a standalone flag, run main
    main "$@"
fi
