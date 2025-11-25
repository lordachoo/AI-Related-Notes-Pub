# DGX SPARK Agent Zero (A0) Notes

## Overview (Approach)

- Agent Zero is running via docker , with a persistent data directory
    - `~/a0-dev` - restart, start, stop, tailLogs utility BASH scripts as well as the docker-compose.yml
    - `~/a0` - Persistent data directory for the docker compose
- Ollama is running locally, hosting gpt-oss:120b for Chat/Web Browse models, and qwen2.5:7b for Utility model
    - Ollama is running locally (bare metal) attached to the docker container via [Instructions for Ollama <-> Docker](./native-ollama-connect-to-docker-container/README.md)

## Compose

```yaml
$ cat docker-compose.yml

services:
  agent-zero:
    image: agent0ai/agent-zero
    ports:
      - "8881:80"
    volumes:
      - /home/anelson/a0:/a0
    environment:
      - ALLOWED_ORIGINS=*://localhost:*,*://127.0.0.1:*,*://0.0.0.0:*,*://192.168.1.161:*,*://${WAN_IP_ADDRESS}}$:*
    restart: unless-stopped
```

### Utility Scripts

```bash
anelson@dgx-spark0:~/a0-dev$ cat restart start stop
#!/bin/bash
docker compose restart

#!/bin/bash
docker compose up -d

#!/bin/bash
docker compose down
```

## models.py patch for memory related `reasoning_delta` error on Utility Model

- Had issues where memory did not work. In addition to changing to `qwen2.5:7b` as the utility model, I also applied the below patch so that the model can handle cases where `reasoning_delta` might be missing. 

### Error

```
Traceback (most recent call last):
Traceback (most recent call last):
  File "/a0/python/extensions/message_loop_prompts_after/_50_recall_memories.py", line 146, in search_memories
    filter = await self.agent.call_utility_model(
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/a0/agent.py", line 719, in call_utility_model
    response, _reasoning = await call_data["model"].unified_call(
                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/a0/models.py", line 545, in unified_call
    output = result.add_chunk(parsed)
             ^^^^^^^^^^^^^^^^^^^^^^^^
  File "/a0/models.py", line 118, in add_chunk
    self.reasoning += processed_chunk["reasoning_delta"]
TypeError: can only concatenate str (not "NoneType") to str


TypeError: can only concatenate str (not "NoneType") to str
```

### Fix

```
anelson@dgx-spark0:~/a0-dev$ diff ~/a0/models.py.orig ~/a0/models.py
118c118
<         self.reasoning += processed_chunk["reasoning_delta"]
---
>         self.reasoning += (processed_chunk.get("reasoning_delta") or "")
```

- After this, I was able to tell it my name, it saved it to memory. In another chat prompt, it was able to tell me my name from memory. This was failing before. Also the Chat tabs started properly saving (Because Utilty model started working between prompts).