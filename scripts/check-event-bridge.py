#!/usr/bin/env python3
"""Exercise the real hook executable using fictional input and a local test listener.

Quit Notch Pet first. Never removes an existing socket, settings, or captured data.
"""

from __future__ import annotations

import argparse
import fcntl
import json
import os
from pathlib import Path
import socket
import stat
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
BUILD = Path(os.environ.get("TMPDIR", "/private/tmp")) / "notch-pet-dev/build"
DIRECTORY = Path(f"/private/tmp/notch-pet-{os.getuid()}")
ENDPOINT = DIRECTORY / "events-v1.sock"
TIMINGS: list[float] = []


def invoke(helper: Path, raw: bytes, agent: str = "codex", *, pane: str | None = None) -> None:
    environment = {key: value for key, value in os.environ.items()
                   if key in {"PATH", "TMPDIR", "DEVELOPER_DIR", "LLVM_PROFILE_FILE"}}
    if pane is not None:
        environment["OTTY_PANE_ID"] = pane
    started = time.monotonic()
    result = subprocess.run([str(helper), "--agent", agent], input=raw,
                            capture_output=True, env=environment, timeout=1)
    elapsed = time.monotonic() - started
    TIMINGS.append(elapsed)
    assert result.returncode == 0, "helper must return zero"
    assert result.stdout == result.stderr == b"", "helper must remain silent"
    assert elapsed < 0.75, "helper exceeded process deadline allowance"


