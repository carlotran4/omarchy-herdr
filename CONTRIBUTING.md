# Contributing

Contributions are welcome. Keep changes focused, preserve the invariants in [`AGENTS.md`](AGENTS.md), and validate before opening a pull request:

```bash
omarchy plugin validate .
node --test tests/herdr.test.mjs
qmllint -I /usr/share/omarchy/shell BarWidget.qml HerdrModel.qml
bash -n scripts/focus-herdr-window
```

Behavior changes should include the narrowest useful test and update the README when they affect installation, settings, interactions, or requirements. Test visual changes in a user-owned plugin directory; never edit Omarchy's packaged files under `/usr/share/omarchy/`.
