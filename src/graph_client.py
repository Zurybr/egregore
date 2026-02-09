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
        """Get all memory nodes from the graph."""
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
        """Get all relationships between memories."""
        query = """
        MATCH (m1:Memory)-[r]->(m2:Memory)
        RETURN m1.id as source, m2.id as target, type(r) as type, r as properties
        LIMIT 1000
        """
        with self.driver.session() as session:
            result = session.run(query)
            return [dict(record) for record in result]

    def create_memory(self, data: str, metadata: dict | None = None) -> str:
        """Create a new memory node."""
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
        """Create a relationship between two memories."""
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
        """Delete a memory node and its relationships."""
        query = """
        MATCH (m:Memory {id: $id})
        DETACH DELETE m
        RETURN count(m) as deleted
        """

        with self.driver.session() as session:
            result = session.run(query, id=memory_id)
            return result.single()["deleted"] > 0

    def search_memories(self, query_text: str) -> list[dict[str, Any]]:
        """Search memories by content."""
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
        """Get graph statistics."""
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

        # Calculate density
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
