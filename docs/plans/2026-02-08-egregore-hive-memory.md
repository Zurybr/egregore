# Egregore - Hive Mind Memory Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a complete "Egregore" - a persistent hive mind memory system for Claude Code with automated installation via `install.sh`.

**Architecture:** FastMCP server exposing `recall_memory` and `store_memory` tools backed by Mem0 with graph capabilities (Memgraph MAGE + Qdrant). Interactive bash installer handles prerequisites, configuration, Docker deployment, and automatic Claude Code MCP registration.

**Tech Stack:** Python 3.13, uv, mem0ai[graph], FastMCP, Pydantic, Docker Compose (Memgraph MAGE + Qdrant), Bash

---

## Task 1: Project Structure and pyproject.toml

**Files:**
- Create: `pyproject.toml`
- Create: `.python-version`

**Step 1: Create Python version file**

```bash
echo "3.13" > .python-version
```

**Step 2: Create pyproject.toml with all dependencies**

```toml
[project]
name = "egregore"
version = "0.1.0"
description = "Hive Mind Memory System for Claude Code"
readme = "README.md"
requires-python = ">=3.13"
dependencies = [
    "mem0ai[graph]>=0.1.0",
    "fastmcp>=0.4.0",
    "pydantic>=2.0.0",
    "pydantic-settings>=2.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0.0",
    "pytest-asyncio>=0.23.0",
    "ruff>=0.6.0",
    "mypy>=1.8.0",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.ruff]
line-length = 100
target-version = "py313"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "UP", "B", "C4", "SIM"]

[tool.mypy]
python_version = "3.13"
strict = true
warn_return_any = true
warn_unused_configs = true

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
```

**Step 3: Verify syntax**

```bash
cat pyproject.toml | head -20
```

Expected: Clean output showing TOML structure

**Step 4: Commit**

```bash
git add pyproject.toml .python-version
git commit -m "feat: initialize project with pyproject.toml"
```

---

## Task 2: Docker Compose Infrastructure

**Files:**
- Create: `docker-compose.yml`

**Step 1: Create docker-compose.yml with Memgraph MAGE and Qdrant**

```yaml
version: "3.8"

services:
  memgraph:
    image: memgraph/memgraph-mage:latest
    container_name: egregore-memgraph
    ports:
      - "7687:7687"  # Bolt protocol
      - "7444:7444"  # WebSocket for Lab
    volumes:
      - memgraph_data:/var/lib/memgraph
    environment:
      - MEMGRAPH="--telemetry-enabled=false"
    healthcheck:
      test: ["CMD", "mgconsole", "--eval", "RETURN 1;"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    restart: unless-stopped

  qdrant:
    image: qdrant/qdrant:latest
    container_name: egregore-qdrant
    ports:
      - "6333:6333"  # REST API
      - "6334:6334"  # gRPC
    volumes:
      - qdrant_data:/qdrant/storage
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6333/healthz"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
    restart: unless-stopped

volumes:
  memgraph_data:
    name: egregore_memgraph_data
  qdrant_data:
    name: egregore_qdrant_data
```

**Step 2: Validate YAML syntax**

```bash
docker-compose config > /dev/null && echo "Valid YAML"
```

