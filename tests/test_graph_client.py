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
