#!/bin/bash
#
# Egregore - Hive Mind Memory System Installer
# One-command setup for persistent Claude Code memory
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
    echo -e "${MAGENTA}${BOLD}"
    echo "    ███████╗ ██████╗ ██████╗ ███████╗ ██████╗  ██████╗ ██████╗ ███████╗"
    echo "    ██╔════╝██╔════╝ ██╔══██╗██╔════╝██╔═══██╗██╔═══██╗██╔══██╗██╔════╝"
    echo "    █████╗  ██║  ███╗██████╔╝█████╗  ██║   ██║██║   ██║██████╔╝█████╗  "
    echo "    ██╔══╝  ██║   ██║██╔══██╗██╔══╝  ██║   ██║██║   ██║██╔══██╗██╔══╝  "
    echo "    ███████╗╚██████╔╝██║  ██║███████╗╚██████╔╝╚██████╔╝██║  ██║███████╗"
    echo "    ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚══════╝"
    echo -e "${NC}"
    echo -e "${CYAN}         Hive Mind Memory System for Claude Code${NC}"
    echo -e "${CYAN}         Persistent knowledge across all your projects${NC}"
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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get absolute path
get_abs_path() {
    cd "$1" && pwd
}

# ==================== STEP 1: PREREQUISITES ====================

check_prerequisites() {
    step "Step 1/5: Checking Prerequisites"

    local missing=()

    # Check Docker
    if command_exists docker; then
        local docker_version
        docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
        success "Docker found (version $docker_version)"
    else
        error "Docker is not installed"
        missing+=("docker")
    fi

    # Check Docker Compose
    if command_exists docker compose || docker compose version >/dev/null 2>&1; then
        success "Docker Compose found"
    else
        error "Docker Compose is not installed"
        missing+=("docker compose")
    fi

    # Check Python 3.13
    if command_exists python3; then
        local py_version
        py_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
        if [[ "$py_version" == "3.13" ]]; then
            success "Python 3.13 found"
        else
            warn "Python version is $py_version (3.13 recommended)"
        fi
    else
        error "Python 3 is not installed"
        missing+=("python3")
    fi

    # Check/Install uv
    if command_exists uv; then
        local uv_version
        uv_version=$(uv --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        success "uv found (version $uv_version)"
    else
        warn "uv not found. Installing..."
        install_uv
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        error "Missing required tools: ${missing[*]}"
        echo ""
        echo "Please install the missing tools and try again:"
        echo "  - Docker: https://docs.docker.com/get-docker/"
        echo "  - Python 3.13: https://www.python.org/downloads/"
        exit 1
    fi

    success "All prerequisites satisfied!"
}

install_uv() {
    info "Installing uv (Python package manager)..."

    if command_exists curl; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    elif command_exists wget; then
        wget -qO- https://astral.sh/uv/install.sh | sh
    else
        error "Cannot install uv: neither curl nor wget found"
        echo "Please install uv manually: https://docs.astral.sh/uv/getting-started/installation/"
        exit 1
    fi

    # Source the environment to make uv available
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi

    # Check if uv is now available
    if command_exists uv; then
        success "uv installed successfully"
    else
        error "uv installation may have succeeded but it's not in PATH"
        echo "Please restart your shell or run: source ~/.cargo/env"
        exit 1
    fi
}

# ==================== STEP 2: INTERACTIVE CONFIG ====================

interactive_config() {
    step "Step 2/5: Interactive Configuration"

    echo ""
    echo -e "${CYAN}Let's configure your Egregore instance...${NC}"
    echo ""

    # Embedding provider selection
    local provider_choice
    while true; do
        echo -e "${BOLD}Which embedding provider will you use?${NC}"
        echo "  [1] OpenAI (recommended)"
        echo "  [2] Google Gemini"
        echo ""
        read -rp "Enter choice [1-2]: " provider_choice

        case $provider_choice in
            1)
                EMBEDDING_PROVIDER="openai"
                echo ""
                info "Selected: OpenAI"
                break
                ;;
            2)
                EMBEDDING_PROVIDER="gemini"
                echo ""
                info "Selected: Google Gemini"
                break
                ;;
            *)
                warn "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done

    # API Key input
    echo ""
    if [ "$EMBEDDING_PROVIDER" = "openai" ]; then
        echo -e "${BOLD}Enter your OpenAI API Key:${NC}"
        echo "  (Get one at: https://platform.openai.com/api-keys)"
    else
        echo -e "${BOLD}Enter your Google Gemini API Key:${NC}"
        echo "  (Get one at: https://aistudio.google.com/app/apikey)"
    fi

    # Read API key (hidden input)
    while true; do
        read -rsp "  API Key: " api_key
        echo ""

        if [ -z "$api_key" ]; then
            warn "API Key cannot be empty"
            continue
        fi

        # Basic validation - only warn if pattern doesn't match
        key_valid=true
        if [ "$EMBEDDING_PROVIDER" = "openai" ]; then
            # Check if key starts with sk- (case insensitive)
            if [[ ! "$api_key" =~ ^[Ss][Kk]- ]]; then
                key_valid=false
            fi
        fi

        if [ "$key_valid" = false ]; then
            warn "API key doesn't match expected format for $EMBEDDING_PROVIDER"
            read -rp "Continue anyway? [y/N]: " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                continue
            fi
        fi

        EMBEDDING_API_KEY="$api_key"
        break
    done

    success "API Key configured"

    # Instance name
    echo ""
    echo -e "${BOLD}Enter instance name:${NC}"
    read -rp "  [default: egregore_collective]: " instance_name
    INSTANCE_NAME="${instance_name:-egregore_collective}"
    success "Instance name: $INSTANCE_NAME"

    # Generate .env file
    generate_env_file
}