Expected: "Valid YAML" (may warn about version being obsolete, that's OK)

**Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: add docker-compose with memgraph-mage and qdrant"
```

---

## Task 3: Configuration Module (src/config.py)

**Files:**
- Create: `src/__init__.py`
- Create: `src/config.py`

**Step 1: Create src directory and __init__.py**

```bash
mkdir -p src
touch src/__init__.py
```

**Step 2: Create config.py with Pydantic Settings**

```python
"""Configuration management for Egregore."""

from enum import Enum
from functools import lru_cache

from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class EmbeddingProvider(str, Enum):
    """Supported embedding providers."""

    OPENAI = "openai"
    GEMINI = "gemini"


class Settings(BaseSettings):
    """Egregore configuration settings.

    Loads from environment variables and .env file.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Instance configuration
    instance_name: str = Field(
        default="egregore_collective",
        description="Name of this Egregore instance",
    )

    # Embedding configuration
    embedding_provider: EmbeddingProvider = Field(
        default=EmbeddingProvider.OPENAI,
        description="Embedding provider to use",
    )
    embedding_api_key: SecretStr = Field(
        description="API key for the embedding provider",
    )

    # Memgraph configuration
    memgraph_host: str = Field(default="localhost")
    memgraph_port: int = Field(default=7687)
    memgraph_user: str = Field(default="")
    memgraph_password: SecretStr = Field(default=SecretStr(""))

    # Qdrant configuration
    qdrant_host: str = Field(default="localhost")
    qdrant_port: int = Field(default=6333)

    @property
    def memgraph_uri(self) -> str:
        """Build Memgraph connection URI."""
        auth = ""
        if self.memgraph_user:
            auth = f"{self.memgraph_user}:{self.memgraph_password.get_secret_value()}@"
        return f"bolt://{auth}{self.memgraph_host}:{self.memgraph_port}"

    @property
    def qdrant_uri(self) -> str:
        """Build Qdrant connection URI."""
        return f"http://{self.qdrant_host}:{self.qdrant_port}"


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()


# Export for convenient access
settings = get_settings()
```

**Step 3: Verify Python syntax**

```bash
python3 -m py_compile src/config.py && echo "Valid Python"
```

Expected: "Valid Python"

**Step 4: Commit**

```bash
git add src/__init__.py src/config.py
git commit -m "feat: add configuration module with Pydantic settings"
```

---

## Task 4: Mem0 Client Module (src/memory.py)

**Files:**
- Create: `src/memory.py`

**Step 1: Create memory.py with Mem0 client wrapper**

```python
"""Mem0 client wrapper for Egregore."""

from typing import Any

from mem0 import MemoryClient

from src.config import Settings, get_settings


class EgregoreMemory:
    """Wrapper around Mem0 client for Egregore operations."""

    def __init__(self, settings: Settings | None = None) -> None:
        """Initialize the memory client.

        Args:
            settings: Configuration settings. Uses cached settings if not provided.
        """
        self.settings = settings or get_settings()
        self._client: MemoryClient | None = None

    @property
    def client(self) -> MemoryClient:
        """Lazy initialization of Mem0 client."""
        if self._client is None:
            config = self._build_config()
            self._client = MemoryClient.from_config(config_dict=config)
        return self._client

    def _build_config(self) -> dict[str, Any]:
        """Build Mem0 configuration dictionary."""
        config: dict[str, Any] = {
            "vector_store": {
                "provider": "qdrant",
                "config": {
                    "collection_name": self.settings.instance_name,
                    "host": self.settings.qdrant_host,
                    "port": self.settings.qdrant_port,
                    "embedding_model_dims": 1536,  # OpenAI default
                },
            },
            "graph_store": {
                "provider": "memgraph",
                "config": {
                    "url": self.settings.memgraph_uri,
                },
            },
            "llm": {
                "provider": self.settings.embedding_provider.value,
                "config": {
                    "api_key": self.settings.embedding_api_key.get_secret_value(),
                    "model": "gpt-4o-mini" if self.settings.embedding_provider.value == "openai" else "gemini-pro",
                },
            },
            "embedder": {
                "provider": self.settings.embedding_provider.value,
                "config": {
                    "api_key": self.settings.embedding_api_key.get_secret_value(),
                    "model": "text-embedding-3-small" if self.settings.embedding_provider.value == "openai" else "models/embedding-001",
                },
            },
        }
        return config

    def recall(self, query: str, limit: int = 5) -> list[dict[str, Any]]:
        """Search for memories matching the query.

        Args:
            query: Search query string
            limit: Maximum number of results to return

        Returns:
            List of matching memory entries
        """
        results = self.client.search(
            query=query,
            limit=limit,
        )
        return results

    def store(
        self,
        data: str,
        metadata: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Store a new memory.

        Args:
            data: The memory content to store
            metadata: Optional metadata to attach

        Returns:
            Storage result with memory IDs
        """
        result = self.client.add(
            data,
            metadata=metadata or {},
        )
        return result

    def health_check(self) -> dict[str, bool]:
        """Check connectivity to memory stores.

        Returns:
            Dictionary with health status of each component
        """
        # Basic connectivity check through a simple operation
        try:
            # Try to search (will fail if stores are down)
            self.client.search("health_check", limit=1)
            return {"vector_store": True, "graph_store": True}
        except Exception as e:
            return {"vector_store": False, "graph_store": False, "error": str(e)}


# Singleton instance
_egregore_memory: EgregoreMemory | None = None


def get_memory() -> EgregoreMemory:
    """Get or create the singleton EgregoreMemory instance."""
    global _egregore_memory
    if _egregore_memory is None:
        _egregore_memory = EgregoreMemory()
    return _egregore_memory
```

**Step 2: Verify Python syntax**

```bash
python3 -m py_compile src/memory.py && echo "Valid Python"
```

Expected: "Valid Python"

**Step 3: Commit**

```bash
git add src/memory.py
git commit -m "feat: add Mem0 memory client wrapper"
```

---

## Task 5: FastMCP Server (src/server.py)

**Files:**
- Create: `src/server.py`

**Step 1: Create server.py with FastMCP tools**

```python
"""FastMCP server for Egregore - Hive Mind Memory System."""

import json
from typing import Any

from fastmcp import FastMCP

from src.memory import get_memory

# Initialize FastMCP server
mcp = FastMCP("egregore")


@mcp.tool()
def recall_memory(query: str, limit: int = 5) -> str:
    """Search the hive mind for relevant memories.

    Use this tool BEFORE asking questions or making decisions.
    It retrieves context from previous sessions and shared knowledge.

    Args:
        query: What you're looking for (be specific)
        limit: Maximum memories to retrieve (default: 5)

    Returns:
        JSON string with matching memories
    """
    try:
        memory = get_memory()
        results = memory.recall(query=query, limit=limit)

        # Format results nicely
        formatted = {
            "query": query,
            "memories_found": len(results),
            "memories": results,
        }
        return json.dumps(formatted, indent=2, default=str)
    except Exception as e:
        return json.dumps({"error": str(e), "query": query})


@mcp.tool()
def store_memory(data: str, context: str = "", tags: str = "") -> str:
    """Store a memory in the hive mind.

    Use this to teach the collective - bugs fixed, decisions made,
    preferences learned, architecture defined.

    Args:
        data: The memory content to store
        context: Optional context (e.g., "bugfix", "architecture", "preference")
        tags: Comma-separated tags for categorization

    Returns:
        JSON string with storage result
    """
    try:
        memory = get_memory()

        # Build metadata
        metadata: dict[str, Any] = {}
        if context:
            metadata["context"] = context
        if tags:
            metadata["tags"] = [t.strip() for t in tags.split(",") if t.strip()]

        result = memory.store(data=data, metadata=metadata)

        return json.dumps(
            {
                "status": "stored",
                "memory_ids": result.get("ids", []),
                "context": context,
            },
            indent=2,
            default=str,
        )
    except Exception as e:
        return json.dumps({"error": str(e), "data": data[:100]})


@mcp.tool()
def health_check() -> str:
    """Check Egregore system health.

    Returns:
        JSON string with health status of memory stores
    """
    try:
        memory = get_memory()
        status = memory.health_check()
        return json.dumps(
            {
                "status": "healthy" if all(v for k, v in status.items() if k != "error") else "unhealthy",
                "components": status,
            },
            indent=2,
            default=str,
        )
    except Exception as e:
        return json.dumps({"status": "error", "message": str(e)})


if __name__ == "__main__":
    # Run the server with stdio transport (for MCP)
    mcp.run(transport="stdio")
```

**Step 2: Verify Python syntax**

```bash
python3 -m py_compile src/server.py && echo "Valid Python"
```

Expected: "Valid Python"

**Step 3: Commit**

```bash
git add src/server.py
git commit -m "feat: add FastMCP server with recall_memory and store_memory tools"
```

---

## Task 6: Interactive Install Script (install.sh)

**Files:**
- Create: `install.sh`

**Step 1: Create install.sh with all interactive features**

```bash
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
```

**Step 2: Make script executable**

```bash
chmod +x install.sh
```

**Step 3: Verify script syntax**

```bash
bash -n install.sh && echo "Valid Bash"
```

Expected: "Valid Bash"

**Step 4: Commit**

```bash
git add install.sh
git commit -m "feat: add interactive install.sh with full automation"
```

---

## Task 7: CLAUDE.md Template

**Files:**
- Create: `CLAUDE.md`

**Step 1: Create CLAUDE.md with Egregore Protocol**

```markdown
# EGREGORE PROTOCOL (Memoria Compartida)

> **Egregore** - Sistema de memoria persistente tipo "Hive Mind" para Claude Code.
> Este archivo activa la memoria compartida en tu proyecto.

---

## 🧠 Activación Cognitiva

Este proyecto está conectado a **Egregore**, una memoria de colmena persistente.
Tu primera acción en CUALQUIER sesión debe ser sincronizarte con la colmena.

**Ritual de inicio:**
```
1. Al iniciar sesión → recall_memory("contexto del proyecto")
2. Antes de decidir → recall_memory("decisiones previas sobre X")
3. Al encontrar errores → recall_memory("errores similares")
```

---

## 🛠 Herramientas Disponibles

### `recall_memory(query: str, limit: int = 5)`
Tu buscador. Úsalo antes de preguntar o decidir.

**Cuándo usar:**
- ✅ Al iniciar cualquier sesión
- ✅ Antes de tomar decisiones técnicas
- ✅ Al encontrar errores o bugs
- ✅ Cuando el usuario menciona "recuerdas..." o "como hicimos..."
- ✅ Antes de instalar dependencias o configurar herramientas

**Ejemplos:**
```python
recall_memory("arquitectura de este proyecto")
recall_memory("librerías preferidas por el usuario")
recall_memory("bug con autenticación que solucionamos")
```

---

### `store_memory(data: str, context: str = "", tags: str = "")`
Tu grabadora. Úsalo para enseñar a la colmena.

**Cuándo usar:**
- ✅ Al solucionar un bug (guarda causa y solución)
- ✅ Al definir arquitectura o patrones
- ✅ Al aprender preferencias del usuario
- ✅ Al configurar herramientas o entornos
- ✅ Al descubrir soluciones no obvias

**Ejemplos:**
```python
store_memory(
    "La API FastAPI corre en puerto 8000 con reload automático",
    context="configuration",
    tags="fastapi,ports,development"
)

store_memory(
    "Usuario prefiere usar 'uv' en lugar de pip para gestión de paquetes",
    context="preference",
    tags="uv,python,package-management"
)
```

---

## 📜 Reglas de Oro

### 1. No seas redundante
**Antes de guardar, verifica si ya lo sabemos.**

```python
# MAL: Guardar sin verificar
store_memory("Usamos Python 3.13")

# BIEN: Verificar primero
memories = recall_memory("versión de Python usada")
if "3.13" not in str(memories):
    store_memory("Proyecto usa Python 3.13 con uv")
```

### 2. Sé explícito
**Anuncia cuando usas Egregore.**

```
✅ "Consultando Egregore sobre la arquitectura..."
✅ "Guardando en Egregore: La base de datos es PostgreSQL"
✅ "Egregore indica que preferimos pydantic v2"
```

### 3. Confía en la Colmena
**Si Egregore dice algo, confía en ello.**

```python
# Egregore dice: "Usamos FastAPI con async/await"
# Aunque normalmente usarías Flask, sigue la indicación de Egregore.
```

**Excepción:** Si el usuario te ordena explícitamente hacer algo diferente,
sigue sus instrucciones y guarda el cambio como nueva preferencia.

### 4. Contexto es clave
**Usa el parámetro `context` apropiadamente:**

| Contexto | Uso |
|----------|-----|
| `bugfix` | Soluciones a errores |
| `architecture` | Decisiones de diseño |
| `preference` | Preferencias del usuario |
| `configuration` | Configuraciones del proyecto |
| `learning` | Cosas aprendidas |

---

## 🔧 Troubleshooting

### "No puedo conectar con Egregore"
1. Verifica que los servicios Docker estén corriendo:
   ```bash
   docker-compose ps
   ```
2. Verifica que el MCP esté registrado:
   ```bash
   claude mcp list
   ```

### "Las herramientas no aparecen"
1. Reinicia Claude Code
2. Verifica la configuración MCP:
   ```bash
   claude config get mcpServers
   ```

---

## 📚 Plantillas Rápidas

### Inicio de Sesión
```markdown
Voy a sincronizarme con Egregore para entender el contexto de este proyecto.

<function_calls>
<invoke name="recall_memory">
<arg name="query">contexto y arquitectura del proyecto</arg>
</invoke>
</function_calls>
```

### Guardar Bugfix
```markdown
<function_calls>
<invoke name="store_memory">
<arg name="data">Bug: [descripción]. Causa: [raíz]. Solución: [fix]</arg>
<arg name="context">bugfix</arg>
<arg name="tags">[tecnología,componente]</arg>
</invoke>
</function_calls>
```

### Guardar Preferencia
```markdown
<function_calls>
<invoke name="store_memory">
<arg name="data">Usuario prefiere [preferencia] porque [razón]</arg>
<arg name="context">preference</arg>
<arg name="tags">[categoría]</arg>
</invoke>
</function_calls>
```

---

*Egregore v0.1.0 - Hive Mind Memory System*
*"La memoria colectiva es más sabia que cualquier individuo"*
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "feat: add CLAUDE.md with Egregore Protocol template"
```

---

## Task 8: README.md Documentation

**Files:**
- Create: `README.md`

**Step 1: Create comprehensive README**

```markdown
# 🐝 Egregore - Hive Mind Memory for Claude Code

[![Python 3.13](https://img.shields.io/badge/python-3.13-blue.svg)](https://www.python.org/)
[![uv](https://img.shields.io/badge/uv-package%20manager-purple.svg)](https://docs.astral.sh/uv/)
[![Mem0](https://img.shields.io/badge/mem0-graph%20memory-green.svg)](https://mem0.ai)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **Persistent shared memory across all your Claude Code projects.**

Egregore is a "Hive Mind" memory system that allows Claude Code to remember context,
preferences, and knowledge across different projects and sessions. Built on [Mem0](https://mem0.ai)
with graph capabilities via Memgraph and vector search via Qdrant.

```
┌─────────────────────────────────────────────────────────────┐
│                    YOUR PROJECTS                            │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │ Project │  │ Project │  │ Project │  │ Project │  ...   │
│  │   A     │  │   B     │  │   C     │  │   D     │        │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘        │
│       └─────────────┴─────────────┴─────────────┘           │
│                       │                                     │
│              ┌────────▼────────┐                           │
│              │    EGREGORE     │  ← Shared Memory           │
│              │   (Hive Mind)   │                           │
│              └────────┬────────┘                           │
│                       │                                     │
│         ┌─────────────┼─────────────┐                      │
│         ▼             ▼             ▼                      │
│    ┌─────────┐   ┌─────────┐   ┌─────────┐                │
│    │Memgraph │   │ Qdrant  │   │ Mem0    │                │
│    │(Graph)  │   │(Vector) │   │(Engine) │                │
│    └─────────┘   └─────────┘   └─────────┘                │
└─────────────────────────────────────────────────────────────┘
```

---

## ✨ Features

- 🧠 **Persistent Memory** - Knowledge survives across sessions
- 🔗 **Graph Relationships** - Understand connections between concepts
- 🔍 **Vector Search** - Semantic memory retrieval
- 🚀 **One-Command Setup** - Interactive installer like `npm init`
- 🔌 **Claude Code Native** - Seamless MCP integration
- 🏗️ **Multi-Provider** - OpenAI or Google Gemini embeddings

---

## 🚀 Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Python 3.13](https://www.python.org/downloads/)
- [Claude Code CLI](https://claude.ai/code)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/egregore.git
cd egregore

# Run the interactive installer
./install.sh
```

The installer will:
1. ✅ Check prerequisites (and install `uv` if missing)
2. 🎛️ Ask for your embedding provider (OpenAI/Gemini) and API key
3. 🐳 Deploy Memgraph and Qdrant via Docker
4. 🔌 Register Egregore with Claude Code
5. 📋 Show you how to activate it in your projects

---

## 🛠️ Manual Setup (if you prefer)

```bash
# 1. Create virtual environment
uv venv --python 3.13
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# 2. Install dependencies
uv pip install -e "."

# 3. Configure
cp .env.example .env
# Edit .env with your API keys

# 4. Start infrastructure
docker-compose up -d

# 5. Register with Claude Code
claude mcp add egregore -- $(pwd)/.venv/bin/python $(pwd)/src/server.py
```

---

## 📖 Usage

### In Your Projects

Add this to your project's `CLAUDE.md`:

```markdown
# EGREGORE PROTOCOL

## 🧠 Activación
Este proyecto usa Egregore. Tu primera acción debe ser:
`recall_memory("contexto del proyecto")`

## 🛠 Herramientas
- `recall_memory(query)` - Buscar conocimiento previo
- `store_memory(data)` - Guardar nuevo conocimiento

## 📜 Reglas
- Consulta Egregore antes de decidir
- Guarda bugs y sus soluciones
- Sé explícito: "Guardando en Egregore..."
```

### Example Interactions

```python
# Claude consulta el contexto al iniciar
recall_memory("arquitectura y stack tecnológico de este proyecto")
# → "FastAPI async, PostgreSQL, deployed on Render..."

# Claude guarda un bugfix
store_memory(
    "Bug: CORS fallaba en producción. Solución: agregar origins explícitos",
    context="bugfix",
    tags="cors,fastapi,production"
)

# En otro proyecto, Claude recuerda
recall_memory("cómo configurar CORS en FastAPI")
# → "Egregore indica: En proyecto anterior usaste origins explícitos..."
```

---

## 🏗️ Architecture

```
┌────────────────────────────────────────────────────────────┐
│  Claude Code                                                │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  MCP Client                                          │  │
│  │  ┌─────────────┐  ┌─────────────┐                  │  │
│  │  │recall_memory│  │store_memory │                  │  │
│  │  └──────┬──────┘  └──────┬──────┘                  │  │
│  └─────────┼────────────────┼─────────────────────────┘  │
└────────────┼────────────────┼────────────────────────────┘
             │                │
             ▼                ▼
┌────────────────────────────────────────────────────────────┐
│  Egregore MCP Server (FastMCP)                             │
│  - Tool definitions                                        │
│ - Request routing                                          │
└────────────────────┬───────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────┐
│  Mem0 Client                                               │
│  - Graph operations                                        │
│  - Vector search                                           │
│  - Memory management                                       │
└──────┬───────────────────────┬─────────────────────────────┘
       │                       │
       ▼                       ▼
┌──────────────┐      ┌──────────────┐
│  Memgraph    │      │   Qdrant     │
│  (Graph DB)  │◄────►│ (Vector DB)  │
│  - Entities  │      │  - Embeddings│
│  - Relations │      │  - Search    │
└──────────────┘      └──────────────┘
```

---

## 📁 Project Structure

```
egregore/
├── src/
│   ├── __init__.py
│   ├── config.py          # Pydantic settings management
│   ├── memory.py          # Mem0 client wrapper
│   └── server.py          # FastMCP server
├── docker-compose.yml     # Memgraph + Qdrant
├── pyproject.toml         # Python dependencies
├── install.sh             # Interactive installer ⭐
├── CLAUDE.md              # Template for your projects
└── README.md              # This file
```

---

## ⚙️ Configuration

Environment variables (set in `.env`):

| Variable | Description | Default |
|----------|-------------|---------|
| `INSTANCE_NAME` | Name of your Egregore instance | `egregore_collective` |
| `EMBEDDING_PROVIDER` | `openai` or `gemini` | `openai` |
| `EMBEDDING_API_KEY` | API key for embeddings | (required) |
| `MEMGRAPH_HOST` | Memgraph hostname | `localhost` |
| `MEMGRAPH_PORT` | Memgraph Bolt port | `7687` |
| `QDRANT_HOST` | Qdrant hostname | `localhost` |
| `QDRANT_PORT` | Qdrant HTTP port | `6333` |

---

## 🧪 Development

```bash
# Run tests
uv run pytest

# Type checking
uv run mypy src/

# Linting
uv run ruff check src/
uv run ruff format src/

# View logs
docker-compose logs -f

# Reset data (⚠️ destroys all memories)
docker-compose down -v
```

---

## 🤝 Contributing

Contributions welcome! Please read our [Contributing Guide](CONTRIBUTING.md).

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file.

---

## 🙏 Acknowledgments

- [Mem0](https://mem0.ai) - The memory layer that powers Egregore
- [Memgraph](https://memgraph.com) - High-performance graph database
- [Qdrant](https://qdrant.tech) - Vector similarity search engine
- [FastMCP](https://github.com/jlowin/fastmcp) - Fast MCP server framework

---

<div align="center">

**"La memoria colectiva es más sabia que cualquier individuo"**

🐝 *Egregore - Hive Mind Memory System* 🐝

</div>
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "feat: add comprehensive README with architecture diagrams"
```

---

## Task 9: .env.example Template

**Files:**
- Create: `.env.example`

**Step 1: Create example environment file**

```bash
cat > .env.example << 'EOF'
# Egregore Configuration Template
# Copy this file to .env and fill in your values

# Instance Configuration
INSTANCE_NAME=egregore_collective

# Embedding Provider
# Options: openai, gemini
EMBEDDING_PROVIDER=openai

# API Key for your chosen provider
# OpenAI: https://platform.openai.com/api-keys
# Gemini: https://aistudio.google.com/app/apikey
EMBEDDING_API_KEY=your_api_key_here

# Memgraph Configuration (Graph Database)
MEMGRAPH_HOST=localhost
MEMGRAPH_PORT=7687
MEMGRAPH_USER=
MEMGRAPH_PASSWORD=

# Qdrant Configuration (Vector Database)
QDRANT_HOST=localhost
QDRANT_PORT=6333
EOF
```

**Step 2: Commit**

```bash
git add .env.example
git commit -m "feat: add .env.example template"
```

---

## Task 10: .gitignore

**Files:**
- Create: `.gitignore`

**Step 1: Create .gitignore**

```bash
cat > .gitignore << 'EOF'
# Environment variables
.env
.env.local
.env.*.local

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Virtual environments
.venv/
venv/
ENV/
env/

# IDEs
.idea/
.vscode/
*.swp
*.swo
*~
.DS_Store

# Testing
.pytest_cache/
.coverage
htmlcov/
.tox/

# Docker
.dockerignore

# Logs
*.log
logs/
EOF
```

**Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: add .gitignore"
```

---

## Summary

This implementation plan creates a complete Egregore system with:

| Component | Purpose |
|-----------|---------|
| `pyproject.toml` | Python 3.13 project with uv, mem0ai[graph], fastmcp |
| `docker-compose.yml` | Memgraph MAGE + Qdrant infrastructure |
| `src/config.py` | Pydantic settings with validation |
| `src/memory.py` | Mem0 client wrapper with graph+vector stores |
| `src/server.py` | FastMCP server exposing recall/store tools |
| `install.sh` | Interactive installer with visual feedback |
| `CLAUDE.md` | Protocol template for user projects |
| `README.md` | Complete documentation with architecture |

**Execution Order:** Tasks 1-10 in sequence, each with verification steps and commits.
