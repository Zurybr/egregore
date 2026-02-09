# Egregore Dashboard - Interactive Graph Visualization

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an interactive web dashboard for visualizing and managing the Egregore memory graph, allowing users to view, add, and connect memories through a visual interface.

**Architecture:** Streamlit-based web application with direct Memgraph connectivity via neo4j-driver. Uses streamlit-agraph for interactive graph visualization and provides forms for CRUD operations on memories and relationships.

**Tech Stack:** Streamlit, streamlit-agraph, neo4j-driver, pandas

---

## Task 1: Update Dependencies in pyproject.toml

**Files:**
- Modify: `pyproject.toml`

**Step 1: Add dashboard dependencies**

Add to the `[project.dependencies]` section:
```toml
dependencies = [
    "mem0ai[graph]>=0.1.0",
    "fastmcp>=0.4.0",
    "pydantic>=2.0.0",
    "pydantic-settings>=2.0.0",
    "streamlit>=1.40.0",
    "streamlit-agraph>=0.1.0",
    "neo4j>=5.0.0",
    "pandas>=2.0.0",
]
```

**Step 2: Add dashboard script entry point**

Add to the `[project.scripts]` section:
```toml
[project.scripts]
egregore-dashboard = "src.dashboard:main"
```

**Step 3: Verify TOML syntax**

Run: `python3 -c "import tomllib; tomllib.load(open('pyproject.toml', 'rb'))" && echo "Valid TOML"`

Expected: "Valid TOML"

**Step 4: Commit**

```bash
git add pyproject.toml
git commit -m "feat: add dashboard dependencies (streamlit, neo4j, pandas)"
```

---

## Task 2: Create Graph Client Module

**Files:**
- Create: `src/graph_client.py`

**Step 1: Create graph_client.py**

