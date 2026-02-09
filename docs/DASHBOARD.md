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
