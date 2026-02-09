---
name: egregore
description: MCP-based hive mind memory system for storing and retrieving context across sessions. Implements the EGREGORE PROTOCOL for persistent shared memory. Use when starting any task, completing meaningful work, learning user preferences, or verifying memory system health.
---

# Egregore - Hive Mind Memory Protocol

## ⚠️ MANDATORY - Before Starting ANY Work

**ALWAYS call `recall_memory(query)` before ANY task.** This is not optional.

The first action for ANY task must be searching the hive mind for relevant context.

## MCP Tools

### health_check
Verify memory system health. Returns JSON with memory store status.

**Use when:**
- Memory operations fail
- Verifying system status
- Troubleshooting connectivity

### recall_memory(query, limit)
Search for relevant memories in hive mind. Retrieves context from previous sessions and shared knowledge.

**Parameters:**
- `query` (required): What to search for
- `limit` (optional): Maximum memories to return (default: 5)

**Use when:**
- Starting ANY new task (always required first)
- Searching for previous solutions
- Looking up user preferences
- Finding project context
- Retrieving architecture decisions

**Query examples:**
- User's name, preferences, or context
- Project-specific information
- Previous bugs fixed or patterns discovered
- Architecture decisions made

### store_memory(data, context, tags)
Store a memory in hive mind. Teaches the collective across sessions.

**Parameters:**
- `data` (required): Content to store
- `context` (optional): Category (e.g., "bugfix", "architecture", "learning", "preference")
- `tags` (optional): Comma-separated keywords

**Use when:**
- Fixing a bug → problem + solution (context="bugfix")
- Making an architecture decision (context="architecture")
- Discovering a reusable pattern (context="learning")
- Completing a feature (context="preference")
- Learning user preferences (context="preference")

## Required MCP Server Configuration

Ensure this MCP server is configured in your Claude Code settings:

```json
{
  "egregore": {
    "type": "sse",
    "url": "http://localhost:9000/sse"
  }
}
```

## Workflow

### 1. Before ANY Work
```python
recall_memory("relevant query about task, user, or project")
```

### 2. During Work
Use retrieved context to inform decisions and approach.

### 3. After Meaningful Work
```python
store_memory(
    data="description of what was learned or decided",
    context="bugfix|architecture|learning|preference",
    tags="relevant,keywords,here"
)
```

### 4. If Issues Occur
```python
health_check()  # Verify system status
```
