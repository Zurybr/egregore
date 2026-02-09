"""Egregore SSE Client - Connect to the Hive Mind."""

from __future__ import annotations

import json
import os
from typing import Any
from urllib.parse import urljoin

import requests
import sseclient


class EgregoreClient:
    """Client for Egregore SSE server."""

    def __init__(self, base_url: str | None = None) -> None:
        """Initialize client.

        Args:
            base_url: Server URL. Defaults to EGREGORE_URL env var or localhost:9000.
        """
        self.base_url = base_url or os.environ.get(
            "EGREGORE_URL", "http://localhost:9000"
        )
        self.session = requests.Session()
        self.session.headers.update({
            "Accept": "text/event-stream",
            "Cache-Control": "no-cache",
        })

    def _endpoint(self, path: str) -> str:
        """Build full URL."""
        return urljoin(self.base_url, path)

    def health_check(self) -> dict[str, Any]:
        """Check server health."""
        try:
            # SSE health check via tool call
            response = self._call_tool("health_check", {})
            return json.loads(response) if isinstance(response, str) else response
        except Exception as e:
            return {"status": "error", "message": str(e)}

    def recall(
        self, query: str, limit: int = 5, user_id: str = "egregore"
    ) -> list[dict[str, Any]]:
        """Search memories by semantic similarity."""
        response = self._call_tool(
            "recall_memory",
            {"query": query, "limit": limit, "user_id": user_id}
        )
        if isinstance(response, str):
            data = json.loads(response)
            return data.get("memories", {}).get("results", [])
        return []

    def store(
        self,
        data: str,
        context: str = "",
        tags: str = "",
        user_id: str = "egregore"
    ) -> dict[str, Any]:
        """Store a new memory."""
        response = self._call_tool(
            "store_memory",
            {
                "data": data,
                "context": context,
                "tags": tags,
                "user_id": user_id
            }
        )
        if isinstance(response, str):
            return json.loads(response)
        return response

    def _call_tool(self, tool_name: str, params: dict[str, Any]) -> Any:
        """Call an MCP tool via SSE."""
        # Connect to SSE endpoint
        url = self._endpoint("/sse")
        response = self.session.get(url, stream=True)
        response.raise_for_status()

        client = sseclient.SSEClient(response)

        try:
            # Wait for endpoint event
            endpoint = None
            for event in client.events():
                if event.event == "endpoint":
                    endpoint = event.data
                    break

            if not endpoint:
                raise ConnectionError("No endpoint received from SSE server")

            # Send tool call via POST
            message = {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/call",
                "params": {
                    "name": tool_name,
                    "arguments": params
                }
            }

            post_url = self._endpoint(endpoint)
            post_response = self.session.post(
                post_url,
                json=message,
                headers={"Content-Type": "application/json"}
            )
            post_response.raise_for_status()

            # Wait for response via SSE
            for event in client.events():
                if event.event == "message":
                    data = json.loads(event.data)
                    if "result" in data:
                        return data["result"]
                    elif "error" in data:
                        raise RuntimeError(data["error"])

        finally:
            response.close()

        return {}
