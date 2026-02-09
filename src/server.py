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
