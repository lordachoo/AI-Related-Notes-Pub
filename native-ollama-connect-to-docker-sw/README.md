# Connecting Docker Compose Containers to Native Ollama

## Problem
Docker containers need to connect to Ollama running natively on the host system.

## Solution: Use Docker Bridge Network IP

Docker's default bridge network makes the host accessible at `172.17.0.1` from inside containers.

---

## Step 1: Configure Ollama to Listen on All Interfaces

By default, Ollama only listens on `127.0.0.1` (localhost). Configure it to accept connections from Docker:

```bash
sudo systemctl edit ollama
```

Add:
```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

Restart Ollama:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

Verify:
```bash
ss -tlnp | grep 11434
# Should show: 0.0.0.0:11434
```

---

## Step 2: Find Docker Bridge IP

```bash
ip addr show docker0 | grep "inet " | awk '{print $2}' | cut -d/ -f1
```

Output (typically):
```
172.17.0.1
```

---

## Step 3: Create docker-compose.yml

Example using standard bridge networking:

```yaml
services:
  your-app:
    image: your-image
    ports:
      - "8080:80"
    volumes:
      - ./data:/data
    environment:
      - OLLAMA_URL=http://172.17.0.1:11434
    restart: unless-stopped
```

**Key points:**
- Use `ports:` for port mapping
- Set Ollama URL to `http://172.17.0.1:11434`
- Do NOT use `network_mode: host`

---

## Step 4: Configure Your Application

Inside your containerized application, connect to Ollama using:

```
http://172.17.0.1:11434
```

Or with the `/v1` suffix for OpenAI-compatible endpoints:

```
http://172.17.0.1:11434/v1
```

---

## Step 5: Start Container

```bash
docker compose up -d
```

---

## Verification

Test from host:
```bash
curl http://172.17.0.1:11434/api/tags
```

Test from container:
```bash
docker exec -it <container-name> curl http://172.17.0.1:11434/api/tags
```

Both should return your Ollama models list.

---

## Why This Works

| Component | Network Location | Access Point |
|-----------|-----------------|--------------|
| Ollama | Host (native) | `0.0.0.0:11434` |
| Docker Bridge | Virtual interface | `172.17.0.1` |
| Container | Inside Docker | Connects via `172.17.0.1:11434` |

The Docker bridge (`docker0`) acts as a gateway, allowing containers to reach host services at `172.17.0.1` while maintaining network isolation and port mapping for external access.
