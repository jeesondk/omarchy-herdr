# jesper.herdr — Herdr bar widget for Omarchy

A bar widget and panel for [Herdr](https://herdr.dev/), the terminal workspace
manager for AI coding agents. It shows the live session — workspaces, tabs,
panes, the agent detected in each pane, and context usage — plus buttons to
open Herdr and create a new workspace.

<img width="625" height="497" alt="image" src="https://github.com/user-attachments/assets/bc62e853-7aeb-4c75-8c42-056bd59dcfe8" />


## Install

Requires [herdr](https://herdr.dev/) installed, and Omarchy's default terminal
set (`omarchy default terminal ...`) for the "Open Herdr" button.

```bash
omarchy plugin add https://github.com/jeesondk/omarchy-herdr.git --enable
```

Then restart the shell (`omarchy restart shell`) if the widget does not appear
in the bar. Move it with `omarchy bar move jesper.herdr --section right`.

## What it shows

- Bar icon: the Herdr logo (from herdr.dev), dimmed when the herdr server is down.
- Panel: per workspace, its tabs, and each pane with a status dot, the agent
  running in it, the pane title, and context tokens (`ctx 48.6k`).
- Buttons: **Open Herdr** (runs `omarchy launch terminal herdr`) and
  **New workspace** (`herdr workspace create --focus`).

## Remote machines over SSH

Herdr can manage remote servers (`herdr machine add <ssh-target>`). To show
saved machines in the panel as remote sections — their workspaces, tabs, panes
and agents, queried through `herdr --machine <label> ...` over SSH — list
their labels in the widget settings:

```bash
omarchy bar set jesper.herdr remotes "vps,ci"
```

Each remote section shows a status dot (unreachable remotes say so), an
**Attach** button (opens the remote TUI via `herdr --remote <target>` in the
default terminal), a **New workspace** button (`herdr --machine <label>
workspace create --focus`), and the remote's live workspace tree. Remote
polls have a longer timeout and never block the local section.

To add a remote from the panel, use the **Add remote** button: enter the SSH
target (`user@host`) and press Add. The panel runs `herdr machine add
<target> --label <host>` non-interactively (works when SSH key auth is set
up) and adds the label to the `remotes` setting automatically. If the add
needs interactive auth — or herdr needs to approve installing/updating the
remote herdr binary, which it only does from an interactive terminal — the
panel detects that, adds the label to `remotes` right away, and opens a
terminal running `herdr machine add` so you can enter the password / approve
the install. The remote's section appears immediately and turns green on the
next poll once the machine is saved. Other failures (DNS, host key) show the
error with an **Open in terminal** fallback.

## How it works

The widget polls `bin/omarchy-herdr-state` (shipped in this repo, run with the
system python3) every `refreshIntervalSec` seconds (default 3; change with
`omarchy bar set jesper.herdr refreshIntervalSec 5`). The exporter reads
`herdr api snapshot` / `herdr agent list` over herdr's socket API.

Herdr only recognizes a fixed set of agents, so a pane running an agent it
doesn't know (e.g. `vibe-rs`) stays at status "unknown" in herdr itself. For
those panes the exporter falls back to `herdr pane process-info` to identify
the foreground agent process and reads context usage from the agent's own
status line (`herdr pane read`).

## Notes

- Unofficial community plugin; not affiliated with Herdr. The logo asset is
  Herdr's brand mark from herdr.dev.
- The plugin runs unsandboxed inside omarchy-shell; review the code before
  installing (as `omarchy plugin add` itself warns).

## License

MIT (see LICENSE). The Herdr logo remains property of its respective owner.