```python
"""Direct Memgraph client for dashboard operations."""

from typing import Any

from neo4j import GraphDatabase

from src.config import Settings, get_settings


class GraphClient:
    """Client for direct Memgraph graph operations."""

    def __init__(self, settings: Settings | None = None) -> None:
        """Initialize graph client.

        Args:
            settings: Configuration settings
        """
        self.settings = settings or get_settings()
        self._driver = None

    @property
    def driver(self) -> GraphDatabase.driver:
        """Lazy initialization of Neo4j driver."""
        if self._driver is None:
            self._driver = GraphDatabase.driver(
                self.settings.memgraph_uri,
                auth=(
                    self.settings.memgraph_user or "",
                    self.settings.memgraph_password.get_secret_value()
                    if self.settings.memgraph_password
                    else "",
                ),
            )
        return self._driver

    def close(self) -> None:
        """Close the driver connection."""
        if self._driver:
            self._driver.close()
            self._driver = None

    def get_all_memories(self) -> list[dict[str, Any]]:
        """Get all memory nodes from the graph.

        Returns:
            List of memory nodes with their properties
        """
        query = """
        MATCH (m:Memory)
        RETURN m.id as id, m.data as data, m.created_at as created_at,
               m.metadata as metadata, labels(m) as labels
        LIMIT 1000
        """
        with self.driver.session() as session:
            result = session.run(query)
            return [dict(record) for record in result]

    def get_all_relationships(self) -> list[dict[str, Any]]:
        """Get all relationships between memories.

        Returns:
            List of relationships with source and target IDs
        """
        query = """
        MATCH (m1:Memory)-[r]->(m2:Memory)
        RETURN m1.id as source, m2.id as target, type(r) as type, r as properties
        LIMIT 1000
        """
        with self.driver.session() as session:
            result = session.run(query)
            return [dict(record) for record in result]

    def create_memory(self, data: str, metadata: dict | None = None) -> str:
        """Create a new memory node.

        Args:
            data: The memory content
            metadata: Optional metadata dictionary

        Returns:
            ID of the created memory
        """
        import uuid
        from datetime import datetime

        memory_id = str(uuid.uuid4())
        metadata = metadata or {}

        query = """
        CREATE (m:Memory {
            id: $id,
            data: $data,
            created_at: $created_at,
            metadata: $metadata
        })
        RETURN m.id as id
        """

        with self.driver.session() as session:
            result = session.run(
                query,
                id=memory_id,
                data=data,
                created_at=datetime.now().isoformat(),
                metadata=str(metadata),
            )
            return result.single()["id"]

    def create_relationship(
        self, source_id: str, target_id: str, rel_type: str = "RELATED_TO"
    ) -> bool:
        """Create a relationship between two memories.

        Args:
            source_id: ID of the source memory
            target_id: ID of the target memory
            rel_type: Type of relationship

        Returns:
            True if created successfully
        """
        query = f"""
        MATCH (m1:Memory {{id: $source_id}})
        MATCH (m2:Memory {{id: $target_id}})
        CREATE (m1)-[r:{rel_type}]->(m2)
        RETURN r
        """

        with self.driver.session() as session:
            result = session.run(query, source_id=source_id, target_id=target_id)
            return result.single() is not None

    def delete_memory(self, memory_id: str) -> bool:
        """Delete a memory node and its relationships.

        Args:
            memory_id: ID of the memory to delete

        Returns:
            True if deleted successfully
        """
        query = """
        MATCH (m:Memory {id: $id})
        DETACH DELETE m
        RETURN count(m) as deleted
        """

        with self.driver.session() as session:
            result = session.run(query, id=memory_id)
            return result.single()["deleted"] > 0

    def search_memories(self, query_text: str) -> list[dict[str, Any]]:
        """Search memories by content.

        Args:
            query_text: Search query

        Returns:
            List of matching memories
        """
        query = """
        MATCH (m:Memory)
        WHERE m.data CONTAINS $query
        RETURN m.id as id, m.data as data, m.created_at as created_at,
               m.metadata as metadata
        LIMIT 100
        """

        with self.driver.session() as session:
            result = session.run(query, query=query_text)
            return [dict(record) for record in result]

    def get_statistics(self) -> dict[str, int]:
        """Get graph statistics.

        Returns:
            Dictionary with node count, relationship count, etc.
        """
        queries = {
            "memory_count": "MATCH (m:Memory) RETURN count(m) as count",
            "relation_count": "MATCH ()-[r]->() RETURN count(r) as count",
            "unique_relations": "MATCH ()-[r]->() RETURN count(DISTINCT type(r)) as count",
        }

        stats = {}
        with self.driver.session() as session:
            for key, query in queries.items():
                result = session.run(query)
                stats[key] = result.single()["count"]

        # Calculate density (simplified)
        n = stats.get("memory_count", 0)
        e = stats.get("relation_count", 0)
        stats["density"] = round(e / (n * (n - 1)) if n > 1 else 0, 4)

        return stats


# Singleton instance
_graph_client: GraphClient | None = None


def get_graph_client() -> GraphClient:
    """Get or create the singleton GraphClient instance."""
    global _graph_client
    if _graph_client is None:
        _graph_client = GraphClient()
    return _graph_client
```

**Step 2: Verify Python syntax**

Run: `python3 -m py_compile src/graph_client.py && echo "Valid Python"`

Expected: "Valid Python"

**Step 3: Commit**

```bash
git add src/graph_client.py
git commit -m "feat: add GraphClient for direct Memgraph operations"
```

---

## Task 3: Create Streamlit Dashboard

**Files:**
- Create: `src/dashboard.py`

**Step 1: Create dashboard.py**

