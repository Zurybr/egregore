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
    if command_exists docker-compose || docker compose version >/dev/null 2>&1; then
        success "Docker Compose found"
    else
        error "Docker Compose is not installed"
        missing+=("docker-compose")
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

        # Basic validation
        if [ "$EMBEDDING_PROVIDER" = "openai" ] && [[ ! "$api_key" =~ ^sk- ]]; then
            warn "OpenAI API keys typically start with 'sk-'"
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
    docker-compose up -d --wait

    if [ $? -eq 0 ]; then
        success "Docker services are running"
    else
        error "Failed to start Docker services"
        echo "Check logs with: docker-compose logs"
        exit 1
    fi

    # Wait a bit for services to be fully ready
    info "Waiting for services to be fully ready..."
    sleep 5
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

    # Check if claude CLI is available
    if command_exists claude; then
        info "Registering Egregore with Claude Code..."

        if claude mcp add egregore -- "$python_path" "$server_path"; then
            success "Egregore registered with Claude Code!"
            CLAUDE_INSTALLED=true
        else
            warn "Failed to automatically register with Claude Code"
            CLAUDE_INSTALLED=false
        fi
    else
        warn "Claude CLI not found in PATH"
        CLAUDE_INSTALLED=false
    fi

    if [ "$CLAUDE_INSTALLED" = false ]; then
        echo ""
        echo -e "${YELLOW}Manual installation required:${NC}"
        echo ""
        echo "Run this command to register Egregore:"
        echo ""
        echo -e "${CYAN}  claude mcp add egregore -- $python_path $server_path${NC}"
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
# EGREGORE PROTOCOL (Memoria Compartida)

## 🧠 Activación Cognitiva
Este proyecto está conectado a **Egregore**, una memoria de colmena persistente.
Tu primera acción en CUALQUIER sesión debe ser sincronizarte con la colmena.

## 🛠 Herramientas
1. **`recall_memory(query)`**: Tu buscador. Úsalo antes de preguntar.
   - *Cuándo usar:* Al iniciar sesión, antes de tomar decisiones técnicas, al encontrar errores.
2. **`store_memory(data)`**: Tu grabadora. Úsalo para enseñar a la colmena.
   - *Cuándo usar:* Al solucionar un bug, al definir arquitectura, al aprender preferencias del usuario.

## 📜 Reglas de Oro
- **No seas redundante:** Antes de guardar, verifica si ya lo sabemos.
- **Sé explícito:** "Guardando en Egregore: La API corre en el puerto 8000".
- **Confía en la Colmena:** Si Egregore dice que usamos una librería específica, úsala, a menos que el usuario te ordene lo contrario.
EOF
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Useful commands
    echo -e "${BOLD}Useful Commands:${NC}"
    echo "  View logs:        docker-compose logs -f"
    echo "  Stop services:    docker-compose down"
    echo "  Start services:   docker-compose up -d"
    echo "  Health check:     claude mcp list  # Should show 'egregore'"
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