generate_env_file() {
    info "Generating .env file..."

    cat > .env << EOF
# Egregore Configuration
# Generated on $(date)

# Instance
INSTANCE_NAME=$INSTANCE_NAME

# Embedding Provider
EMBEDDING_PROVIDER=$EMBEDDING_PROVIDER
EMBEDDING_API_KEY=$EMBEDDING_API_KEY

# Memgraph (Graph Database)
MEMGRAPH_HOST=localhost
MEMGRAPH_PORT=7687
MEMGRAPH_USER=
MEMGRAPH_PASSWORD=

# Qdrant (Vector Database)
QDRANT_HOST=localhost
QDRANT_PORT=6333
EOF

    # Secure the file
    chmod 600 .env

    success ".env file created (permissions: 600)"
}

# ==================== STEP 3: INFRASTRUCTURE ====================

deploy_infrastructure() {
    step "Step 3/5: Deploying Infrastructure"

    # Create virtual environment
    info "Creating Python virtual environment..."
    uv venv --python 3.13
    success "Virtual environment created"

    # Install dependencies
    info "Installing Python dependencies..."
    uv pip install -e "."
    success "Dependencies installed"

    # Start Docker services
    info "Starting Docker services (Memgraph + Qdrant)..."
    docker compose up -d

    if [ $? -eq 0 ]; then
        success "Docker services started"
    else
        error "Failed to start Docker services"
        echo "Check logs with: docker compose logs"
        exit 1
    fi

    # Wait for services to be fully ready
    info "Waiting for services to be fully ready..."
    sleep 15
    success "Infrastructure deployed!"
}

# ==================== STEP 4: CLAUDE CODE INTEGRATION ====================

