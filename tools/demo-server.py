#!/usr/bin/env python3
"""Small Herdr-protocol fixture used to film the product demo."""

from __future__ import annotations

import argparse
import json
import os
import signal
import socket
import threading
import time
from pathlib import Path

SCENES = [
    ["working", "working", "idle", "done"],
    ["working", "blocked", "idle", "done"],
    ["working", "working", "done", "done"],
]
NAMES = ["api-auth-refresh", "checkout-redesign", "release-notes", "flake-hunter"]
CWDS = ["~/Developer/herdr/api", "~/Developer/storefront", "~/Developer/herdr", "~/Developer/herdr/tests"]


class DemoServer:
    def __init__(self, path: Path, interval: float) -> None:
        self.path = path
        self.interval = interval
        self.scene = 0
        self.sequence = 10
        self.running = True
        self.subscribers: list[socket.socket] = []
        self.lock = threading.Lock()

    def agents(self) -> list[dict[str, object]]:
        return [
            {
                "name": name,
                "display_agent": "pi",
                "agent_status": SCENES[self.scene][index],
                "state_change_seq": self.sequence - index,
                "workspace_id": "demo",
                "tab_id": f"demo:t{index + 1}",
                "pane_id": f"demo:p{index + 1}",
                "cwd": cwd.replace("~", str(Path.home()), 1),
                "foreground_cwd": cwd.replace("~", str(Path.home()), 1),
            }
            for index, (name, cwd) in enumerate(zip(NAMES, CWDS, strict=True))
        ]

    @staticmethod
    def send(conn: socket.socket, payload: dict[str, object]) -> None:
        conn.sendall((json.dumps(payload, separators=(",", ":")) + "\n").encode())

    def handle(self, conn: socket.socket) -> None:
        reader = conn.makefile("r", encoding="utf-8")
        keep = False
        try:
            line = reader.readline()
            if not line:
                return
            request = json.loads(line)
            request_id = request.get("id", "")
            method = request.get("method")
            if method == "agent.list":
                self.send(conn, {"id": request_id, "result": {"type": "agent_list", "agents": self.agents()}})
            elif method == "agent.focus":
                self.send(conn, {"id": request_id, "result": {"type": "agent_focused"}})
            elif method == "events.subscribe":
                self.send(conn, {"id": request_id, "result": {"type": "subscription_started"}})
                with self.lock:
                    self.subscribers.append(conn)
                keep = True
                while self.running:
                    time.sleep(1)
            else:
                self.send(conn, {"id": request_id, "error": {"code": "unknown_method", "message": str(method)}})
        except (BrokenPipeError, ConnectionError, json.JSONDecodeError, OSError):
            pass
        finally:
            if keep:
                with self.lock:
                    if conn in self.subscribers:
                        self.subscribers.remove(conn)
            reader.close()
            conn.close()

    def cycle(self) -> None:
        while self.running:
            time.sleep(self.interval)
            self.scene = (self.scene + 1) % len(SCENES)
            self.sequence += 10
            event = {"event": "pane_agent_status_changed", "data": {"type": "pane_agent_status_changed", "pane_id": "demo:p2"}}
            with self.lock:
                clients = list(self.subscribers)
            for conn in clients:
                try:
                    self.send(conn, event)
                except OSError:
                    pass

    def run(self) -> None:
        self.path.unlink(missing_ok=True)
        listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        listener.bind(str(self.path))
        listener.listen()
        os.chmod(self.path, 0o600)
        threading.Thread(target=self.cycle, daemon=True).start()
        print(self.path, flush=True)
        try:
            while self.running:
                conn, _ = listener.accept()
                threading.Thread(target=self.handle, args=(conn,), daemon=True).start()
        finally:
            self.running = False
            listener.close()
            self.path.unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--socket", type=Path, default=Path("/tmp/herdr-demo.sock"))
    parser.add_argument("--interval", type=float, default=3.0)
    args = parser.parse_args()
    server = DemoServer(args.socket, args.interval)
    signal.signal(signal.SIGTERM, lambda *_: setattr(server, "running", False))
    server.run()


if __name__ == "__main__":
    main()
