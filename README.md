# 🐝 Egregore - Hive Mind Memory for Claude Code

[![Python 3.13](https://img.shields.io/badge/python-3.13-blue.svg)](https://www.python.org/)
[![uv](https://img.shields.io/badge/uv-package%20manager-purple.svg)](https://docs.astral.sh/uv/)
[![Mem0](https://img.shields.io/badge/mem0-graph%20memory-green.svg)](https://mem0.ai)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **Persistent shared memory across all your Claude Code projects.**

Egregore is a "Hive Mind" memory system that allows Claude Code to remember context,
preferences, and knowledge across different projects and sessions. Built on [Mem0](https://mem0.ai)
with graph capabilities via Kuzu and vector search via Qdrant.

## 🆕 SSE Architecture (v2.0)

Egregore now uses **SSE (Server-Sent Events)** transport, allowing multiple Claude Code instances
to connect to a single centralized memory server. No more multiple processes—one brain, many clients.

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
│              │  Claude Code    │                           │
│              │  (MCP Client)   │                           │
│              └────────┬────────┘                           │
│                       │ SSE (HTTP)                        │
└───────────────────────┼─────────────────────────────────────┘
                        │
              ┌─────────▼──────────┐
              │  Egregore Server   │  ← Single Instance
              │  Port: 9000        │    (Singleton via lock)
              └─────────┬──────────┘
                        │
         ┌──────────────┼──────────────┐
         ▼              ▼              ▼
    ┌─────────┐   ┌─────────┐   ┌─────────┐
    │  Kuzu   │   │ Qdrant  │   │  Mem0   │
    │ (Graph) │   │(Vector) │   │(Engine) │
    └─────────┘   └─────────┘   └─────────┘
```

## ✨ Features

- 🧠 **Persistent Memory** - Knowledge survives across sessions
- 🔗 **Graph Relationships** - Understand connections between concepts (Kuzu)
- 🔍 **Vector Search** - Semantic memory retrieval (Qdrant)
- 🚀 **One-Command Setup** - Interactive installer like `npm init`
- 🌐 **SSE Transport** - Centralized server for multiple Claude instances
- 🔌 **Claude Code Native** - Seamless MCP integration
- 🏗️ **Multi-Provider** - OpenAI or Google Gemini embeddings
- 📊 **Web Dashboard** - Visual graph exploration

## 🚀 Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Python 3.13](https://www.python.org/downloads/)
- [Claude Code CLI](https://claude.ai/code)

### Installation

```bash
# Clone the repository
git clone https://github.com/Zurybr/egregore.git
cd egregore

# Run the interactive installer
./install.sh
```

The installer will:
1. ✅ Check prerequisites (and install `uv` if missing)
2. 🎛️ Ask for your embedding provider (OpenAI/Gemini) and API key
3. 🐳 Deploy Qdrant via Docker (Kuzu is embedded, no container needed)
4. 🚀 Start the SSE server on port 9000
5. 🔌 Register Egregore with Claude Code (SSE transport)
6. 📋 Show you how to activate it in your projects

### Quick Initialization (if already installed)

```bash
# Just start the server and infrastructure
./init.sh
```

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

# 4. Start infrastructure (Qdrant only)
docker-compose up -d

# 5. Start the SSE server
egregore-server start
```

## 📖 Usage

### Server Management

```bash
# Check server status
egregore-server status

# View logs
egregore-server logs -f

# Restart server
egregore-server restart

# Stop server
egregore-server stop
```

### In Your Projects

Add these directives to your `CLAUDE.md`, `.cursorrules`, or equivalent:

```markdown
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
```

### Example Interactions

```python
# Claude consults context when starting
recall_memory("architecture and tech stack of this project")
# → "FastAPI async, PostgreSQL, deployed on Render..."

# Claude saves a bugfix
store_memory(
    "Bug: CORS failed in production. Fix: add explicit origins",
    context="bugfix",
    tags="cors,fastapi,production"
)

# In another project, Claude remembers
recall_memory("how to configure CORS in FastAPI")
# → "Egregore indicates: In previous project you used explicit origins..."
```

## 🏗️ Architecture

### SSE Transport

```
┌────────────────────────────────────────────────────────────┐
│  Multiple Claude Code Instances                             │
│  ┌─────────────────┐  ┌─────────────────┐                 │
│  │  Claude (Local) │  │ Claude (Remote) │  ...            │
│  │  MCP Client     │  │  MCP Client     │                 │
│  └────────┬────────┘  └────────┬────────┘                 │
│           │                    │                          │
│           └────────┬───────────┘                          │
│                    │ SSE (HTTP)                           │
└────────────────────┼──────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────┐
│  Egregore SSE Server (FastMCP)                             │
│  - Singleton instance (file lock)                          │
│  - Port: 9000 (configurable)                               │
│  - Multiple client support                                 │
└────────────────────┬───────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────┐
│  Mem0 Client                                               │
│  - Graph operations (Kuzu)                                 │
│  - Vector search (Qdrant)                                  │
│  - Memory management                                       │
└──────┬───────────────────────┬─────────────────────────────┘
       │                       │
       ▼                       ▼
┌──────────────┐      ┌──────────────┐
│    Kuzu      │      │   Qdrant     │
│  (Graph DB)  │      │ (Vector DB)  │
│  - Embedded  │      │  - Docker    │
│  - No auth   │      │  - Port 6333 │
└──────────────┘      └──────────────┘
```

### Data Storage

| Component | Technology | Type | Persistence |
|-----------|-----------|------|-------------|
| Graph | Kuzu | Embedded | `/tmp/egregore_kuzu.db` |
| Vectors | Qdrant | Docker | Named volume |
| Config | File | - | `.env` |
| Logs | File | - | `/tmp/egregore.log` |

## 📁 Project Structure

```
egregore/
├── src/
│   ├── __init__.py
│   ├── config.py          # Pydantic settings management
│   ├── dashboard.py       # Streamlit dashboard
│   ├── graph_client.py    # Direct Kuzu client (for dashboard)
│   ├── cli.py             # egregore-server CLI
│   ├── memory.py          # Mem0 client wrapper
│   └── server.py          # FastMCP SSE server
├── docs/
│   └── DASHBOARD.md       # Dashboard documentation
├── docker-compose.yml     # Qdrant only (Kuzu is embedded)
├── pyproject.toml         # Python dependencies
├── install.sh             # Interactive installer ⭐
├── init.sh                # Quick initialization
├── uninstall.sh           # Complete removal
├── CLAUDE.md              # Template for your projects
└── README.md              # This file
```

## ⚙️ Configuration

Environment variables (set in `.env`):

| Variable | Description | Default |
|----------|-------------|---------|
| `INSTANCE_NAME` | Name of your Egregore instance | `egregore_collective` |
| `EMBEDDING_PROVIDER` | `openai` or `gemini` | `openai` |
| `EMBEDDING_API_KEY` | API key for embeddings | (required) |
| `EGREGORE_HOST` | Server bind address | `0.0.0.0` |
| `EGREGORE_PORT` | Server port | `9000` |
| `QDRANT_HOST` | Qdrant hostname | `localhost` |
| `QDRANT_PORT` | Qdrant HTTP port | `6333` |

### MCP Client Configuration

Claude Code connects via SSE (configured automatically by `install.sh`):

```json
{
  "mcpServers": {
    "egregore": {
      "type": "sse",
      "url": "http://localhost:9000/sse"
    }
  }
}
```

For remote access, replace `localhost` with your server's IP.

## 🧪 Development

```bash
# Run tests
uv run pytest

# Type checking
uv run mypy src/

# Linting
uv run ruff check src/
uv run ruff format src/

# View infrastructure logs
docker-compose logs -f

# Reset data (⚠️ destroys all memories)
docker-compose down -v
rm -rf /tmp/egregore_kuzu.db
```

---

## 📊 Dashboard

Egregore includes a web-based dashboard for visualizing and managing your memory graph.

### Start the Dashboard

```bash
# Activate virtual environment
source .venv/bin/activate

# Start dashboard
egregore-dashboard
# or: streamlit run src/dashboard.py
```

Then open http://localhost:8501 in your browser.

### Dashboard Features

- 🕸️ **Interactive Graph**: Visualize memory connections
- ➕ **Add Memories**: Create new memories via web UI
- 🔗 **Add Relations**: Connect memories with relationships
- 📋 **List View**: Search and manage all memories
- 📊 **Statistics**: View graph metrics

See [docs/DASHBOARD.md](docs/DASHBOARD.md) for detailed documentation.

## 🔄 Migration from stdio (v1.x)

If you were using the old stdio transport:

```bash
# 1. Stop any running old processes
pkill -f "egregore.*server.py"

# 2. Run the new installer (updates MCP config to SSE)
./install.sh

# 3. Or manually update ~/.claude.json:
# Change "type": "stdio" to "type": "sse"
# Replace "command"/"args" with "url": "http://localhost:9000/sse"
```

The uninstall script handles both versions:
```bash
./uninstall.sh  # Removes stdio and SSE configurations
```

## 🤝 Contributing

Contributions welcome! Please read our [Contributing Guide](CONTRIBUTING.md).

## 📄 License

MIT License - see [LICENSE](LICENSE) file.

## 🙏 Acknowledgments

- [Mem0](https://mem0.ai) - The memory layer that powers Egregore
- [Kuzu](https://kuzudb.com) - Embedded graph database
- [Qdrant](https://qdrant.tech) - Vector similarity search engine
- [FastMCP](https://github.com/jlowin/fastmcp) - Fast MCP server framework

<div align="center">

**"Collective memory is wiser than any individual"**

🐝 *Egregore - Hive Mind Memory System* 🐝

</div>
