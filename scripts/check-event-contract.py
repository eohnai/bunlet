#!/usr/bin/env python3
"""Check the v1 contract's fictional cases. This is not production app code."""

from __future__ import annotations

import copy
import hashlib
import json
import re
import sys
import unicodedata
import uuid
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
POLICY = {
    "raw_hook_bytes": 262144,
    "frame_bytes": 16384,
    "delivery_age_ms": 30000,
    "future_skew_ms": 2000,
    "freshness_ms": 120000,
    "sessions": 128,
    "event_ids": 4096,
    "turn_ids": 256,
    "requests": 64,
}
HOOKS = {
    "SessionStart", "UserPromptSubmit", "PreToolUse", "PermissionRequest",
    "PostToolUse", "Stop", "SessionEnd",
}
TOOL_HOOKS = {"PreToolUse", "PermissionRequest", "PostToolUse"}
REQUIRED = {"version", "event_id", "agent", "session_id", "hook_event_name", "observed_at_ms"}
OPTIONAL = {"turn_id", "tool_use_id", "tool_name", "cwd", "terminal", "prompt_preview", "reply_preview"}


class InvalidMessage(ValueError):
    pass


def reject(reason: str) -> None:
    raise InvalidMessage(reason)


def unique_object(pairs: list) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            reject("duplicate_key")
        result[key] = value
    return result


def valid_string(value: object, limit: int) -> bool:
    if not isinstance(value, str):
        return False
    try:
        return (0 < len(value.encode("utf-8")) <= limit
                and not any(unicodedata.category(c) in {"Cc", "Cs"} for c in value))
    except UnicodeEncodeError:
        return False


def decode_frame(frame: bytes) -> dict:
    if len(frame) > POLICY["frame_bytes"]:
        reject("frame_too_large")
    if not frame.endswith(b"\n") or b"\n" in frame[:-1]:
        reject("framing")
    try:
        text = frame[:-1].decode("utf-8", errors="strict")
    except UnicodeDecodeError:
        reject("utf8")
    try:
        message = json.loads(text, object_pairs_hook=unique_object,
                             parse_constant=lambda _: reject("nonfinite"))
    except (json.JSONDecodeError, RecursionError):
        reject("json")
    if type(message) is not dict:
        reject("object_required")
    if not REQUIRED <= message.keys():
        reject("missing_field")
    if message.keys() - REQUIRED - OPTIONAL:
        reject("unknown_field")
    if type(message["version"]) is not int or message["version"] != 1:
        reject("version")
    event_id = message["event_id"]
    try:
        canonical = str(uuid.UUID(event_id)) if isinstance(event_id, str) else None
    except (ValueError, AttributeError):
        canonical = None
    if canonical is None or canonical != event_id:
        reject("event_id")
    if message["agent"] not in ("codex", "claude"):
        reject("agent")
    if not valid_string(message["session_id"], 256):
        reject("session_id")
    hook = message["hook_event_name"]
    if not isinstance(hook, str) or hook not in HOOKS:
        reject("hook")
    observed = message["observed_at_ms"]
    if type(observed) is not int or not 0 <= observed <= 9007199254740991:
        reject("timestamp")
    for name, limit in (("turn_id", 256), ("tool_use_id", 256), ("tool_name", 128), ("cwd", 4096)):
        if name in message and not valid_string(message[name], limit):
            reject(name)
    for name, limit in (("prompt_preview", 1024), ("reply_preview", 1024)):
        if name in message and not valid_string(message[name], limit):
            reject(name)
    # Decision 0019: display previews only on the hook that carries them.
    if "prompt_preview" in message and hook != "UserPromptSubmit":
        reject("prompt_preview")
    if "reply_preview" in message and hook != "Stop":
        reject("reply_preview")
    if "cwd" in message and not message["cwd"].startswith("/"):
        reject("cwd")
    if hook in TOOL_HOOKS:
        if "tool_name" not in message:
            reject("tool_name")
    elif "tool_name" in message or "tool_use_id" in message:
        reject("tool_fields")
    if "terminal" in message:
        terminal = message["terminal"]
        if (type(terminal) is not dict or terminal.keys() != {"kind", "pane_selector"}
                or terminal["kind"] != "otty"
                or not valid_string(terminal["pane_selector"], 256)):
            reject("terminal")
    return message