install_claude_mcp() {
    step "Step 4/5: Installing Claude Code MCP Server"

    local project_dir
    project_dir=$(get_abs_path ".")
    local python_path="$project_dir/.venv/bin/python"
    local server_path="$project_dir/src/server.py"

    info "Project directory: $project_dir"
    info "Python path: $python_path"
    info "Server path: $server_path"

    # Configure MCP server globally in ~/.claude.json
    local claude_config="$HOME/.claude.json"
    local claude_backup="$HOME/.claude.json.backup"

    # Backup existing config if it exists
    if [ -f "$claude_config" ]; then
        cp "$claude_config" "$claude_backup"
    fi

    # Create or update ~/.claude.json with egregore MCP server
    info "Configuring Egregore MCP server globally..."

    # Use jq if available, otherwise use python
    if command_exists jq; then
        # Create new config or update existing with jq
        if [ ! -f "$claude_config" ] || [ ! -s "$claude_config" ]; then
            # Create new config
            echo "{\"mcpServers\":{\"egregore\":{\"command\":\"$python_path\",\"args\":[\"$server_path\"]}}}" | jq '.' > "$claude_config"
        else
            # Update existing config
            jq --arg python "$python_path" --arg server "$server_path" \
                '.mcpServers.egregore = {"command": $python, "args": [$server]}' \
                "$claude_config" > "${claude_config}.tmp" && mv "${claude_config}.tmp" "$claude_config"
        fi
    else
        # Fallback: use python to modify JSON
        python3 << PYTHON_EOF
import json
import os

config_file = "$claude_config"
python_path = "$python_path"
server_path = "$server_path"

# Read existing config or create new
if os.path.exists(config_file):
    with open(config_file, 'r') as f:
        config = json.load(f)
else:
    config = {}

# Ensure mcpServers exists
if 'mcpServers' not in config:
    config['mcpServers'] = {}

# Add egregore server
config['mcpServers']['egregore'] = {
    'command': python_path,
    'args': [server_path]
}

# Write back to file
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
PYTHON_EOF
    fi

    # Verify the configuration
    if [ -f "$claude_config" ]; then
        success "Egregore MCP server configured globally in ~/.claude.json"
        CLAUDE_INSTALLED=true

        # Clean up backup on success
        if [ -f "$claude_backup" ]; then
            rm "$claude_backup"
        fi
    else
        warn "Failed to configure Egregore MCP server"
        CLAUDE_INSTALLED=false
    fi

    if [ "$CLAUDE_INSTALLED" = false ]; then
        echo ""
        echo -e "${YELLOW}Manual installation required:${NC}"
        echo ""
        echo "Add this to your ~/.claude.json:"
        echo ""
        echo -e "${CYAN}{\"mcpServers\": {\"egregore\": {\"command\": \"$python_path\", \"args\": [\"$server_path\"]}}}${NC}"
        echo ""
    fi
}

# ==================== STEP 5: FINAL INSTRUCTIONS ====================

show_final_instructions() {
    step "Step 5/5: Setup Complete!"

    echo ""
    echo -e "${GREEN}${BOLD}✨ Egregore is now ready!${NC}"
    echo ""
    echo -e "${CYAN}Your hive mind memory is active and waiting for knowledge.${NC}"
    echo ""

    # Show status
    echo -e "${BOLD}System Status:${NC}"
    echo "  • Memgraph (Graph DB):  localhost:7687"
    echo "  • Qdrant (Vector DB):   localhost:6333"
    echo "  • Instance Name:        $INSTANCE_NAME"
    echo ""

    # Show Claude Code instructions
    echo -e "${BOLD}Add this to your CLAUDE.md files to activate Egregore:${NC}"
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    cat << 'EOF'
# EGREGORE PROTOCOL (Hive Mind Memory)

## REQUIRED: Before Starting Work
Use `recall_memory(query)` before any task.

## Store Memories When:
- Fixing a bug → problem + solution (context="bugfix")
- Making an architecture decision (context="architecture")
- Discovering a reusable pattern (context="learning")
- Learning user preferences (context="preference")

**Required parameters:** `data`, `context`, and `tags` (comma-separated)

### Available Tools
- `recall_memory(query, limit)` - Search the hive mind
- `store_memory(data, context, tags)` - Teach the collective

→ Full documentation: https://github.com/Zurybr/egregore
EOF
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Useful commands
    echo -e "${BOLD}Useful Commands:${NC}"
    echo "  View logs:        docker compose logs -f"
    echo "  Stop services:    docker compose down"
    echo "  Start services:   docker compose up -d"
    echo "  Health check:     claude mcp list  # Should show 'egregore'"
    echo ""

    # Dashboard section
    echo -e "${BOLD}📊 Web Dashboard:${NC}"
    echo "  Start dashboard:  source .venv/bin/activate && streamlit run src/dashboard.py"
    echo "  Or use:           egregore-dashboard"
    echo "  Open at:          http://localhost:8501"
    echo ""

    echo -e "${GREEN}Happy coding with your hive mind! 🐝${NC}"
    echo ""
}

# ==================== MAIN ====================

main() {
    print_banner

    # Check if running in correct directory
    if [ ! -f "pyproject.toml" ]; then
        error "pyproject.toml not found. Please run this script from the project root."
        exit 1
    fi

    check_prerequisites
    interactive_config
    deploy_infrastructure
    install_claude_mcp
    show_final_instructions
}

# Run main function
main "$@"
