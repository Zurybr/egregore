# Local Client Setup for Egregore Remote Server

This guide explains how to connect your **local machine** to an Egregore server running on a **remote server**.

## Architecture

```
┌─────────────────┐         ┌─────────────────┐
│  Local Machine   │         │  Remote Server   │
│  (Your Laptop)   │         │  (VPS/Cloud)     │
└────────┬────────┘         └────────┬────────┘
         │                          │
         │ SSE (HTTP)              │
         └──────────────────────────┘
                   │
         ┌────────▼─────────┐
         │  Egregore Server │
         │  Port: 9000       │
         └────────┬─────────┘
                  │
        ┌─────────┴─────────┐
        │    Kuzu + Qdrant  │
        └───────────────────┘
```

## Quick Setup

### 1. MCP Configuration (~/.claude.json)

Edit `~/.claude.json` on your local machine:

```json
{
  "mcpServers": {
    "egregore": {
      "type": "sse",
      "url": "http://<YOUR_SERVER_IP>:9000/sse"
    }
  }
}
```

Replace `<YOUR_SERVER_IP>` with your server's actual IP address.

### 2. Memory Protocol (~/.claude/memory/MEMORY.md)

Create the memory protocol file:

```bash
mkdir -p ~/.claude/memory
cat > ~/.claude/memory/MEMORY.md << 'EOF'
# EGREGORE PROTOCOL (Hive Mind Memory)

## ⚠️ MANDATORY - Before Starting ANY Work
**ALWAYS use `recall_memory(query)` before ANY task.** This is not optional.

Query examples:
- User's name, preferences, or context
- Project-specific information
- Previous bugs fixed or patterns discovered
- Architecture decisions made

## Store Memories When:
- Fixing a bug → problem + solution (context="bugfix")
- Making an architecture decision (context="architecture")
- Discovering a reusable pattern (context="learning")
- Completing a feature (context="preference")
- Learning user preferences (context="preference")

**Required parameters:** `data`, `context`, and `tags` (comma-separated)

### Available Tools
- `health_check` - Check memory system status
- `recall_memory(query, limit)` - Search the hive mind
- `store_memory(data, context, tags)` - Teach the collective

→ Full documentation: https://github.com/Zurybr/egregore
EOF
```

### 3. CLAUDE.md Protocol (Optional)

Add to your project `CLAUDE.md`:

```markdown
# EGREGORE PROTOCOL (Hive Mind Memory)

## ⚠️ MANDATORY - Before Starting ANY Work
**ALWAYS use `recall_memory(query)` before ANY task.**

[rest of protocol...]
```

### 4. CLI Tool (Optional)

For a cooler CLI interface with colors and interactive mode:

```bash
# On your local machine
cd ~/path/to/egregore/skill-egregore
uv pip install -e .
export EGREGORE_URL="http://<YOUR_SERVER_IP>:9000"
egregore interactive
```

## Test Connection

From your local machine, test:

```bash
curl http://<YOUR_SERVER_IP>:9000/sse
```

Should return: `text/event-stream` response headers.

## Server-Side Setup

On your remote server, run:

```bash
cd /path/to/egregore
./init.sh --server-only
```

The `--server-only` flag:
- Starts the SSE server
- Starts Docker services (Qdrant)
- Shows client setup instructions
- **Does NOT** configure local MCP/MEMORY.md

## Firewall Configuration

Make sure port **9000** is open on your server:

```bash
# UFW (Ubuntu)
sudo ufw allow 9000/tcp

# firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-port=9000/tcp
sudo firewall-cmd --reload

# AWS Security Group
# Allow inbound TCP on port 9000 from your IP
```

## Troubleshooting

### Connection Refused

```bash
# Check if server is running
curl http://<YOUR_SERVER_IP>:9000/sse

# Check server logs (on the server)
egregore-server logs -f
```

### MCP Not Connecting

1. Verify URL in `~/.claude.json` is correct
2. Restart Claude Code after configuration
3. Check server logs: `egregore-server logs -f`

### Memory.md Not Loading

1. Verify file exists: `ls -la ~/.claude/memory/MEMORY.md`
2. Check file permissions: `chmod 644 ~/.claude/memory/MEMORY.md`
3. Restart Claude Code

## Next Steps

Once connected:

1. Test with: `recall_memory("test")`
2. Store first memory: `store_memory("Test memory", "testing", "setup")`
3. Explore: `egregore stats` (if using CLI tool)
