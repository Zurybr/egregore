# 🐝 Egregore Skill - Hive Mind Memory CLI

Advanced CLI for Egregore memory system with cool features like colored output, graph visualization, and interactive mode.

## Installation

```bash
cd skill-egregore
uv pip install -e "."
```

Or install as Claude skill (if supported by your Claude CLI version).

## Usage

### Basic Commands

```bash
# Search memories
egregore recall "authentication patterns"

# Store memory
egregore store -d "Fixed CORS bug in production" -c bugfix -t "cors,fastapi"

# Advanced search with filters
egregore search "microservices" -c architecture -t "scaling"

# Show statistics
egregore stats

# Recent memories
egregore recent -n 5

# Check server health
egregore status
```

### Interactive Mode

```bash
egregore interactive
```

Commands in interactive mode:
- `recall <query>` - Search
- `store` - Store memory (prompts for details)
- `recent [n]` - Show recent
- `stats` - Statistics
- `status` - Health check
- `help` - Show help
- `quit` - Exit

### Graph Visualization

```bash
# Visualize memory graph around a query
egregore graph "microservices" --depth 3
```

## Features

- 🎨 **Colored Output** - Beautiful terminal formatting with relevance bars
- 📊 **Statistics** - Context breakdowns and tag clouds
- 🔍 **Fuzzy Search** - Find memories by content, context, or tags
- 🕸️ **Graph View** - Visualize memory relationships
- 💬 **Interactive Mode** - Explore memories conversationally
- ⚡ **Fast** - Direct SSE connection to Egregore server

## Configuration

Set environment variable for custom server URL:

```bash
export EGREGORE_URL="http://localhost:9000"
```

## Requirements

- Python 3.13+
- Egregore server running (see main project)
- `requests` and `sseclient-py` libraries