def receive_one(helper: Path, raw: bytes, agent: str, pane: str | None = None) -> dict:
    with socket.socket(socket.AF_UNIX) as listener:
        listener.bind(str(ENDPOINT))
        identity = ENDPOINT.lstat()
        os.chmod(ENDPOINT, 0o600)
        listener.listen(1)
        listener.settimeout(1)
        frames: list[bytes] = []
        errors: list[Exception] = []

        def collect() -> None:
            try:
                connection, _ = listener.accept()
                with connection:
                    connection.settimeout(1)
                    frame = b""
                    while True:
                        chunk = connection.recv(16385)
                        if not chunk:
                            break
                        frame += chunk
                        assert len(frame) <= 16384
                    frames.append(frame)
            except Exception as error:
                errors.append(error)

        thread = threading.Thread(target=collect)
        thread.start()
        try:
            invoke(helper, raw, agent, pane=pane)
            thread.join(timeout=2)
            assert not thread.is_alive() and not errors, "listener did not receive one frame"
            assert len(frames) == 1 and frames[0].endswith(b"\n")
            assert b"\n" not in frames[0][:-1]
            return json.loads(frames[0])
        finally:
            current = ENDPOINT.lstat()
            assert (current.st_dev, current.st_ino) == (identity.st_dev, identity.st_ino)
            ENDPOINT.unlink()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--helper", type=Path, help="check this packaged helper instead of the local build")
    arguments = parser.parse_args()
    if arguments.helper is None:
        # Build location matches run.sh. Building is a separate, explicit verification step.
        candidates = list(BUILD.glob("*/debug/NotchPetHook"))
        assert len(candidates) == 1, "build the helper with bash scripts/run.sh --build-only first"
        helper = candidates[0]
    else:
        helper = arguments.helper.expanduser().absolute()
        try:
            is_regular = stat.S_ISREG(helper.lstat().st_mode)
        except OSError:
            is_regular = False
        if not is_regular or not os.access(helper, os.X_OK):
            parser.error("helper must be an existing executable regular file")
    try:
        DIRECTORY.mkdir(mode=0o700)
    except FileExistsError:
        pass
    directory = os.open(DIRECTORY, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    lock = -1
    try:
        info = os.fstat(directory)
        assert info.st_uid == os.getuid() and stat.S_IMODE(info.st_mode) == 0o700
        lock = os.open("listener.lock", os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK,
                       0o600, dir_fd=directory)
        info = os.fstat(lock)
        assert stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid()
        assert stat.S_IMODE(info.st_mode) == 0o600 and info.st_nlink == 1
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        assert not os.path.lexists(ENDPOINT), "quit the app first; existing socket left untouched"

        minimal = b'{"session_id":"fictional","hook_event_name":"SessionStart"}'
        for agent in ("codex", "claude"):
            for _ in range(5):
                invoke(helper, minimal, agent)
        assert not os.path.lexists(ENDPOINT)
        print("PASS unavailable app: five silent zero-exit invocations per agent; no spool or socket created")

        examples = json.loads((ROOT / "docs/notes/agent-event-examples.json").read_text())["examples"]
        identities = set()
        for example in examples:
            payload, agent = example["payload"], example["agent"]
            frame = receive_one(helper, json.dumps(payload).encode(), agent, "fictional-unverified-pane")
            assert frame["version"] == 1 and frame["agent"] == agent
            assert frame["session_id"] == payload["session_id"]
            assert frame["hook_event_name"] == payload["hook_event_name"]
            assert frame.get("turn_id") == payload.get("prompt_id" if agent == "claude" else "turn_id")
            assert frame["terminal"] == {"kind": "otty", "pane_selector": "fictional-unverified-pane"}
            assert set(frame) <= {"version", "event_id", "agent", "session_id", "hook_event_name",
                                  "observed_at_ms", "turn_id", "tool_use_id", "tool_name", "cwd", "terminal"}
            assert frame["event_id"] not in identities
            identities.add(frame["event_id"])
            assert abs(time.time() * 1000 - frame["observed_at_ms"]) < 2000
        print(f"PASS {len(examples)} fictional hook projections through the actual helper")

        for agent in ("codex", "claude"):
            boundary = receive_one(helper, minimal + b" " * (262144 - len(minimal)), agent)
            assert boundary["session_id"] == "fictional" and boundary["agent"] == agent
        print("PASS raw stdin accepted at exactly 262144 bytes for both agents")

        with socket.socket(socket.AF_UNIX) as listener:
            listener.bind(str(ENDPOINT))
            os.chmod(ENDPOINT, 0o600)
            listener.listen(8)
            listener.settimeout(0.15)
            try:
                for agent in ("codex", "claude"):
                    for raw in [b"{}", b"[", b"\xff", b" " * 262145,
                                b'{"session_id":"a","session_id":"b","hook_event_name":"SessionStart"}']:
                        invoke(helper, raw, agent)
                    for hook in ("Interrupt", "StopFailure", "Notification", "Elicitation", "ElicitationResult"):
                        invoke(helper, json.dumps({"session_id": "a", "hook_event_name": hook}).encode(), agent)
                    invoke(helper, minimal, agent, pane="invalid\npane")
                invoke(helper, minimal, "unsupported")
                try:
                    listener.accept()
                    raise AssertionError("invalid input reached listener")
                except socket.timeout:
                    pass
            finally:
                ENDPOINT.unlink()
        print("PASS malformed, oversized, unsupported, and invalid-pane input dropped before connection")

        environment = {"PATH": os.environ.get("PATH", "/usr/bin:/bin"),
                       "LLVM_PROFILE_FILE": os.environ["LLVM_PROFILE_FILE"]}
        for agent in ("codex", "claude"):
            process = subprocess.Popen([str(helper), "--agent", agent], stdin=subprocess.PIPE,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=environment)
            started = time.monotonic()
            # Keep the input pipe open. The helper must time out instead of waiting for EOF.
            process.wait(timeout=0.75)
            elapsed = time.monotonic() - started
            process.stdin.close()
            assert process.returncode == 0 and process.stdout.read() == process.stderr.read() == b""
            assert elapsed < 0.75
            print(f"PASS {agent} open stdin dropped within {elapsed * 1000:.0f} ms including launch")

        with socket.socket(socket.AF_UNIX) as listener:
            listener.bind(str(ENDPOINT))
            os.chmod(ENDPOINT, 0o600)
            listener.listen(1)
            fillers = []
            try:
                for _ in range(64):
                    peer = socket.socket(socket.AF_UNIX)
                    peer.setblocking(False)
                    fillers.append(peer)
                    try:
                        peer.connect(str(ENDPOINT))
                    except OSError:
                        break
                else:
                    raise AssertionError("could not saturate the test socket")
                for agent in ("codex", "claude"):
                    invoke(helper, minimal, agent)
            finally:
                for peer in fillers:
                    peer.close()
                ENDPOINT.unlink()
        print("PASS busy socket drops silently without retry")
        print(f"PASS helper process times: {min(TIMINGS) * 1000:.0f}–{max(TIMINGS) * 1000:.0f} ms including launch")
        print("Bridge process checks passed")
    finally:
        if lock >= 0:
            os.close(lock)
        os.close(directory)
        # Keep listener.lock and its directory. Removing lock files permits split ownership.


if __name__ == "__main__":
    # A local helper may come from a coverage build. Never emit its profile into the checkout.
    with tempfile.TemporaryDirectory(prefix="notch-pet-bridge-check-") as profile_directory:
        os.environ["LLVM_PROFILE_FILE"] = str(Path(profile_directory) / "helper-%p.profraw")
        main()