def encode(message: dict) -> bytes:
    return (json.dumps(message, ensure_ascii=True, sort_keys=True, separators=(",", ":")) + "\n").encode()


@dataclass
class Session:
    status: str = "unknown"
    reason: str | None = "no_baseline"
    turn: str | None = None
    baseline: bool = False
    stopped: bool = False
    terminal: bool = False
    saturated: bool = False
    watermark: int | None = None
    deadline: int | None = None
    seen: dict = field(default_factory=dict)
    turns: set = field(default_factory=set)
    retired: set = field(default_factory=set)
    pending: dict = field(default_factory=dict)

    def unknown(self, reason: str) -> None:
        self.status, self.reason = "unknown", reason

    def refresh(self, message: dict, wall: int, monotonic: int) -> None:
        self.watermark = message["observed_at_ms"]
        age = max(0, wall - message["observed_at_ms"])
        self.deadline = monotonic + POLICY["freshness_ms"] - age

    def show_pending(self) -> None:
        self.reason = None
        kinds = {request["kind"] for request in self.pending.values()}
        self.status = ("question_needed" if "question_needed" in kinds else
                       "approval_needed" if kinds else "working")


class ReferenceStore:
    """A small executable interpretation for review, not the shared-store API."""

    def __init__(self) -> None:
        self.sessions: dict[tuple[str, str], Session] = {}

    def advance(self, monotonic: int) -> None:
        for session in self.sessions.values():
            if (not session.terminal and session.status != "unknown"
                    and session.deadline is not None and monotonic >= session.deadline):
                session.unknown("expired")

    def invalidate_clocks(self) -> None:
        for session in self.sessions.values():
            if not session.terminal:
                session.unknown("clock_or_wake")

    def receive(self, message: dict, wall: int, monotonic: int) -> str:
        return self.receive_frame(encode(message), wall, monotonic)

    def receive_frame(self, frame: bytes, wall: int, monotonic: int) -> str:
        message = decode_frame(frame)
        self.advance(monotonic)
        age = wall - message["observed_at_ms"]
        if age > POLICY["delivery_age_ms"] or age < -POLICY["future_skew_ms"]:
            return "delivery_time"
        key = (message["agent"], message["session_id"])
        if key not in self.sessions:
            if len(self.sessions) >= POLICY["sessions"]:
                return "session_capacity"
            self.sessions[key] = Session()
        session = self.sessions[key]
        event_id = message["event_id"]
        digest = hashlib.sha256(encode(message)).digest()
        if event_id in session.seen:
            if session.seen[event_id] != digest:
                session.unknown("event_id_conflict")
                return "event_id_conflict"
            return "duplicate"
        turn = message.get("turn_id")
        if (session.saturated or len(session.seen) >= POLICY["event_ids"]
                or (turn is not None and turn not in session.turns
                    and len(session.turns) >= POLICY["turn_ids"])):
            session.saturated = True
            session.unknown("identity_capacity")
            return "identity_capacity"
        session.seen[event_id] = digest
        if turn is not None:
            session.turns.add(turn)
        hook = message["hook_event_name"]
        if hook == "SessionEnd":
            session.terminal = True
            session.status, session.reason = "ended", None
            session.pending.clear()
            session.deadline = None
            return "ended"
        if session.terminal:
            if hook == "SessionStart":
                session.unknown("reused_session_id")
            return "terminal_restriction"
        if session.watermark is not None and message["observed_at_ms"] <= session.watermark:
            session.unknown("ambiguous_capture_order")
            return "ambiguous_capture_order"
        if turn is not None and turn in session.retired:
            return "retired_turn"
        if hook == "SessionStart":
            if len(session.seen) == 1:
                session.status, session.reason = "idle", None
                session.refresh(message, wall, monotonic)
                return "applied"
            return "repeated_start"
        if hook == "UserPromptSubmit":
            if session.baseline and turn == session.turn:
                return "repeated_submit"
            if session.baseline and turn is None:
                session.unknown("missing_turn_identity")
                return "conflict"
            if session.pending or (session.baseline and session.status == "working"):
                session.unknown("overlapping_turns")
                return "conflict"
            if session.turn is not None:
                session.retired.add(session.turn)
            session.turn, session.baseline, session.stopped = turn, True, False
            session.status, session.reason = "working", None
            session.refresh(message, wall, monotonic)
            return "applied"
        correlated = session.baseline and turn is not None and turn == session.turn
        if hook == "Stop":
            if not correlated:
                session.unknown("uncorrelated_stop")
                return "conflict"
            session.pending = {key: request for key, request in session.pending.items()
                               if request["turn"] != turn}
            session.stopped = True
            if session.status == "unknown":
                return "resolved_but_unknown"
            if session.status == "response_ready":
                return "repeated_stop"
            session.status, session.reason = "response_ready", None
            session.refresh(message, wall, monotonic)
            return "applied"
        if session.stopped:
            session.unknown("activity_after_stop")
            return "conflict"
        tool_id, tool_name = message.get("tool_use_id"), message["tool_name"]
        question_tool = {"codex": "request_user_input", "claude": "AskUserQuestion"}[message["agent"]]
        opens = hook == "PermissionRequest" or (hook == "PreToolUse" and tool_name == question_tool)
        request_key = (turn, tool_id) if turn is not None and tool_id is not None else event_id
        if opens:
            kind = "question_needed" if tool_name == question_tool else "approval_needed"
            request = {"turn": turn, "tool": tool_id, "name": tool_name, "kind": kind}
            if request_key in session.pending:
                if session.pending[request_key] != request:
                    session.unknown("request_conflict")
                    return "conflict"
                return "merged_request"
            if len(session.pending) >= POLICY["requests"]:
                session.unknown("request_capacity")
                return "request_capacity"
            session.pending[request_key] = request
            if not correlated:
                session.unknown("uncorrelated_activity")
                return "conflict"
            if session.status == "unknown":
                return "retained_but_unknown"
            session.show_pending()
            session.refresh(message, wall, monotonic)
            return "applied"
        if hook == "PostToolUse":
            request = session.pending.get(request_key)
            if correlated and request is not None and request["name"] == tool_name:
                del session.pending[request_key]
                if session.status == "unknown":
                    return "resolved_but_unknown"
                session.show_pending()
                session.refresh(message, wall, monotonic)
                return "applied"
            if session.pending:
                session.unknown("uncorrelated_resolution")
                return "conflict"
            return "unmatched_completion"
        if not correlated:
            session.unknown("uncorrelated_activity")
            return "conflict"
        if session.status == "unknown" or session.pending:
            return "no_change"
        session.status, session.reason = "working", None
        session.refresh(message, wall, monotonic)
        return "applied"

    def snapshot(self) -> list:
        return [{"agent": agent, "session_id": identity, "status": session.status,
                 "pending": len(session.pending), "reason": session.reason}
                for (agent, identity), session in sorted(self.sessions.items())]


