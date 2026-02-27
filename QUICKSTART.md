# EverMemOS Quick Start Guide

A complete guide to install, configure, and use EverMemOS with Claude Code.

## Table of Contents

1. [Overview](#overview)
2. [System Requirements](#system-requirements)
3. [Quick Start (One-Command Installation)](#quick-start-one-command-installation)
4. [Manual Installation](#manual-installation)
5. [Claude Code Plugin Installation](#claude-code-plugin-installation)
6. [Configuration](#configuration)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)
9. [Resource Monitoring](#resource-monitoring)

---

## Overview

EverMemOS is a persistent memory system for Claude Code that automatically saves and recalls context from past conversations.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Claude Code                              │
│                      (MCP Host)                              │
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────┐  │
│  │     EverMemOS-MCP-Bridge (Plugin)                     │  │
│  └───────────────────────────────────────────────────────┘  │
│                      │ HTTP REST API                        │
└──────────────────────┼──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│                    EverMemOS Service                         │
│              (Docker Compose - Port 1995)                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │  FastAPI │  │ MongoDB  │  │   Milvus │  │    ES    │     │
│  │   Layer  │  │ (文档)   │  │ (向量)   │  │ (全文)   │     │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘     │
└─────────────────────────────────────────────────────────────┘
```

---

## System Requirements

### Minimum Requirements

| Component | Requirement |
|-----------|-------------|
| **OS** | macOS 12+ or Linux (Ubuntu 20.04+) |
| **Memory** | 8 GB RAM (4 GB minimum) |
| **Disk** | 20 GB free space |
| **Docker** | Docker 20.10+ with Docker Compose |
| **Python** | Python 3.10+ |

### Required Software

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (macOS/Linux)
- [Python 3.10+](https://www.python.org/downloads/)
- [uv](https://github.com/astral-sh/uv) (Python package manager)

---

## Quick Start (One-Command Installation)

### Step 1: Clone and Enter Directory

```bash
cd /path/to/EverMemOS
```

### Step 2: Run Installation Script

```bash
./install.sh
```

The script will:
1. Check system requirements
2. Install missing dependencies
3. Configure environment variables
4. Start Docker containers
5. Install Python dependencies
6. Start EverMemOS service
7. Verify installation

### Step 3: Verify Installation

```bash
# Check health
curl http://localhost:1995/health

# Expected output:
# {"status":"healthy","timestamp":"...","message":"System running normally"}
```

---

## Manual Installation

If the automatic script doesn't work, follow these steps:

### Step 1: Install Dependencies

**macOS (with Homebrew):**
```bash
# Install Homebrew if not installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Docker Desktop
brew install --cask docker

# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Linux (Ubuntu/Debian):**
```bash
# Install Docker
sudo apt-get update
sudo apt-get install -y docker.io docker-compose

# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Step 2: Configure Environment

```bash
# Copy template configuration
cp env.template .env

# Edit .env with your settings
nano .env
```

**Minimum required configuration:**
```bash
# Vectorize (Embedding) API - Get from https://bailian.console.aliyun.com/
VECTORIZE_API_KEY=your-aliyun-api-key

# LLM API (for memory boundary detection)
LLM_API_KEY=your-llm-api-key
```

### Step 3: Start Infrastructure

```bash
# Start Docker containers
docker compose up -d

# Wait for containers to be healthy (may take 1-2 minutes)
sleep 60
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### Step 4: Install Python Dependencies

```bash
# Install dependencies
uv sync
```

### Step 5: Start EverMemOS Service

```bash
# Start service
uv run python src/run.py

# Or run in background
nohup uv run python src/run.py > /tmp/evermemos.log 2>&1 &
```

### Step 6: Verify

```bash
# Check health endpoint
curl http://localhost:1995/health
```

---

## Claude Code Plugin Installation

### Prerequisites

- Claude Code installed: `npm install -g @anthropic-ai/claude-code`
- EverMemOS running on `localhost:1995`

### Installation Steps

**Step 1: Navigate to Plugin Directory**

```bash
cd /path/to/evermem-claude-code
```

**Step 2: Configure Plugin (Local Mode)**

The plugin is already configured for local mode. No API key needed!

**Step 3: Install to Claude Code**

```bash
# Install plugin
claude --plugin-dir .
```

**Step 4: Verify Installation**

In Claude Code, type:
```
/evermem:help
```

You should see the EverMem help message.

### Manual Configuration (if needed)

If the plugin doesn't connect automatically, set environment variables:

```bash
# Add to your shell profile (~/.zshrc or ~/.bashrc)
export EVERMEM_API_URL="http://localhost:1995"

# Reload shell
source ~/.zshrc  # or source ~/.bashrc
```

---

## Configuration

### Getting API Keys

#### 1. Aliyun Bailian (Recommended for Chinese Users)

**Website:** https://bailian.console.aliyun.com/

**Free Tier:** 1 million tokens (valid for 90 days)

**Pricing:** ¥0.5 per million tokens

**Steps:**
1. Register/login with Alibaba Cloud account
2. Navigate to "Model Studio" (百炼)
3. Create an API Key
4. Copy the key (starts with `sk-`)

#### 2. OpenAI (Alternative)

**Website:** https://platform.openai.com/

**Steps:**
1. Create an account
2. Go to API Keys section
3. Create new secret key

#### 3. DeepInfra (Free Tier Available)

**Website:** https://deepinfra.com/

**Free Tier:** 10,000 requests/month

### Configuration File (.env)

```bash
# =============================================================================
# Vectorize (Embedding) Configuration
# =============================================================================

# Option 1: Aliyun Bailian (Recommended)
VECTORIZE_PROVIDER=vllm
VECTORIZE_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
VECTORIZE_API_KEY=sk-your-aliyun-key
VECTORIZE_MODEL=text-embedding-v4
VECTORIZE_DIMENSIONS=1024

# Option 2: OpenAI
# VECTORIZE_PROVIDER=openai
# VECTORIZE_BASE_URL=https://api.openai.com/v1
# VECTORIZE_API_KEY=sk-your-openai-key
# VECTORIZE_MODEL=text-embedding-3-small
# VECTORIZE_DIMENSIONS=1536

# =============================================================================
# LLM Configuration (for memory boundary detection)
# =============================================================================

LLM_PROVIDER=openai
LLM_MODEL=gpt-4o-mini
LLM_API_KEY=your-llm-api-key
```

---

## Testing

### Test 1: API Health Check

```bash
curl http://localhost:1995/health
```

### Test 2: Store a Memory

```bash
curl -X POST http://localhost:1995/api/v1/memories \
  -H "Content-Type: application/json" \
  -d '{
    "message_id": "test-001",
    "create_time": "'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'",
    "sender": "user",
    "sender_name": "Test User",
    "role": "user",
    "content": "How do I implement JWT authentication in Python?",
    "group_id": "test-session",
    "group_name": "Test Session"
  }'
```

### Test 3: Search Memories

```bash
# Keyword search
curl -X GET http://localhost:1995/api/v1/memories/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "JWT authentication",
    "user_id": "user",
    "retrieve_method": "keyword",
    "top_k": 5
  }'

# Hybrid search (requires embedding API)
curl -X GET http://localhost:1995/api/v1/memories/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Python auth",
    "user_id": "user",
    "retrieve_method": "hybrid",
    "top_k": 5
  }'
```

### Test 4: Claude Code Integration

1. Start a conversation in Claude Code
2. Ask about something you discussed before:
   ```
   Remember when we talked about JWT authentication?
   ```
3. Claude should recall the previous context automatically

4. Use Memory Hub:
   ```
   /evermem:hub
   ```

---

## Troubleshooting

### Issue 1: Port Already in Use

**Symptom:** `bind: address already in use`

**Solution:**
```bash
# Find and kill process using port 1995
lsof -ti:1995 | xargs kill -9

# Or stop existing Docker containers
docker-compose stop
```

### Issue 2: Docker Container Unhealthy

**Symptom:** Container shows `unhealthy` status

**Solution:**
```bash
# Check logs
docker logs memsys-milvus-standalone
docker logs memsys-milvus-etcd

# Restart containers
docker-compose restart
```

### Issue 3: Embedding API Error

**Symptom:** Vector search returns empty results

**Solution:**
```bash
# Check API key is set
grep VECTORIZE_API_KEY .env

# Test API directly
curl -X POST https://dashscope.aliyuncs.com/compatible-mode/v1/embeddings \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"model": "text-embedding-v4", "input": "test"}'
```

### Issue 4: Memory Not Being Retrieved

**Symptom:** Claude doesn't recall previous conversations

**Solution:**
```bash
# Check if memories are being stored
curl http://localhost:1995/api/v1/memories?user_id=user&limit=10

# Check Claude Code plugin is installed
claude plugin list

# Check plugin configuration
echo $EVERMEM_API_URL
```

### Issue 5: Permission Denied

**Symptom:** Cannot execute install.sh

**Solution:**
```bash
chmod +x install.sh
./install.sh
```

---

## Resource Monitoring

### Check Docker Container Resources

```bash
# Real-time stats
docker stats

# One-time snapshot
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

### Check EverMemOS Service

```bash
# Process info
ps aux | grep "python src/run.py"

# Log file
tail -f /tmp/evermemos.log
```

### Stop All Services

```bash
# Using install script
./install.sh --stop

# Or manually
pkill -f "python src/run.py"
docker-compose stop
```

---

## Command Reference

### Install Script Commands

```bash
./install.sh              # Full installation
./install.sh --stop       # Stop all services
./install.sh --restart    # Restart services
./install.sh --status     # Check status
./install.sh --help       # Show help
```

### Docker Commands

```bash
docker-compose up -d      # Start containers
docker-compose stop       # Stop containers
docker-compose restart    # Restart containers
docker-compose logs -f    # Follow logs
docker ps                 # List running containers
```

### Python Service Commands

```bash
# Start service
uv run python src/run.py

# Run in background
nohup uv run python src/run.py > /tmp/evermemos.log 2>&1 &

# Stop service
pkill -f "python src/run.py"
```

---

## Next Steps

1. **Explore Memory Hub**: Run `/evermem:hub` in Claude Code
2. **Customize Configuration**: Edit `.env` file for your needs
3. **Read Documentation**: See `README.md` for advanced features
4. **Join Community**: Submit issues and feature requests on GitHub

---

## Support

- **GitHub Issues**: https://github.com/evermemos/evermemos/issues
- **Documentation**: See `README.md` and `CLAUDE.md`

---

**Happy Coding with EverMemOS! 🚀**
