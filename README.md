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
