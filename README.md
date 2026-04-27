# Gombey AI

Private AI Chat for Your Business

## Quick Start

```bash
# 1. Clone
git clone https://github.com/BermyBoysTechSolutions/gombey-ai.git
cd gombey-ai

# 2. Configure
cp .env.example .env
# Edit .env with your OpenRouter key

# 3. Deploy
docker-compose up -d
```

## Admin User Management

Since `ALLOW_REGISTRATION=false`, new accounts must be created manually by the admin.

### Create a new user account

```bash
# Use the helper script
./scripts/create-user.sh username email@example.com password
```

### User Onboarding Flow

1. **Customer pays you** (Stripe, PayPal, etc.)
2. **You create their account** using the script above
3. **Send them credentials** — they log in at `chat.gombeytech.com`
4. **They start using Gombey AI**

### Team Accounts

For teams that want shared access:
- **Option A**: Create one shared account (everyone uses same login)
- **Option B**: Create individual accounts per team member (isolated chats)

For true team workspaces (shared chats between users), use Option A for now; full client workspaces can be added later if demand justifies it.

## Configuration

- `.env` - Environment variables
- `librechat.yaml` - Gombey AI model and UI configuration
- `docker-compose.yml` - Deployment orchestration

## Support

Built by [Gombey Tech LLC](https://gombeytech.com)
