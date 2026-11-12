#!/usr/bin/env python3
"""Check the actual pet app with disposable preferences and window-only captures.

Never quits an existing app instance or changes agent configuration. Requires a
GUI session; capture access is needed unless --skip-capture is explicitly used.
Fixtures and generated probes stay outside the repository. Visual inspection is
reported as skipped in no-capture mode, never inferred from window metadata.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import time
import uuid


CONTROL = r'''
import AppKit
import CoreGraphics
let args = CommandLine.arguments
switch args[1] {
case "focus":
    print(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1)
case "watchFocus":
    let destination = URL(fileURLWithPath: args[2])
    var activations: [Int32] = []
    try JSONSerialization.data(withJSONObject: activations).write(to: destination, options: .atomic)
    let observer = NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { notification in
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            activations.append(app.processIdentifier)
            try? JSONSerialization.data(withJSONObject: activations).write(to: destination, options: .atomic)
        }
    }
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 90))
    NSWorkspace.shared.notificationCenter.removeObserver(observer)
case "quit":
    guard let pid = Int32(args[2]), let app = NSRunningApplication(processIdentifier: pid),
          app.terminate() else { exit(1) }
case "windows":
    let pid = Int32(args[2])!
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0)
        as? [[String: Any]] ?? []
    let owned = windows.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }
    print(String(data: try JSONSerialization.data(withJSONObject: owned), encoding: .utf8)!)
default: exit(2)
}
'''


def run_case(app: Path, root: Path, control: Path, suite: str, name: str,
             skip_capture: bool = False) -> dict:
    case = root / name
    case.mkdir()
    (case / "codex").mkdir()
    (case / "claude").mkdir()
    env = {key: value for key, value in os.environ.items()
           if key in {"PATH", "TMPDIR", "DEVELOPER_DIR"}}
    env.update(NOTCH_PET_PREFERENCES_SUITE=suite,
               NOTCH_PET_EVIDENCE_DIR=str(case),
               CODEX_HOME=str(case / "codex"), CLAUDE_CONFIG_DIR=str(case / "claude"))
    activation_file = case / "focus-activations.json"
    monitor = subprocess.Popen([str(control), "watchFocus", str(activation_file)])
    monitor_deadline = time.monotonic() + 10
    while not activation_file.exists() and monitor.poll() is None and time.monotonic() < monitor_deadline:
        time.sleep(0.05)
    if not activation_file.exists():
        monitor.terminate()
        monitor.wait(timeout=10)
        raise AssertionError("native focus monitor did not start")
    focus_before = int(subprocess.check_output([str(control), "focus"], text=True))
    executable = app / "Contents/MacOS/NotchPet"
    with (case / "stdout.txt").open("w") as out, (case / "stderr.txt").open("w") as err:
        process = subprocess.Popen([str(executable)], env=env, stdout=out, stderr=err)
        try:
            deadline = time.monotonic() + 20
            evidence_file = case / "pet.json"
            while not evidence_file.exists() and time.monotonic() < deadline:
                assert process.poll() is None, f"{name}: app exited before evidence"
                time.sleep(0.1)
            assert evidence_file.exists(), f"{name}: no evidence from normal app startup"
            evidence = json.loads(evidence_file.read_text())
            assert evidence["pid"] == process.pid
            assert Path(evidence["executable"]).resolve() == executable.resolve()
            assert evidence["petVisible"] and evidence["artworkLoaded"]
            assert evidence["presentation"] == "pet" and evidence["agentServicesEnabled"] is False
            assert evidence["size"] >= 64 and evidence["size"] <= 256
            assert set(evidence["serviceStarts"]) == {
                "eventReceiver", "usageReceiver", "providerProcess", "configurationProbe", "agentRefresh"
            }
            assert all(value == 0 for value in evidence["serviceStarts"].values())
            windows = json.loads(subprocess.check_output(
                [str(control), "windows", str(process.pid)], text=True))
            (case / "windows.json").write_text(json.dumps(windows, indent=2))
            pet = [w for w in windows if w["kCGWindowNumber"] == evidence["windowNumber"]]
            assert len(pet) == 1, f"{name}: pet window not independently observed"
            bounds = pet[0]["kCGWindowBounds"]
            assert abs(bounds["Width"] - evidence["size"]) <= 1
            assert abs(bounds["Height"] - evidence["size"]) <= 1
            if not skip_capture:
                capture = case / "pet.png"
                subprocess.run(["/usr/sbin/screencapture", "-x", "-o", "-l",
                                str(evidence["windowNumber"]), str(capture)], check=True, timeout=15)
                assert capture.exists() and capture.stat().st_size > 1024, f"{name}: invalid capture"
            evidence["captureSkipped"] = skip_capture
            focus_after = int(subprocess.check_output([str(control), "focus"], text=True))
            evidence["independentFocusBefore"] = focus_before
            evidence["independentFocusAfter"] = focus_after
            assert monitor.poll() is None, "native focus monitor ended before observation completed"
            evidence["activationPIDs"] = json.loads(activation_file.read_text())
            (case / "observed.json").write_text(json.dumps(evidence, indent=2))
            assert process.pid not in evidence["activationPIDs"], f"{name}: test app took keyboard focus"
            assert process.pid not in {focus_before, focus_after, evidence["focusBefore"], evidence["focusAfter"]}
            (case / "verified.json").write_text(json.dumps(evidence, indent=2))
            subprocess.run([str(control), "quit", str(process.pid)], check=True, timeout=15)
            process.wait(timeout=15)
            assert process.returncode == 0, f"{name}: Quit failed"
            final = json.loads(evidence_file.read_text())
            assert final["phase"] == "terminated", f"{name}: normal Quit lifecycle not observed"
            assert all(value == 0 for value in final["serviceStarts"].values())
            return evidence
        finally:
            if monitor.poll() is None:
                monitor.terminate()
                monitor.wait(timeout=10)
            if process.poll() is None:
                # Target only the instance this check created.
                subprocess.run([str(control), "quit", str(process.pid)], timeout=10)
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.terminate()
                    process.wait(timeout=10)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", required=True, type=Path)
    parser.add_argument("--artifacts", required=True, type=Path)
    parser.add_argument("--skip-capture", action="store_true",
                        help="Run native checks without screenshots; visual acceptance remains skipped")
    args = parser.parse_args()
    app = args.app.resolve()
    root = args.artifacts.resolve() / uuid.uuid4().hex
    repo = Path(__file__).resolve().parents[1]
    assert not root.is_relative_to(repo), "artifacts must stay outside the repository"
    resource = app / "Contents/Resources/NotchPet_Pet.bundle"
    assert resource.is_dir(), "packaged Pet resource bundle missing"
    assert list(resource.rglob("white-lionhead-idle.png")), "packaged rabbit missing"
    root.mkdir(parents=True)
    (root / "control.swift").write_text(CONTROL)
    control = root / "control"
    subprocess.run(["/usr/bin/swiftc", str(root / "control.swift"), "-o", str(control)],
                   check=True, timeout=120)
    suite = "local.notchpet.verify." + uuid.uuid4().hex
    try:
        missing = run_case(app, root, control, suite, "missing-preferences", args.skip_capture)
        assert missing["size"] == 120, "missing preferences must use default size"
        subprocess.run(["/usr/bin/defaults", "write", suite, "pet.size", "-float", "180"], check=True)
        saved = run_case(app, root, control, suite, "saved-size", args.skip_capture)
        restored = run_case(app, root, control, suite, "saved-size-relaunch", args.skip_capture)
        assert saved["size"] == restored["size"] == 180, "saved size did not survive Quit/relaunch"
        subprocess.run(["/usr/bin/defaults", "write", suite, "pet.size", "-string", "invalid"], check=True)
        invalid = run_case(app, root, control, suite, "invalid-preferences", args.skip_capture)
        assert invalid["size"] == 120, "invalid preferences must use default size"
        checks = ["visible rabbit without agent panels/warnings", "usable default size",
                  "saved size survives Quit/relaunch", "invalid size fallback",
                  "zero production agent-service starts", "keyboard focus preserved"]
        report = {"checks": checks, "passed": 5 if args.skip_capture else 6,
                  "skipped": 1 if args.skip_capture else 0, "total": 6, "artifacts": str(root),
                  "visualInspectionRequired": True, "captureSkipped": args.skip_capture,
                  "sizeSeedMethod": "isolated UserDefaults domain; setter covered by Swift tests"}
        (root / "result.json").write_text(json.dumps(report, indent=2))
        for index, check in enumerate(checks):
            print("SKIP (user requested no capture):" if args.skip_capture and index == 0 else "PASS:", check)
        if args.skip_capture:
            print("5/6 real-app checks passed; 1 visual check skipped by request:", root)
        else:
            print("6/6 real-app checks passed; inspect captures:", root)
    finally:
        subprocess.run(["/usr/bin/defaults", "delete", suite], capture_output=True)


if __name__ == "__main__":
    main()