def check_messages(cases: list) -> None:
    for case in cases:
        if "message" in case:
            frame = encode(case["message"])
        elif "raw" in case:
            frame = case["raw"].encode("utf-8")
        else:
            frame = bytes.fromhex(case["hex"])
        if "pad_to_bytes" in case:
            frame = frame[:-1] + b" " * (case["pad_to_bytes"] - len(frame)) + frame[-1:]
        try:
            decode_frame(frame)
            actual = "valid"
        except InvalidMessage as error:
            actual = str(error)
        assert actual == case["expect"], f'{case["name"]}: expected {case["expect"]}, got {actual}'
        if actual != "valid":
            store = ReferenceStore()
            deliver(store, example_event(1))
            before = copy.deepcopy(store.sessions)
            try:
                store.receive_frame(frame, 1000001, 1000001)
                raise AssertionError(f'{case["name"]}: invalid frame was applied')
            except InvalidMessage:
                assert store.sessions == before, f'{case["name"]}: invalid frame changed state'


def check_sequences(cases: list) -> int:
    steps = 0
    for case in cases:
        store = ReferenceStore()
        for index, step in enumerate(case["steps"], 1):
            context = f'{case["name"]}, step {index}'
            if "message" in step:
                outcome = store.receive(step["message"], step["wall_ms"], step["monotonic_ms"])
                assert outcome == step["outcome"], f'{context}: expected {step["outcome"]}, got {outcome}'
            elif step["operation"] == "advance":
                store.advance(step["monotonic_ms"])
            else:
                assert step["operation"] in {"wake", "clock_change"}, context
                store.invalidate_clocks()
            actual = store.snapshot()
            assert actual == step["expect"], f'{context}: expected {step["expect"]}, got {actual}'
            steps += 1
    return steps


