# herdr-vibe-bridge (local workaround until herdr ships vibe support)

Herdr 0.9.5's recognized-agent list is a closed enum without vibe, so panes
running `vibe-rs` stay at `agent_status: "unknown"` and don't appear in
`herdr agent list` or the TUI sidebar. The server's `pane.report_agent` API
accepts any agent label and sets hook authority for a custom source, so this
bridge reports vibe panes as agent `"vibe"` (plus `display_agent` and ctx
tokens via `pane.report_metadata`), and clears panes that stop running vibe.

Upstream tracking: herdrdev/herdr discussion #5865 (PR #5863 was closed by
the contributor gate). Once a herdr release recognizes vibe natively, delete
this bridge.

## Install

```bash
install -m755 herdr-vibe-bridge ~/.local/bin/herdr-vibe-bridge
install -Dm644 herdr-vibe-bridge.service herdr-vibe-bridge.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now herdr-vibe-bridge.timer
```

The timer runs the bridge every 5s; each run re-reports with a fresh `seq`
(hook authority) and refreshes metadata under a 60s TTL, so display data
never goes stale while the timer lives.

## Uninstall

```bash
systemctl --user disable --now herdr-vibe-bridge.timer
rm ~/.config/systemd/user/herdr-vibe-bridge.service ~/.config/systemd/user/herdr-vibe-bridge.timer
rm ~/.local/bin/herdr-vibe-bridge
systemctl --user daemon-reload
```

## How it decides

For each pane: `herdr pane process-info` → foreground process name mapped via
`PROCESS_AGENT_LABELS` (`vibe`, `vibe-rs`, `mistral-vibe` → `vibe`). State is
`working` when the visible screen shows interrupt chrome (`esc to interrupt`),
else `idle`. Tokens come from the agent's own status line (`ctx 97.2k/800k`).

Extend `PROCESS_AGENT_LABELS` in the script to bridge other unrecognized
agents the same way.
