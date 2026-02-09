"""Mem0 client wrapper for Egregore."""

from typing import Any

from mem0 import Memory

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
            self._client = Memory.from_config(config_dict=config)
        return self._client

    def _build_config(self) -> dict[str, Any]:
        """Build Mem0 configuration dictionary."""
        config: dict[str, Any] = {
            "vector_store": {
                "provider": "qdrant",
                "config": {
                    "collection_name": self.settings.instance_name,
                    "host": self.settings.qdrant_host,
                    "port": self.settings.qdrant_port,
                    "embedding_model_dims": 1536,  # OpenAI default
                },
            },
            "graph_store": {
                "provider": "memgraph",
                "config": {
                    "url": self.settings.memgraph_uri,
                },
            },
            "llm": {
                "provider": self.settings.embedding_provider.value,
                "config": {
                    "api_key": self.settings.embedding_api_key.get_secret_value(),
                    "model": "gpt-4o-mini" if self.settings.embedding_provider.value == "openai" else "gemini-pro",
                },
            },
            "embedder": {
                "provider": self.settings.embedding_provider.value,
                "config": {
                    "api_key": self.settings.embedding_api_key.get_secret_value(),
                    "model": "text-embedding-3-small" if self.settings.embedding_provider.value == "openai" else "models/embedding-001",
                },
            },
        }
        return config

    def recall(self, query: str, limit: int = 5) -> list[dict[str, Any]]:
        """Search for memories matching the query.

        Args:
            query: Search query string
            limit: Maximum number of results to return

        Returns:
            List of matching memory entries
        """
        results = self.client.search(
            query=query,
            limit=limit,
        )
        return results

    def store(
        self,
        data: str,
        metadata: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Store a new memory.

        Args:
            data: The memory content to store
            metadata: Optional metadata to attach

        Returns:
            Storage result with memory IDs
        """
        result = self.client.add(
            data,
            metadata=metadata or {},
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
            self.client.search("health_check", limit=1)
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