```python
"""Egregore Dashboard - Interactive Graph Visualization."""

import pandas as pd
import streamlit as st
from agraph import Config, Edge, Node, agraph

from src.graph_client import GraphClient, get_graph_client

# Page configuration
st.set_page_config(
    page_title="Egregore Dashboard",
    page_icon="🐝",
    layout="wide",
    initial_sidebar_state="expanded",
)


def init_session_state():
    """Initialize session state variables."""
    if "client" not in st.session_state:
        st.session_state.client = get_graph_client()
    if "refresh" not in st.session_state:
        st.session_state.refresh = False


def render_header():
    """Render the dashboard header."""
    col1, col2 = st.columns([6, 1])
    with col1:
        st.title("🐝 Egregore Dashboard")
        st.markdown("*Visualize and manage your Hive Mind memory*")
    with col2:
        if st.button("🔄 Refresh", use_container_width=True):
            st.session_state.refresh = True
            st.rerun()


def render_statistics(client: GraphClient):
    """Render statistics cards."""
    stats = client.get_statistics()

    col1, col2, col3, col4 = st.columns(4)

    with col1:
        st.metric("🧠 Memories", stats.get("memory_count", 0))
    with col2:
        st.metric("🔗 Relations", stats.get("relation_count", 0))
    with col3:
        st.metric("📊 Density", f"{stats.get('density', 0):.4f}")
    with col4:
        st.metric("🏷️ Relation Types", stats.get("unique_relations", 0))


def render_graph_visualization(client: GraphClient):
    """Render the interactive graph visualization."""
    st.subheader("🕸️ Memory Graph")

    # Get data
    memories = client.get_all_memories()
    relationships = client.get_all_relationships()

    if not memories:
        st.info("No memories found. Add some memories to see the graph!")
        return

    # Create nodes
    nodes = []
    for mem in memories:
        node_id = mem.get("id", "unknown")
        # Truncate data for display
        data = mem.get("data", "")
        label = data[:30] + "..." if len(data) > 30 else data

        nodes.append(
            Node(
                id=node_id,
                label=label,
                title=data,  # Tooltip
                size=20,
                color="#00C49A" if "bugfix" in str(mem.get("metadata", "")) else "#0088FE",
            )
        )

    # Create edges
    edges = []
    for rel in relationships:
        edges.append(
            Edge(
                source=rel.get("source"),
                target=rel.get("target"),
                label=rel.get("type", "RELATED_TO"),
                color="#888888",
            )
        )

    # Graph configuration
    config = Config(
        width="100%",
        height=500,
        directed=True,
        physics=True,
        hierarchical=False,
        nodeHighlightBehavior=True,
        highlightColor="#F7C331",
        collapsible=False,
    )

    # Render graph
    agraph(nodes=nodes, edges=edges, config=config)


def render_add_memory(client: GraphClient):
    """Render form to add new memory."""
    st.subheader("➕ Add Memory")

    with st.form("add_memory_form"):
        data = st.text_area("Memory Content", height=100)
        col1, col2 = st.columns(2)
        with col1:
            context = st.selectbox(
                "Context",
                ["", "bugfix", "architecture", "preference", "configuration", "learning"],
            )
        with col2:
            tags = st.text_input("Tags (comma-separated)")

        submitted = st.form_submit_button("Add Memory", use_container_width=True)

        if submitted and data:
            metadata = {}
            if context:
                metadata["context"] = context
            if tags:
                metadata["tags"] = [t.strip() for t in tags.split(",") if t.strip()]

            try:
                memory_id = client.create_memory(data, metadata)
                st.success(f"Memory created! ID: {memory_id[:8]}...")
                st.session_state.refresh = True
            except Exception as e:
                st.error(f"Error creating memory: {e}")


def render_add_relation(client: GraphClient):
    """Render form to add relationship."""
    st.subheader("🔗 Add Relationship")

    memories = client.get_all_memories()
    if len(memories) < 2:
        st.info("Need at least 2 memories to create a relationship.")
        return

    memory_options = {m["id"]: f"{m['data'][:40]}..." for m in memories}

    with st.form("add_relation_form"):
        col1, col2 = st.columns(2)
        with col1:
            source_id = st.selectbox(
                "From Memory",
                options=list(memory_options.keys()),
                format_func=lambda x: memory_options.get(x, x),
            )
        with col2:
            target_id = st.selectbox(
                "To Memory",
                options=list(memory_options.keys()),
                format_func=lambda x: memory_options.get(x, x),
            )

        rel_type = st.selectbox(
            "Relationship Type",
            ["RELATED_TO", "DEPENDS_ON", "FIXES", "IMPLEMENTS", "REFERENCES"],
        )

        submitted = st.form_submit_button("Add Relationship", use_container_width=True)

        if submitted:
            if source_id == target_id:
                st.error("Cannot create relationship to the same memory!")
            else:
                try:
                    success = client.create_relationship(source_id, target_id, rel_type)
                    if success:
                        st.success("Relationship created!")
                        st.session_state.refresh = True
                    else:
                        st.error("Failed to create relationship.")
                except Exception as e:
                    st.error(f"Error: {e}")


def render_memory_list(client: GraphClient):
    """Render the memory list table."""
    st.subheader("📋 Memory List")

    # Search
    search_query = st.text_input("🔍 Search memories", "")

    if search_query:
        memories = client.search_memories(search_query)
    else:
        memories = client.get_all_memories()

    if not memories:
        st.info("No memories found.")
        return

    # Convert to DataFrame for display
    df_data = []
    for mem in memories:
        df_data.append({
            "ID": mem.get("id", "")[:8] + "...",
            "Content": mem.get("data", "")[:100] + "...",
            "Created": mem.get("created_at", "")[:19],
            "Metadata": str(mem.get("metadata", ""))[:50],
        })

    df = pd.DataFrame(df_data)
    st.dataframe(df, use_container_width=True, hide_index=True)

    # Delete memory section
    st.subheader("🗑️ Delete Memory")
    memory_options = {m["id"]: f"{m['data'][:50]}..." for m in memories}

    col1, col2 = st.columns([3, 1])
    with col1:
        to_delete = st.selectbox(
            "Select memory to delete",
            options=list(memory_options.keys()),
            format_func=lambda x: memory_options.get(x, x),
            key="delete_select",
        )
    with col2:
        if st.button("Delete", use_container_width=True, type="primary"):
            try:
                success = client.delete_memory(to_delete)
                if success:
                    st.success("Memory deleted!")
                    st.session_state.refresh = True
                else:
                    st.error("Failed to delete.")
            except Exception as e:
                st.error(f"Error: {e}")


def main():
    """Main dashboard application."""
    init_session_state()
    client = st.session_state.client

    render_header()

    # Statistics
    render_statistics(client)

    st.divider()

    # Main content in tabs
    tab1, tab2, tab3 = st.tabs(["🕸️ Graph View", "➕ Add Content", "📋 List View"])

    with tab1:
        render_graph_visualization(client)

    with tab2:
        col1, col2 = st.columns(2)
        with col1:
            render_add_memory(client)
        with col2:
            render_add_relation(client)

    with tab3:
        render_memory_list(client)

    # Footer
    st.divider()
    st.caption("Egregore Dashboard v0.1.0 - Hive Mind Memory System")


if __name__ == "__main__":
    main()
```

