#!/usr/bin/env python3
"""Egregore CLI - Hive Mind Memory interface."""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime
from typing import Any

from .client import EgregoreClient
from .ui import UI, MemoryFormatter


def get_client() -> EgregoreClient:
    """Get configured client."""
    return EgregoreClient()


def cmd_recall(args: argparse.Namespace) -> int:
    """Search memories."""
    ui = UI()
    client = get_client()

    ui.info(f"🔍 Searching: {args.query}")
    ui.spinner.start()

    try:
        results = client.recall(args.query, args.limit)
        ui.spinner.stop()

        if not results:
            ui.warning("No memories found")
            return 0

        ui.success(f"Found {len(results)} memories")
        print()

        for i, mem in enumerate(results, 1):
            MemoryFormatter.format_memory(mem, index=i)
            print()

        return 0

    except Exception as e:
        ui.spinner.stop()
        ui.error(f"Search failed: {e}")
        return 1


def cmd_store(args: argparse.Namespace) -> int:
    """Store a memory."""
    ui = UI()
    client = get_client()

    # Interactive mode if no data provided
    if not args.data:
        ui.info("📝 Interactive memory storage")
        args.data = ui.prompt("Memory content")
        if not args.data:
            ui.error("Content required")
            return 1

        args.context = ui.prompt("Context (bugfix/architecture/preference/learning)", args.context)
        args.tags = ui.prompt("Tags (comma-separated)", args.tags)

    ui.spinner.start()

    try:
        result = client.store(args.data, args.context, args.tags)
        ui.spinner.stop()

        ui.success("✓ Memory stored successfully")
        if "memory_ids" in result:
            ui.info(f"  ID: {result['memory_ids'][0] if result['memory_ids'] else 'N/A'}")

        return 0

    except Exception as e:
        ui.spinner.stop()
        ui.error(f"Store failed: {e}")
        return 1


def cmd_search(args: argparse.Namespace) -> int:
    """Advanced search with filters."""
    ui = UI()
    client = get_client()

    ui.info(f"🔍 Advanced search: {args.query}")

    filters = []
    if args.context:
        filters.append(f"context={args.context}")
    if args.tags:
        filters.append(f"tags={args.tags}")

    if filters:
        ui.info(f"  Filters: {', '.join(filters)}")

    ui.spinner.start()

    try:
        results = client.recall(args.query, args.limit or 10)
        ui.spinner.stop()

        # Filter results if needed
        if args.context or args.tags:
            filtered = []
            for mem in results:
                meta = mem.get("metadata", {})
                match = True

                if args.context:
                    match = match and meta.get("context") == args.context

                if args.tags:
                    mem_tags = meta.get("tags", [])
                    search_tags = [t.strip() for t in args.tags.split(",")]
                    match = match and any(t in mem_tags for t in search_tags)

                if match:
                    filtered.append(mem)

            results = filtered

        if not results:
            ui.warning("No memories match the criteria")
            return 0

        ui.success(f"Found {len(results)} memories")
        print()

        for i, mem in enumerate(results, 1):
            MemoryFormatter.format_memory(mem, index=i)
            print()

        return 0

    except Exception as e:
        ui.spinner.stop()
        ui.error(f"Search failed: {e}")
        return 1


def cmd_graph(args: argparse.Namespace) -> int:
    """Visualize memory graph."""
    ui = UI()
    client = get_client()

    ui.info(f"🕸️  Building graph around: {args.query}")
    ui.spinner.start()

    try:
        # Get central memory
        results = client.recall(args.query, limit=1)
        ui.spinner.stop()

        if not results:
            ui.warning("No central memory found")
            return 0

        center = results[0]
        MemoryFormatter.format_graph(center, depth=args.depth)

        return 0

    except Exception as e:
        ui.spinner.stop()
        ui.error(f"Graph failed: {e}")
        return 1


def cmd_status(args: argparse.Namespace) -> int:
    """Check system health."""
    ui = UI()
    client = get_client()

    ui.info("🏥 Checking Egregore health...")
    ui.spinner.start()

    try:
        status = client.health_check()
        ui.spinner.stop()

        if status.get("status") == "healthy":
            ui.success("✓ System healthy")
            components = status.get("components", {})
            for name, healthy in components.items():
                icon = "✓" if healthy else "✗"
                color = ui.green if healthy else ui.red
                print(f"  {color(icon)} {name}")
        else:
            ui.error("✗ System unhealthy")
            print(f"  {status.get('message', 'Unknown error')}")

        return 0

    except Exception as e:
        ui.spinner.stop()
        ui.error(f"Health check failed: {e}")
        ui.info("\nIs the server running?")
        ui.info("  egregore-server start")
        return 1


def cmd_recent(args: argparse.Namespace) -> int:
    """Show recent memories."""
    ui = UI()
    client = get_client()

    ui.info(f"📚 Recent {args.n} memories")
    ui.spinner.start()

    try:
        # Search for all, sort by timestamp
        results = client.recall("*", limit=args.n)
        ui.spinner.stop()

        if not results:
            ui.warning("No memories found")
            return 0

        # Sort by created_at if available
        results.sort(
            key=lambda x: x.get("metadata", {}).get("created_at", ""),
            reverse=True
        )

        for i, mem in enumerate(results[:args.n], 1):
            MemoryFormatter.format_memory(mem, index=i)
            print()

        return 0

    except Exception as e:
        ui.spinner.stop()
        ui.error(f"Failed: {e}")
        return 1


