#!/usr/bin/env python3
"""Validate foundation job results, with optional evidence reports for CI."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys

MAX_INPUT = 16 * 1024
JOBS = {"workflow": "Workflow", "tests": "Tests", "build": "Build",
        "contract": "Contract", "helper": "Helper"}
KNOWN_RESULTS = {"success", "failure", "cancelled", "skipped"}


def unique_jobs(pairs: list[tuple[str, object]]) -> dict:
    result: dict = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate job")
        result[key] = value
    return result


def required_result(raw: str | None) -> tuple[bool, list[str]]:
    results: dict = {}
    reason = ""
    try:
        if raw is None or not raw.strip() or len(raw.encode("utf-8")) > MAX_INPUT:
            raise ValueError("missing or oversized results")
        value = json.loads(raw, object_pairs_hook=unique_jobs)
        if type(value) is not dict:
            raise ValueError("expected object")
        results = value
    except (ValueError, RecursionError):
        reason = "missing or malformed job results"
    if not reason and results.keys() != JOBS.keys():
        reason = "unexpected job set"
    labels: list[str] = []
    all_success = not reason
    for key, name in JOBS.items():
        if key not in results:
            label = "missing"
        elif type(results[key]) is not str:
            label = "malformed"
        elif results[key] in KNOWN_RESULTS:
            label = results[key]
        else:
            label = "unknown"
        all_success = all_success and label == "success"
        labels.append(f"{name}: {label}")
    labels.append("Required: success" if all_success else "Required: failure")
    if reason:
        labels.append("Reason: " + reason)
    return all_success, labels


def write_reports() -> int:
    reports = Path(os.environ['RUNNER_TEMP']) / 'notch-pet-ci/reports'
    success, lines = required_result(os.environ.get('CI_JOB_RESULTS'))

    def load_object(key):
        raw = os.environ.get(key, '')
        if len(raw.encode('utf-8')) > MAX_INPUT:
            raise ValueError('oversized evidence')
        value = json.loads(raw, object_pairs_hook=unique_jobs)
        if type(value) is not dict:
            raise ValueError('invalid evidence shape')
        return value

    try:
        receipts = load_object('CI_EVIDENCE_RESULTS')
        evidence_ok = receipts.keys() == JOBS.keys() and all(value == 'true' for value in receipts.values())
    except (ValueError, RecursionError):
        receipts, evidence_ok = {}, False
    try:
        states = load_object('CI_JOB_RESULTS')
    except (ValueError, RecursionError):
        states = {}
    status = 0 if success and evidence_ok else 1
    text = ('\n'.join(lines) + '\n')[:4096] + ('Evidence: complete\n' if evidence_ok else 'Evidence: missing or invalid\n')
    text += 'Overall Required: ' + ('success' if status == 0 else 'failure') + '\n'
    (reports / 'required.log').write_text(text)
    (reports / 'required-exit-code.txt').write_text(str(status) + '\n')
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as summary:
        summary.write('## Required result\n\n| Job | Result | Evidence |\n|---|---|---|\n')
        for key, name in JOBS.items():
            state = states.get(key)
            label = state if type(state) is str and state in KNOWN_RESULTS else 'unknown'
            available = 'complete' if receipts.get(key) == 'true' else 'missing/unavailable'
            summary.write('| ' + name + ' | ' + label + ' | ' + available + ' |\n')
        summary.write('\nOverall Required: ' + ('success' if status == 0 else 'failure') + '\n')
    print(text)
    return status


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reports', action='store_true', help='also validate evidence and write the CI summary')
    arguments = parser.parse_args()
    if arguments.reports:
        return write_reports()
    success, lines = required_result(os.environ.get("CI_JOB_RESULTS"))
    print("\n".join(lines))
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
