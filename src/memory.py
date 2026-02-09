"""Mem0 client wrapper for Egregore."""

from typing import Any

from mem0 import Memory
from mem0.configs.base import (
    MemoryConfig,
    VectorStoreConfig,
    GraphStoreConfig,
    LlmConfig,
    EmbedderConfig,
)

from src.config import Settings, get_settings


class EgregoreMemory:
    """Wrapper around Mem0 client for Egregore operations."""

    def __init__(self, settings: Settings | None = None) -> None:
        """Initialize the memory client.

        Args:
            settings: Configuration settings. Uses cached settings if not provided.
        """
        self.settings = settings or get_settings()
        self._client: Memory | None = None

    @property
    def client(self) -> Memory:
        """Lazy initialization of Mem0 client."""
        if self._client is None:
            config = self._build_config()
            self._client = Memory(config=config)
        return self._client

    def _build_config(self) -> MemoryConfig:
        """Build Mem0 configuration."""
        provider = self.settings.embedding_provider.value

        # Use kuzu for graph store as it doesn't require authentication
        # TODO: Switch to memgraph once authentication is configured
        return MemoryConfig(
            vector_store=VectorStoreConfig(
                provider="qdrant",
                config={
                    "collection_name": self.settings.instance_name,
                    "host": self.settings.qdrant_host,
                    "port": self.settings.qdrant_port,
                    "embedding_model_dims": 1536,  # OpenAI default
                },
            ),
            graph_store=GraphStoreConfig(
                provider="kuzu",
                config={
                    "db_path": "/tmp/egregore_kuzu.db",
                },
            ),
            llm=LlmConfig(
                provider=provider,
                config={
                    "api_key": self.settings.embedding_api_key.get_secret_value(),
                    "model": "gpt-4o-mini" if provider == "openai" else "gemini-pro",
                },
            ),
            embedder=EmbedderConfig(
                provider=provider,
                config={
                    "api_key": self.settings.embedding_api_key.get_secret_value(),
                    "model": "text-embedding-3-small" if provider == "openai" else "models/embedding-001",
                },
            ),
        )

    def recall(self, query: str, limit: int = 5, user_id: str = "egregore") -> list[dict[str, Any]]:
        """Search for memories matching the query.

        Args:
            query: Search query string
            limit: Maximum number of results to return
            user_id: User ID for memory isolation (default: "egregore")

        Returns:
            List of matching memory entries
        """
        results = self.client.search(
            query=query,
            limit=limit,
            user_id=user_id,
        )
        return results

    def store(
        self,
        data: str,
        metadata: dict[str, Any] | None = None,
        user_id: str = "egregore",
    ) -> dict[str, Any]:
        """Store a new memory.

        Args:
            data: The memory content to store
            metadata: Optional metadata to attach
            user_id: User ID for memory isolation (default: "egregore")

        Returns:
            Storage result with memory IDs
        """
        result = self.client.add(
            data,
            metadata=metadata or {},
            user_id=user_id,
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
            self.client.search("health_check", limit=1, user_id="health_check")
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
