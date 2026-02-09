"""UI utilities for Egregore CLI."""

from __future__ import annotations

import sys
from typing import Any


class Colors:
    """ANSI color codes."""

    BLACK = "\033[30m"
    RED = "\033[31m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    BLUE = "\033[34m"
    MAGENTA = "\033[35m"
    CYAN = "\033[36m"
    WHITE = "\033[37m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    RESET = "\033[0m"


class Spinner:
    """Simple spinner for loading states."""

    def __init__(self) -> None:
        self.active = False
        self.chars = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
        self.idx = 0

    def start(self) -> None:
        """Start spinner."""
        self.active = True
        self._draw()

    def stop(self) -> None:
        """Stop spinner."""
        self.active = False
        sys.stdout.write("\r  \r")
        sys.stdout.flush()

    def _draw(self) -> None:
        """Draw spinner frame."""
        if not self.active:
            return
        char = self.chars[self.idx % len(self.chars)]
        sys.stdout.write(f"\r{Colors.CYAN}{char}{Colors.RESET} ")
        sys.stdout.flush()
        self.idx += 1


class UI:
    """User interface helpers."""

    def __init__(self) -> None:
        self.spinner = Spinner()
        self.colors = Colors

    def _color(self, text: str, color: str) -> str:
        """Colorize text."""
        return f"{color}{text}{Colors.RESET}"

    def red(self, text: str) -> str:
        return self._color(text, Colors.RED)

    def green(self, text: str) -> str:
        return self._color(text, Colors.GREEN)

    def yellow(self, text: str) -> str:
        return self._color(text, Colors.YELLOW)

    def blue(self, text: str) -> str:
        return self._color(text, Colors.BLUE)

    def cyan(self, text: str) -> str:
        return self._color(text, Colors.CYAN)

    def magenta(self, text: str) -> str:
        return self._color(text, Colors.MAGENTA)

    def bold(self, text: str) -> str:
        return self._color(text, Colors.BOLD)

    def info(self, text: str) -> None:
        """Print info message."""
        print(f"{Colors.BLUE}ℹ{Colors.RESET} {text}")

    def success(self, text: str) -> None:
        """Print success message."""
        print(f"{Colors.GREEN}✓{Colors.RESET} {text}")

    def warning(self, text: str) -> None:
        """Print warning message."""
        print(f"{Colors.YELLOW}⚠{Colors.RESET} {text}")

    def error(self, text: str) -> None:
        """Print error message."""
        print(f"{Colors.RED}✗{Colors.RESET} {text}", file=sys.stderr)

    def header(self, text: str) -> None:
        """Print header."""
        print(f"\n{Colors.BOLD}{text}{Colors.RESET}")
        print("─" * len(text))

    def banner(self, text: str) -> None:
        """Print banner."""
        width = len(text) + 4
        print()
        print(f"{Colors.CYAN}{'─' * width}{Colors.RESET}")
        print(f"{Colors.CYAN}│{Colors.RESET} {Colors.BOLD}{text}{Colors.RESET} {Colors.CYAN}│{Colors.RESET}")
        print(f"{Colors.CYAN}{'─' * width}{Colors.RESET}")
        print()

    def prompt(self, text: str, default: str = "") -> str:
        """Prompt for input."""
        if default:
            prompt_text = f"{Colors.CYAN}?{Colors.RESET} {text} [{default}]: "
        else:
            prompt_text = f"{Colors.CYAN}?{Colors.RESET} {text}: "

        try:
            response = input(prompt_text).strip()
            return response if response else default
        except (EOFError, KeyboardInterrupt):
            print()
            return default


class MemoryFormatter:
    """Format memory entries for display."""

    @staticmethod
    def format_memory(mem: dict[str, Any], index: int | None = None) -> None:
        """Format a single memory."""
        ui = UI()

        mem_id = mem.get("id", "unknown")[:8]
        data = mem.get("memory", mem.get("data", "No content"))
        meta = mem.get("metadata", {})
        context = meta.get("context", "uncategorized")
        tags = meta.get("tags", [])
        score = mem.get("score", 0)

        # Header with index and ID
        if index:
            prefix = f"{ui.bold(str(index))}."
        else:
            prefix = "•"

        print(f"{prefix} {ui.cyan(mem_id)} {ui.dim(context)}")

        # Content (truncated if too long)
        lines = data.split("\n")
        display = lines[0][:200]
        if len(lines) > 1 or len(data) > 200:
            display += "..."
        print(f"   {display}")

        # Tags
        if tags:
            tag_str = " ".join(f"#{ui.yellow(t)}" for t in tags)
            print(f"   {tag_str}")

        # Score if present
        if score:
            score_bar = "█" * int(score * 10)
            print(f"   {ui.dim('relevance:')} {score_bar} {score:.2f}")

    @staticmethod
    def format_graph(center: dict[str, Any], depth: int = 2) -> None:
        """Format memory as graph center."""
        ui = UI()

        ui.header("Memory Graph")
        print()

        # Center node
        mem_id = center.get("id", "unknown")[:8]
        data = center.get("memory", center.get("data", "No content"))

        print(f"  {ui.bold('◉ Center')}")
        print(f"  {ui.cyan(mem_id)}")
        print(f"  {data[:100]}...")
        print()

        # Related nodes (placeholder - would need graph API)
        print(f"  {ui.dim('Related memories (depth=' + str(depth) + '):')}")
        print(f"  {ui.dim('  Use dashboard for full graph visualization')}")
        print()

    @staticmethod
    def dim(text: str) -> str:
        """Dim text."""
        return f"{Colors.DIM}{text}{Colors.RESET}"
