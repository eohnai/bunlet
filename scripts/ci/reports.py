#!/usr/bin/env python3
"""Validate the current job report inventory and publish evidence receipts."""

import json
import os
from pathlib import Path
import stat
import sys


def main() -> None:
    root = Path(os.environ['RUNNER_TEMP']) / 'notch-pet-ci/reports'
    root.mkdir(parents=True, exist_ok=True)
    job = os.environ['GITHUB_JOB']
    expected = {
        'workflow': ['metadata.json', 'validator-setup.log', 'validator-version.txt', 'workflow.log', 'workflow-exit-code.txt'],
        'tests': ['metadata.json', 'tests.log', 'tests-exit-code.txt', 'tests.jsonl', 'test-summary.json',
                  'coverage-tool.log', 'coverage/coverage.json', 'coverage/summary.json',
                  'coverage/summary.md', 'coverage/metadata.json', 'coverage/html/index.html'],
        'build': ['metadata.json', 'expected-identity.json', 'build.log', 'build-exit-code.txt', 'archive.log', 'build-manifest.json'],
        'contract': ['metadata.json', 'contract.log', 'contract-exit-code.txt'],
        'helper': ['metadata.json', 'expected-identity.json', 'verification.log', 'helper.log', 'helper-exit-code.txt'],
        'required': ['metadata.json', 'required.log', 'required-exit-code.txt'],
    }[job]
    def valid_report(name, value):
        if type(value) is not dict:
            return False
        if name == 'metadata.json':
            fields = {'schema_version', 'commit', 'run_id', 'run_attempt', 'job', 'selected_runner',
                      'execution_context', 'actual_os', 'os_version', 'architecture', 'image_os', 'image_version',
                      'python', 'selected_xcode', 'xcode', 'swift', 'llvm_cov', 'actionlint'}
            return (fields <= value.keys() <= fields | {'check_exit_code'}
                    and type(value.get('schema_version')) is int and value['schema_version'] == 1
                    and value.get('commit') == os.environ['GITHUB_SHA']
                    and value.get('run_id') == os.environ['GITHUB_RUN_ID']
                    and type(value.get('run_attempt')) is int and value['run_attempt'] == int(os.environ['GITHUB_RUN_ATTEMPT'])
                    and value.get('job') == job
                    and all(type(value[key]) is str and 0 < len(value[key]) <= 4096
                            for key in fields - {'schema_version', 'run_attempt'}))
        if name == 'expected-identity.json':
            return (value.keys() == {'commit','run_id','run_attempt','platform','architecture','configuration','xcode_build','swift_version'}
                    and value.get('commit') == os.environ['GITHUB_SHA'] and value.get('run_id') == os.environ['GITHUB_RUN_ID']
                    and type(value.get('run_attempt')) is int and value['run_attempt'] == int(os.environ['GITHUB_RUN_ATTEMPT'])
                    and value.get('platform') == 'macos' and value.get('architecture') == 'arm64'
                    and value.get('configuration') == 'debug' and value.get('xcode_build') == '17F42'
                    and type(value.get('swift_version')) is str and bool(value['swift_version']))
        if name == 'test-summary.json':
            counts = value.get('counts', {})
            return (value.get('schema_version') == 1 and value.get('native_schema') == '6.3.0'
                    and value.get('complete') is True and type(value.get('test_functions')) is int and value['test_functions'] > 0
                    and type(value.get('tests')) is list and len(value['tests']) == value['test_functions']
                    and type(counts) is dict and counts.keys() == {'passed','failed','skipped','cancelled','incomplete'}
                    and all(type(count) is int and count >= 0 for count in counts.values())
                    and sum(counts.values()) == value['test_functions'] and value.get('outcome') in ('success','failure'))
        if name == 'coverage/coverage.json':
            data = value.get('data')
            return (value.get('type') == 'llvm.coverage.json.export' and type(data) is list and len(data) == 1
                    and type(data[0]) is dict and type(data[0].get('files')) is list and bool(data[0]['files']))
        if name == 'coverage/summary.json':
            return (value.get('schema_version') == 1 and type(value.get('modules')) is dict and bool(value['modules'])
                    and type(value.get('file_count')) is int and value['file_count'] > 0)
        if name == 'coverage/metadata.json':
            hashes = [value.get(key) for key in ('profile_sha256','test_runner_sha256','helper_sha256')]
            return (value.get('schema_version') == 1 and type(value.get('llvm_cov_version')) is str
                    and all(type(digest) is str and len(digest) == 64 and all(c in '0123456789abcdef' for c in digest) for digest in hashes))
        if name == 'build-manifest.json':
            return (value.get('schema_version') == 1 and value.get('app') == 'Notch Pet.app'
                    and type(value.get('identity')) is dict and value['identity'].get('commit') == os.environ['GITHUB_SHA']
                    and type(value.get('entries')) is dict and bool(value['entries']))
        return False
    rows = {}
    for name in expected:
        path = root / name
        label = 'missing'
        try:
            info = path.lstat()
            if not stat.S_ISREG(info.st_mode) or info.st_size > 32 * 1024 * 1024:
                label = 'invalid'
            elif name.endswith('.json'):
                value = json.loads(path.read_text())
                label = 'present' if valid_report(name, value) else 'invalid'
            elif name.endswith('-exit-code.txt'):
                text = path.read_text().strip()
                label = 'present' if text.isascii() and text.isdecimal() and 0 <= int(text) <= 255 else 'invalid'
            elif name.endswith('.jsonl'):
                with path.open('rb') as stream:
                    stream.seek(max(0, info.st_size - 1))
                    label = 'present' if info.st_size > 0 and stream.read() == b'\n' else 'invalid'
            else:
                label = 'present'
        except (OSError, ValueError, TypeError, KeyError, RecursionError):
            pass
        rows[name] = label
    complete = all(label == 'present' for label in rows.values())
    (root / 'inventory.json').write_text(json.dumps({'schema_version': 1, 'job': job,
                                                    'complete': complete, 'reports': rows}, indent=2) + '\n')
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        output.write('complete=' + ('true' if complete else 'false') + '\n')
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as summary:
        summary.write('## ' + job.title() + ' evidence\n\n| Report | Status |\n|---|---|\n')
        for name, label in rows.items():
            summary.write('| ' + name + ' | ' + label + ' |\n')
        if job == 'contract':
            summary.write('\nThe reference checker still differs from SessionStore\'s unseen-turn rule.\n')
    print('Evidence:', 'complete' if complete else 'incomplete')
    sys.exit(0 if complete else 1)


if __name__ == "__main__":
    main()