def cmd_stats(args: argparse.Namespace) -> int:
    """Show statistics."""
    ui = UI()
    client = get_client()

    ui.info("📊 Memory Statistics")
    ui.spinner.start()

    try:
        # Get sample of memories for stats
        results = client.recall("*", limit=100)
        ui.spinner.stop()

        if not results:
            ui.warning("No memories found")
            return 0

        # Calculate stats
        contexts: dict[str, int] = {}
        tags: dict[str, int] = {}

        for mem in results:
            meta = mem.get("metadata", {})

            ctx = meta.get("context", "uncategorized")
            contexts[ctx] = contexts.get(ctx, 0) + 1

            for tag in meta.get("tags", []):
                tags[tag] = tags.get(tag, 0) + 1

        ui.header("Overview")
        print(f"  Total memories: {len(results)}")

        ui.header("By Context")
        for ctx, count in sorted(contexts.items(), key=lambda x: -x[1]):
            bar = "█" * min(count, 20)
            print(f"  {ctx:15} {bar} {count}")

        if tags:
            ui.header("Top Tags")
            for tag, count in sorted(tags.items(), key=lambda x: -x[1])[:10]:
                print(f"  #{tag}: {count}")

        return 0

    except Exception as e:
        ui.spinner.stop()
        ui.error(f"Failed: {e}")
        return 1


def cmd_interactive(args: argparse.Namespace) -> int:
    """Start interactive mode."""
    ui = UI()

    ui.banner("🐝 Egregore Interactive Mode")
    ui.info("Type 'help' for commands, 'quit' to exit\n")

    while True:
        try:
            cmd = ui.prompt("egregore").strip()

            if not cmd:
                continue

            if cmd == "quit":
                break

            if cmd == "help":
                print("\nCommands:")
                print("  recall <query>     - Search memories")
                print("  store              - Store memory (interactive)")
                print("  recent             - Show recent memories")
                print("  stats              - Show statistics")
                print("  status             - Check server health")
                print("  quit               - Exit\n")
                continue

            # Parse command
            parts = cmd.split(maxsplit=1)
            action = parts[0]
            rest = parts[1] if len(parts) > 1 else ""

            if action == "recall":
                args.query = rest or "*"
                args.limit = 5
                cmd_recall(args)

            elif action == "store":
                args.data = rest
                args.context = ""
                args.tags = ""
                cmd_store(args)

            elif action == "recent":
                args.n = int(rest) if rest else 10
                cmd_recent(args)

            elif action == "stats":
                cmd_stats(args)

            elif action == "status":
                cmd_status(args)

            else:
                ui.error(f"Unknown command: {action}")

        except KeyboardInterrupt:
            print()
            break
        except EOFError:
            break

    ui.info("\nGoodbye! 👋")
    return 0


def cmd_forget(args: argparse.Namespace) -> int:
    """Remove a memory."""
    ui = UI()

    ui.warning(f"About to delete memory: {args.id}")
    confirm = ui.prompt("Confirm (yes/no)", "no")

    if confirm.lower() != "yes":
        ui.info("Cancelled")
        return 0

    # Note: Delete would need to be implemented in the server
    ui.error("Delete not yet implemented in server")
    return 1


def main(argv: list[str] | None = None) -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        prog="egregore",
        description="🐝 Egregore - Hive Mind Memory CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  egregore recall "authentication patterns"
  egregore store -d "Fixed CORS bug" -c bugfix -t "cors,fastapi"
  egregore search "deployment" -c architecture
  egregore graph "microservices" -d 3
  egregore interactive
        """
    )

    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # Recall
    recall_parser = subparsers.add_parser("recall", help="Search memories")
    recall_parser.add_argument("query", help="Search query")
    recall_parser.add_argument("-l", "--limit", type=int, default=5)

    # Store
    store_parser = subparsers.add_parser("store", help="Store memory")
    store_parser.add_argument("-d", "--data", help="Memory content")
    store_parser.add_argument("-c", "--context", default="", help="Context")
    store_parser.add_argument("-t", "--tags", default="", help="Tags")

    # Search
    search_parser = subparsers.add_parser("search", help="Advanced search")
    search_parser.add_argument("query", help="Search query")
    search_parser.add_argument("-c", "--context", help="Filter by context")
    search_parser.add_argument("-t", "--tags", help="Filter by tags")
    search_parser.add_argument("-l", "--limit", type=int)

    # Graph
    graph_parser = subparsers.add_parser("graph", help="Visualize graph")
    graph_parser.add_argument("query", nargs="?", default="*", help="Center query")
    graph_parser.add_argument("-d", "--depth", type=int, default=2)

    # Status
    subparsers.add_parser("status", help="Check health")

    # Recent
    recent_parser = subparsers.add_parser("recent", help="Recent memories")
    recent_parser.add_argument("-n", type=int, default=10)

    # Stats
    subparsers.add_parser("stats", help="Statistics")

    # Interactive
    subparsers.add_parser("interactive", help="Interactive mode")

    # Forget
    forget_parser = subparsers.add_parser("forget", help="Delete memory")
    forget_parser.add_argument("id", help="Memory ID")

    args = parser.parse_args(argv)

    if not args.command:
        parser.print_help()
        return 1

    commands = {
        "recall": cmd_recall,
        "store": cmd_store,
        "search": cmd_search,
        "graph": cmd_graph,
        "status": cmd_status,
        "recent": cmd_recent,
        "stats": cmd_stats,
        "interactive": cmd_interactive,
        "forget": cmd_forget,
    }

    return commands[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
