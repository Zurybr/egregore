# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Development Commands

```bash
# Install dependencies (uses uv package manager)
uv pip install -e "."

# Run tests
uv run pytest

# Run single test
uv run pytest tests/test_graph_client.py::test_init

# Type checking
uv run mypy src/

# Linting (check)
uv run ruff check src/

# Linting (format)
uv run ruff format src/

# Start infrastructure (Memgraph + Qdrant)
docker-compose up -d

# View infrastructure logs
docker-compose logs -f

# Reset all data (⚠️ destroys all memories)
docker-compose down -v

# Start the web dashboard
streamlit run src/dashboard.py
# or
egregore-dashboard

# Test the MCP server manually
python -m src.server
```

---

## Architecture Overview

Egregore is a dual-path memory system with two separate access patterns:

### Path 1: MCP Integration (Claude Code)
- **Entry point:** `src/server.py` (FastMCP server)
- **Client:** `src/memory.py` (Mem0 wrapper)
- **Purpose:** Semantic search + graph-based memory storage via Mem0
- **Tools:** `recall_memory()`, `store_memory()`, `health_check()`
- **Flow:** Claude Code → FastMCP → Mem0 → (Memgraph + Qdrant)

### Path 2: Web Dashboard (Direct Access)
- **Entry point:** `src/dashboard.py` (Streamlit app)
- **Client:** `src/graph_client.py` (direct Neo4j driver to Memgraph)
- **Purpose:** Visual graph exploration, CRUD operations, statistics
- **Flow:** Dashboard → Neo4j driver → Memgraph (bypasses Mem0)

**Key architectural decision:** The dashboard bypasses Mem0 entirely and queries Memgraph directly via Cypher queries. This is intentional - Mem0's graph operations are limited, so direct Cypher access provides more flexibility for the dashboard visualization and CRUD operations.

### Data Flow

```
┌─────────────┐                              ┌─────────────┐
│ Claude Code │──MCP (stdio)──→ src/server.py│              │
└─────────────┘                              │              │
                                              │   Mem0      │
┌─────────────┐                              │  (memory.py) │
│  Dashboard  │──Neo4j driver──→ graph_client │              │
└─────────────┘                              └──────┬───────┘
                                                     │
                            ┌──────────────────────────┴─────────┐
                            ▼                                    ▼
                     ┌──────────────┐                    ┌──────────────┐
                     │  Memgraph    │◄──────────────────►│   Qdrant     │
                     │  (Graph DB)  │                    │  (Vector DB) │
                     └──────────────┘                    └──────────────┘
```

---

## Configuration

Configuration is managed via `src/config.py` using Pydantic Settings:

- Loads from `.env` file automatically
- Singleton pattern: `get_settings()` returns cached instance
- Key settings: `EMBEDDING_PROVIDER` (openai/gemini), `INSTANCE_NAME`, connection URIs

The `.env` file should contain:
- `EMBEDDING_API_KEY` - Required for embeddings
- `INSTANCE_NAME` - Collection name in Qdrant
- `MEMGRAPH_HOST`, `MEMGRAPH_PORT`, `QDRANT_HOST`, `QDRANT_PORT`

---

## Memgraph Cypher Notes

When working with `GraphClient` or dashboard queries:

- Nodes are labeled `Memory` with properties: `id`, `data`, `created_at`, `metadata`
- Relationships can be any type (e.g., `RELATED_TO`, `DEPENDS_ON`, `FIXES`)
- Use `MATCH (m:Memory)` for querying nodes
- Use `DETACH DELETE` to delete nodes and their relationships
- Memgraph is Neo4j-compatible - standard Cypher applies

---

## Dual Storage Sync

**Important:** Memories added via MCP (`store_memory`) go through Mem0 and are stored in BOTH Memgraph (graph) and Qdrant (vector). Memories added via the dashboard (`GraphClient.create_memory`) are stored ONLY in Memgraph.

This means:
- Dashboard-only memories won't appear in semantic searches via `recall_memory`
- MCP-added memories will appear in the dashboard (they're in Memgraph)
- For consistency, prefer using MCP for memory storage when possible

---

## Entry Points

- **MCP Server:** `python -m src.server` (or registered via `claude mcp add`)
- **Dashboard:** `streamlit run src/dashboard.py` or `egregore-dashboard` command

---

## Code Style

- Python 3.13 with type hints
- Pydantic v2 for settings/validation
- Ruff for linting (line length: 100)
- mypy strict mode enabled
- Singleton pattern used for clients (`get_memory()`, `get_graph_client()`)

---

## Testing

Tests are in `tests/` using pytest. The GraphClient tests use mocks for the Neo4j driver since it requires a running Memgraph instance.