**Step 2: Verify Python syntax**

Run: `python3 -m py_compile src/dashboard.py && echo "Valid Python"`

Expected: "Valid Python"

**Step 3: Commit**

```bash
git add src/dashboard.py
git commit -m "feat: add Streamlit dashboard with graph visualization"
```

---

## Task 4: Create Dashboard Documentation

**Files:**
- Create: `docs/DASHBOARD.md`

**Step 1: Create DASHBOARD.md**

```markdown
# Egregore Dashboard

Interactive web dashboard for visualizing and managing your Egregore memory graph.

## 🚀 Quick Start

### Start the Dashboard

```bash
# Make sure you're in the project directory
cd egregore

# Activate virtual environment
source .venv/bin/activate

# Start the dashboard
streamlit run src/dashboard.py

# Or use the installed command
egregore-dashboard
```

The dashboard will open automatically in your browser at `http://localhost:8501`.

## 📊 Features

### 1. Statistics Overview
View key metrics about your memory graph:
- **Memories**: Total number of memory nodes
- **Relations**: Total number of connections
- **Density**: Graph density metric
- **Relation Types**: Number of unique relationship types

### 2. Graph Visualization
Interactive visualization of your memory graph:
- **Nodes**: Represent individual memories
- **Edges**: Show relationships between memories
- **Colors**: Different colors for different contexts
- **Tooltips**: Hover to see full memory content
- **Interactive**: Click and drag to explore