def example_event(number: int, hook: str = "UserPromptSubmit", **fields) -> dict:
    event = {"version": 1, "event_id": str(uuid.UUID(int=number)), "agent": "codex",
             "session_id": "capacity-example", "hook_event_name": hook,
             "observed_at_ms": 1000000 + number, "turn_id": "turn-a"}
    event.update(fields)
    return event


def deliver(store: ReferenceStore, message: dict) -> str:
    return store.receive(message, message["observed_at_ms"], message["observed_at_ms"])


def check_capacities() -> None:
    store = ReferenceStore()
    for n in range(POLICY["sessions"]):
        assert deliver(store, example_event(n + 1, session_id=f"fictional-{n}")) == "applied"
    assert deliver(store, example_event(999, session_id="one-too-many")) == "session_capacity"
    assert len(store.sessions) == POLICY["sessions"]

    store = ReferenceStore()
    first = example_event(1)
    assert deliver(store, first) == "applied"
    for n in range(2, POLICY["event_ids"] + 1):
        assert deliver(store, example_event(n)) == "repeated_submit"
    assert deliver(store, first) == "duplicate"
    assert deliver(store, example_event(POLICY["event_ids"] + 1)) == "identity_capacity"
    session = next(iter(store.sessions.values()))
    assert len(session.seen) == POLICY["event_ids"] and session.status == "unknown"

    store = ReferenceStore()
    for n in range(POLICY["turn_ids"]):
        assert deliver(store, example_event(n * 2 + 1, turn_id=f"turn-{n}")) == "applied"
        assert deliver(store, example_event(n * 2 + 2, "Stop", turn_id=f"turn-{n}")) == "applied"
    assert deliver(store, example_event(999, turn_id="overflow")) == "identity_capacity"
    session = next(iter(store.sessions.values()))
    assert len(session.turns) == POLICY["turn_ids"] and session.status == "unknown"

    store = ReferenceStore()
    assert deliver(store, example_event(1)) == "applied"
    for n in range(POLICY["requests"]):
        assert deliver(store, example_event(n + 2, "PermissionRequest", tool_name="Bash",
                                            tool_use_id=f"tool-{n}")) == "applied"
    assert deliver(store, example_event(999, "PermissionRequest", tool_name="Bash",
                                        tool_use_id="overflow")) == "request_capacity"
    session = next(iter(store.sessions.values()))
    assert len(session.pending) == POLICY["requests"] and session.status == "unknown"


def check_document() -> None:
    contract = ROOT / "docs/contracts/agent-events-v1.md"
    text = contract.read_text()
    labels = {
        "raw_hook_bytes": "Raw hook stdin",
        "frame_bytes": "Wire frame, including LF",
        "delivery_age_ms": "Maximum delivery age",
        "future_skew_ms": "Allowed future clock difference",
        "freshness_ms": "Observation freshness",
        "sessions": "Sessions per app run",
        "event_ids": "Event IDs per session",
        "turn_ids": "Distinct turn IDs per session",
        "requests": "Pending requests per session",
    }
    for key, label in labels.items():
        match = re.search(r"^\| " + re.escape(label) + r" \| (\d+)", text, re.MULTILINE)
        assert match and int(match[1]) == POLICY[key], f"Document policy differs: {label}"
    for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", text):
        assert (contract.parent / target).is_file(), f"Missing contract link: {target}"


def main() -> None:
    cases = json.loads((ROOT / "docs/contracts/agent-events-v1-cases.json").read_text())
    assert cases["policy"] == POLICY, "Fixture policy differs from the checker"
    check_document()
    print("PASS document policy and local links")
    check_messages(cases["messages"])
    print(f'PASS {len(cases["messages"])} message validation cases')
    steps = check_sequences(cases["sequences"])
    print(f'PASS {len(cases["sequences"])} state sequences ({steps} steps)')
    check_capacities()
    print("PASS 4 memory capacity boundaries")


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, InvalidMessage, KeyError, TypeError, ValueError) as error:
        print(f"FAIL {error}", file=sys.stderr)
        sys.exit(1)
