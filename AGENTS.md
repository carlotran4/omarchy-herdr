# AGENTS.md

## Project overview

Herdr for Omarchy is a native Quickshell bar plugin. It renders Herdr's normalized coding-agent states, opens an Omarchy-styled dashboard, and focuses existing agent panes.

## Invariants

- Keep status updates event-driven through `events.subscribe`; never poll Herdr on a timer.
- Treat events as invalidation signals and refresh with `agent.list`.
- Clicking may focus an existing pane with `agent.focus`; it must never create a terminal, window, pane, tab, or agent.
- Priority is `blocked`, `done`, `working`, `unknown`, then `idle`; newest `state_change_seq` wins ties.
- Keep harness-specific state interpretation inside Herdr.
- Compositor behavior is optional and isolated in `scripts/focus-herdr-window`.
- The plugin must install directly from the repository root with `omarchy plugin add`.
- Do not add symlinks; Omarchy's plugin validator rejects them.
- Never modify `/usr/share/omarchy/`. Dogfood under `~/.config/omarchy/plugins/carlotran4.herdr/`.

## Repository map

- `manifest.json` — Omarchy plugin metadata, defaults, and settings schema.
- `BarWidget.qml` — bar pill, popup dashboard, interactions, and shell integration.
- `HerdrModel.qml` — native socket lifecycle, requests, events, and reconnect behavior.
- `Herdr.js` — deterministic model/formatting helpers.
- `scripts/focus-herdr-window` — optional Hyprland window raising.
- `tests/herdr.test.mjs` — JavaScript model tests.
- `docs/` — screenshots and rendered product video.

## Validation

```bash
omarchy plugin validate .
node --test tests/herdr.test.mjs
qmllint -I /usr/share/omarchy/shell BarWidget.qml HerdrModel.qml
bash -n scripts/focus-herdr-window
```

For live validation, copy the checkout without `.git`, `.github`, `docs`, or `tests` into `~/.config/omarchy/plugins/carlotran4.herdr/`, call `omarchy-shell shell rescanPlugins`, and inspect a fullscreen screenshot. Back up `~/.config/omarchy/shell.json` before changing layout or settings.
