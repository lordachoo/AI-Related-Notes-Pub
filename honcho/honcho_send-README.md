# honcho_send

A small Bash wrapper for pushing the contents of a file into [Honcho](https://honcho.dev) as one or more messages — chunking large files automatically and pulling the API key straight from your Hermes config so you never paste it by hand.

It exists to **manually seed Honcho** with content that didn't get captured automatically — e.g. a project spec or a session summary from a long-running Hermes session that was created before live per-turn persistence was enabled. For normal day-to-day capture, let Hermes write messages itself (`writeFrequency: "turn"` in `~/.hermes/honcho.json`, applied on the next session start). Use this when you need to backfill or inject a specific document.

## Requirements

- `python3` (uses the standard library only — no `pip install`, no `jq`)
- A Hermes Honcho config at `~/.hermes/honcho.json` containing an `apiKey` field
- Network access to `https://api.honcho.dev`

## Install

The function lives in `~/.honcho_send.sh`. Source it, and add it to your shell rc so it's always available:

```bash
source ~/.honcho_send.sh
echo 'source ~/.honcho_send.sh' >> ~/.bashrc
```

It's reloadable: edit the file in vim, then `source ~/.honcho_send.sh` again to pick up changes in the current shell.

## Usage

```
honcho_send <filepath> [peer_id] [session]
```

| Argument   | Required | Default          | Description                                           |
|------------|----------|------------------|-------------------------------------------------------|
| `filepath` | yes      | —                | Path to the file whose contents become the message(s) |
| `peer_id`  | no       | `dgx-spark`      | Which Honcho peer the message is attributed to        |
| `session`  | no       | `anelson`        | Honcho session the message lands in                   |

The workspace (`dgx-spark`), the default peer/session, and the chunk size are set near the top of the function body — edit them there and re-source if your setup changes.

### Examples

```bash
# Push a project spec, attributed to you (the user peer) — default
honcho_send ~/project.md

# Push a session recap, attributed to the agent's own peer
honcho_send ~/session_update.md dgx-spark-hermes

# Push into a specific session
honcho_send ~/notes.md dgx-spark my-other-session
```

## Peers — who said it?

Honcho models content as a **peer** making a statement, and derives that peer's representation from it. Pick the attribution deliberately:

- **`dgx-spark` (you / user peer)** — use for "here's my project / here's where things stand." Feeds *your* representation, which is what future sessions recall against. This is the right default for project continuity.
- **`dgx-spark-hermes` (AI peer)** — use when the content is the agent's own account of what it did. Feeds the agent's self-model.

## Chunking

Honcho rejects messages whose content exceeds its per-message cap (~25k characters — a too-large file returns a `string too long` error). `honcho_send` handles this for you:

- Files under the limit (`24000` chars, conservatively below the cap) are sent as a single message.
- Larger files are split on paragraph boundaries (`\n\n`). A single paragraph that's itself over the limit is hard-split.
- When a file produces multiple parts, each is prefixed with a `[filename part i/n]` tag and all parts are sent together as one batch.

If you still hit a size error, lower `LIMIT` in the function (e.g. to `8000`) and re-source.

## Output & verifying it worked

The command prints a progress line to **stderr** and the result to **stdout**:

```
→ 45000 chars -> 2 message(s)  peer=dgx-spark  session=anelson  file=/home/anelson/project.md
OK: stored 2 message(s)
[
  "2JnQn5SW5j2x-LPtQDEvp",
  "8kRm2pX9a1Lz-QWdFv0tn"
]
```

The returned **ids are the source of truth** — Honcho only hands back an id for a message it actually stored.

**Don't rely on the dashboard's "Messages Created" counter to confirm** — it's windowed and lags/caches, so a successful write may not show up there immediately. To see stored messages directly, go to **Explore → your session → Search Messages**.

## Troubleshooting

| Symptom on terminal                         | Meaning & fix                                                                 |
|---------------------------------------------|-------------------------------------------------------------------------------|
| `usage: ...` / `file not found`             | Path didn't resolve. Use a full path; check `~` expansion.                     |
| `can't read apiKey from ~/.hermes/honcho.json` | Config missing or has no `apiKey` field. Check the file.                     |
| `HTTP 4xx: ... string too long`             | A chunk still exceeded the cap. Lower `LIMIT` and re-source.                   |
| `HTTP 401 / 403`                            | Key invalid or not authorized for the workspace.                              |
| `OK: stored N` but dashboard flat           | It worked — the counter is just lagging. Verify in Explore → Search Messages.  |

## Two-message pattern

For seeding a session's context, pushing **two** messages tends to give Honcho cleaner signal than one merged blob, because they're distinct kinds of content:

```bash
honcho_send ~/project.md          # durable: what I'm building (spec/state)
honcho_send ~/session_update.md   # this run: decisions made, where I left off