### 3. Add Memory
Create new memories directly from the UI:
- Enter memory content
- Select context (bugfix, architecture, preference, etc.)
- Add tags for categorization

### 4. Add Relationship
Connect memories with relationships:
- Select source and target memories
- Choose relationship type:
  - `RELATED_TO`: General connection
  - `DEPENDS_ON`: Dependency relationship
  - `FIXES`: Bug fix relationship
  - `IMPLEMENTS`: Implementation link
  - `REFERENCES`: Reference link

### 5. Memory List
Table view of all memories:
- Search by content
- View metadata
- Delete memories

## 🎨 Graph Colors

Nodes are colored based on context:
- **Green (#00C49A)**: Bug fixes
- **Blue (#0088FE)**: General memories
- **Yellow (#F7C331)**: Highlighted/selected

## 🔧 Configuration

The dashboard uses the same `.env` file as Egregore:

```env
MEMGRAPH_HOST=localhost
MEMGRAPH_PORT=7687
MEMGRAPH_USER=
MEMGRAPH_PASSWORD=
```

## 🐛 Troubleshooting

### "Cannot connect to Memgraph"
- Verify Memgraph is running: `docker-compose ps`
- Check your `.env` configuration
- Ensure ports are correct

### "No module named 'streamlit'"
- Install dependencies: `uv pip install -e "."`
- Activate virtual environment

### Dashboard won't start
- Check if port 8501 is available
- Try: `streamlit run src/dashboard.py --server.port 8502`

## 📸 Screenshot

```
┌─────────────────────────────────────────────────────────────┐
│  🐝 Egregore Dashboard                        [Refresh]     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  Memories   │  │ Relations   │  │    Graph Density    │ │
│  │    142      │  │    89       │  │       0.45          │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  [Interactive Graph Visualization]                         │
├─────────────────────────────────────────────────────────────┤
│  [Add Memory]  [Add Relation]  [Search: __________]        │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 Integration with Claude Code

The dashboard works alongside the Claude Code MCP integration:
- Memories added via `store_memory()` appear in the dashboard
- Memories added via dashboard are available to Claude
- Both use the same Memgraph database

## 🛣️ Roadmap

Future features:
- [ ] Edit memories inline
- [ ] Bulk import/export
- [ ] Advanced graph filtering
- [ ] Memory similarity visualization
- [ ] Time-based memory exploration
```

**Step 2: Commit**

```bash
git add docs/DASHBOARD.md
git commit -m "docs: add dashboard documentation"
```

---

## Task 5: Update README with Dashboard Info

**Files:**
- Modify: `README.md`

**Step 1: Add dashboard section to README**

Add after the "Development" section:

```markdown
---

## 📊 Dashboard

Egregore includes a web-based dashboard for visualizing and managing your memory graph.

### Start the Dashboard

```bash
# Activate virtual environment
source .venv/bin/activate

# Start dashboard
streamlit run src/dashboard.py
```

Then open http://localhost:8501 in your browser.

### Dashboard Features

- 🕸️ **Interactive Graph**: Visualize memory connections
- ➕ **Add Memories**: Create new memories via web UI
- 🔗 **Add Relations**: Connect memories with relationships
- 📋 **List View**: Search and manage all memories
- 📊 **Statistics**: View graph metrics

See [docs/DASHBOARD.md](docs/DASHBOARD.md) for detailed documentation.

---
```

**Step 2: Add dashboard to project structure**

Update the project structure section to include:

```
egregore/
├── src/
│   ├── __init__.py
│   ├── config.py          # Pydantic settings management
│   ├── dashboard.py       # 🆕 Streamlit dashboard
│   ├── graph_client.py    # 🆕 Direct Memgraph client
│   ├── memory.py          # Mem0 client wrapper
│   └── server.py          # FastMCP server
├── docs/
│   └── DASHBOARD.md       # 🆕 Dashboard documentation
├── docker-compose.yml     # Memgraph + Qdrant
├── pyproject.toml         # Python dependencies
├── install.sh             # Interactive installer
├── CLAUDE.md              # Template for your projects
└── README.md              # This file
```

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: update README with dashboard information"
```

---

## Task 6: Add Entry Point Script

**Files:**
- Modify: `pyproject.toml`

**Step 1: Verify entry point is configured**

Ensure the `[project.scripts]` section exists:

```toml
[project.scripts]
egregore-dashboard = "src.dashboard:main"
```

**Step 2: Commit**

```bash
git add pyproject.toml
git commit -m "feat: add egregore-dashboard CLI entry point"
```

---

## Task 7: Create Dashboard Test

**Files:**
- Create: `tests/test_graph_client.py`

**Step 1: Create test directory and test file**

```bash
mkdir -p tests
touch tests/__init__.py
```

```python
"""Tests for graph client."""

import pytest
from unittest.mock import MagicMock, patch

from src.graph_client import GraphClient


class TestGraphClient:
    """Test suite for GraphClient."""

    @patch("src.graph_client.GraphDatabase")
    def test_init(self, mock_graphdb):
        """Test GraphClient initialization."""
        client = GraphClient()
        assert client._driver is None

    @patch("src.graph_client.GraphDatabase")
    def test_get_statistics(self, mock_graphdb):
        """Test statistics retrieval."""
        # Setup mock
        mock_session = MagicMock()
        mock_result = MagicMock()
        mock_result.single.return_value = {"count": 10}
        mock_session.run.return_value = mock_result

        mock_driver = MagicMock()
        mock_driver.session.return_value.__enter__ = MagicMock(return_value=mock_session)
        mock_driver.session.return_value.__exit__ = MagicMock(return_value=False)

        mock_graphdb.driver.return_value = mock_driver

        # Test
        client = GraphClient()
        stats = client.get_statistics()

        assert "memory_count" in stats
        assert "relation_count" in stats
        assert "density" in stats

    @patch("src.graph_client.GraphDatabase")
    def test_create_memory(self, mock_graphdb):
        """Test memory creation."""
        # Setup mock
        mock_session = MagicMock()
        mock_result = MagicMock()
        mock_result.single.return_value = {"id": "test-uuid"}
        mock_session.run.return_value = mock_result

        mock_driver = MagicMock()
        mock_driver.session.return_value.__enter__ = MagicMock(return_value=mock_session)
        mock_driver.session.return_value.__exit__ = MagicMock(return_value=False)

        mock_graphdb.driver.return_value = mock_driver

        # Test
        client = GraphClient()
        memory_id = client.create_memory("Test content", {"context": "test"})

        assert memory_id == "test-uuid"
```

**Step 2: Commit**

```bash
git add tests/
git commit -m "test: add graph client tests"
```

---

## Summary

This implementation adds a complete web dashboard to Egregore:

| Component | Purpose |
|-----------|---------|
| `src/graph_client.py` | Direct Memgraph client for CRUD operations |
| `src/dashboard.py` | Streamlit web application |
| `docs/DASHBOARD.md` | Dashboard documentation |
| `tests/test_graph_client.py` | Unit tests |

**Features:**
- Interactive graph visualization with streamlit-agraph
- Add/edit/delete memories via web UI
- Create relationships between memories
- Search and filter memories
- Real-time statistics

**Usage:**
```bash
egregore-dashboard
# or
streamlit run src/dashboard.py
```

**Execution Order:** Tasks 1-7 in sequence.
