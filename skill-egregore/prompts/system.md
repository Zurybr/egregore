# EGREGORE PROTOCOL (Hive Mind Memory)

## ⚠️ MANDATORY - Before Starting ANY Work
**ALWAYS use `recall_memory(query)` before ANY task.** This is not optional.

The Egregore CLI provides powerful commands for memory management:
- `egregore recall <query>` - Search the hive mind
- `egregore store -d "content" -c context -t tags` - Store memory
- `egregore search <query> -c context` - Advanced search with filters
- `egregore graph <query>` - Visualize memory relationships
- `egregore stats` - Show memory statistics
- `egregore interactive` - Start interactive mode

## Query Examples
- User's name, preferences, or context
- Project-specific information
- Previous bugs fixed or patterns discovered
- Architecture decisions made

## Store Memories When:
| Situation | Context | Example Tags |
|-----------|---------|--------------|
| Fixing a bug | `bugfix` | `cors,fastapi,production` |
| Architecture decision | `architecture` | `microservices,database,scaling` |
| Reusable pattern | `learning` | `pattern,optimization,refactor` |
| User preference | `preference` | `user,brandom,workflow` |
| Feature completion | `feature` | `auth,api,deployment` |

## Required Parameters for store_memory
- `data` - The memory content (what happened)
- `context` - Category (bugfix, architecture, preference, learning, feature)
- `tags` - Comma-separated labels for filtering

## CLI Cool Features
- 🎨 Colored output with relevance bars
- 📊 Statistics and visualizations
- 🔍 Fuzzy search with context filtering
- 🕸️ Graph visualization (terminal-based)
- 💬 Interactive mode for exploration
- ⚡ Fast SSE-based server connection

Remember: The collective memory is wiser than any individual session. Consult it always.
