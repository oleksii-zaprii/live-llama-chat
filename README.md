# Live Llama Chat — OppLoans Internal Live Chat

OppLoans-internal live customer chat: AI-first conversations via local Ollama (`opploans-chat:latest`), with human handover to Loan Advocates in the LA portal.

## Prerequisites

- Ruby 4.0.5 (see `.ruby-version`)
- Bundler
- [Ollama](https://ollama.com/) running locally (`ollama serve`)
- Custom OppLoans model: `opploans-chat:latest`

## Ollama setup

The chat bot uses a custom model with OppLoans knowledge baked in:

```bash
# One-time: create the model from the Modelfile
ollama create opploans-chat -f Modelfile.opploans

# Optional: refresh knowledge base from opploans.com and rebuild Modelfile
ruby script/update_bot.rb
ollama create opploans-chat -f Modelfile.opploans
```

Environment variables (optional):

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama API base URL |
| `OLLAMA_MODEL` | `opploans-chat:latest` | Model name |
| `WIDGET_ALLOWED_ORIGIN` | `*` | CORS origin for widget API |

## Getting started

```bash
bin/setup          # install gems, prepare DB, seed
bin/dev            # web + tailwind + background jobs (Solid Queue)
```

Open:

- **LA Portal (agents):** http://localhost:3000 — login with `agent@opploans.com` / `password`
- **Dev chat simulator (customers):** http://localhost:3000/dev/chat_simulator (development only)

## Architecture

1. Customer starts chat via widget API or dev simulator → `Conversation` in `ai_managed` status
2. Messages go through Action Cable (`ConversationChannel`) → `ProcessAiResponseJob` calls Ollama
3. On handover (keyword, AI decision, or Ollama failure) → status `awaiting_agent`, LA dashboard queue updates live
4. Loan Advocate accepts → `agent_managed`, real-time chat via `LaConversationChannel`
5. Inactive chats closed by `SessionTimeoutJob` (every 5 minutes)

## Testing

```bash
bin/rails test
```

## Deployment

Production uses Solid Queue, Solid Cache, Solid Cable, and Kamal. See `config/deploy.yml`.
