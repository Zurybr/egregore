"""FastMCP server for Egregore - Hive Mind Memory System (SSE Transport).

This module implements a singleton SSE server that multiple Claude Code instances
can connect to simultaneously, providing a centralized memory system.
"""

from __future__ import annotations

import atexit
import fcntl
import json
import logging
import os
import signal
import sys
from pathlib import Path
from typing import Any, NoReturn

from fastmcp import FastMCP

from src.config import get_settings
from src.memory import get_memory

# Constants
PID_FILE = Path("/tmp/egregore.pid")
LOCK_FILE = Path("/tmp/egregore.lock")
LOG_FILE = Path("/tmp/egregore.log")

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout),
    ],
)
logger = logging.getLogger("egregore")

# Initialize FastMCP server with SSE transport
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
        logger.error(f"Error recalling memory: {e}")
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

        logger.info(f"Stored memory with context '{context}' and tags '{tags}'")

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
        logger.error(f"Error storing memory: {e}")
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
        logger.error(f"Health check failed: {e}")
        return json.dumps({"status": "error", "message": str(e)})


class SingletonManager:
    """Manages singleton behavior using file locking and PID files."""

    def __init__(self) -> None:
        self.lock_fd: int | None = None
        self._original_pid: int = os.getpid()

    def acquire_lock(self) -> bool:
        """Acquire exclusive lock to ensure only one instance runs.

        Returns:
            True if lock acquired successfully, False otherwise
        """
        try:
            # Create lock file if it doesn't exist
            LOCK_FILE.parent.mkdir(parents=True, exist_ok=True)
            self.lock_fd = os.open(
                str(LOCK_FILE),
                os.O_CREAT | os.O_RDWR,
                0o666,
            )

            # Try to acquire exclusive lock (non-blocking)
            fcntl.flock(self.lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            logger.info("Acquired singleton lock")
            return True

        except (OSError, IOError) as e:
            logger.error(f"Failed to acquire lock: {e}")
            if self.lock_fd is not None:
                os.close(self.lock_fd)
                self.lock_fd = None
            return False

    def release_lock(self) -> None:
        """Release the exclusive lock."""
        if self.lock_fd is not None:
            try:
                fcntl.flock(self.lock_fd, fcntl.LOCK_UN)
                os.close(self.lock_fd)
                logger.info("Released singleton lock")
            except (OSError, IOError) as e:
                logger.error(f"Error releasing lock: {e}")
            finally:
                self.lock_fd = None

    def write_pid(self) -> None:
        """Write PID to file for process management."""
        PID_FILE.write_text(str(os.getpid()))
        logger.info(f"Wrote PID {os.getpid()} to {PID_FILE}")

    def cleanup(self) -> None:
        """Clean up PID file and release lock on exit."""
        # Only cleanup if we're the original process
        if os.getpid() != self._original_pid:
            return

        logger.info("Cleaning up singleton resources")

        # Remove PID file
        try:
            PID_FILE.unlink(missing_ok=True)
        except OSError as e:
            logger.error(f"Error removing PID file: {e}")

        # Release lock
        self.release_lock()


def signal_handler(signum: int, frame: Any) -> NoReturn:
    """Handle shutdown signals gracefully."""
    logger.info(f"Received signal {signum}, shutting down...")
    sys.exit(0)


def run_server() -> NoReturn:
    """Run the SSE server with singleton enforcement."""
    settings = get_settings()

    # Setup signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    # Initialize singleton manager
    singleton = SingletonManager()

    # Try to acquire singleton lock
    if not singleton.acquire_lock():
        logger.error("Another Egregore server is already running")
        print("Error: Another Egregore server is already running", file=sys.stderr)
        print(f"Check status with: egregore-server status", file=sys.stderr)
        sys.exit(1)

    # Write PID file
    singleton.write_pid()

    # Register cleanup on exit
    atexit.register(singleton.cleanup)

    # Get host and port from environment or settings
    host = os.environ.get("EGREGORE_HOST", settings.egregore_host)
    port = int(os.environ.get("EGREGORE_PORT", settings.egregore_port))

    logger.info(f"Starting Egregore SSE server on {host}:{port}")
    print(f"Egregore SSE server starting...")
    print(f"  URL: http://{host}:{port}/sse")
    print(f"  PID: {os.getpid()}")
    print(f"  Log: {LOG_FILE}")

    try:
        # Run the server with SSE transport
        mcp.run(transport="sse", host=host, port=port)
    except Exception as e:
        logger.exception("Server error")
        print(f"Server error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    run_server()
