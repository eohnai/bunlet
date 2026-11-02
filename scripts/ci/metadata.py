#!/usr/bin/env python3
"""Record allowlisted CI metadata or prepare independent build identity."""

import argparse
import json
import os
from pathlib import Path
import platform
import subprocess
import sys


def collect_metadata() -> None:
    reports = Path(os.environ['RUNNER_TEMP']) / 'notch-pet-ci/reports'
    reports.mkdir(parents=True, exist_ok=True)

    def version(command):
        try:
            result = subprocess.run(command, capture_output=True, timeout=10)
            if result.returncode == 0 and len(result.stdout) <= 4096:
                return result.stdout.decode('utf-8').strip()
        except (OSError, subprocess.SubprocessError, UnicodeError):
            pass
        return 'unavailable'

    mac = sys.platform == 'darwin'
    value = {
        'schema_version': 1, 'commit': os.environ['GITHUB_SHA'],
        'run_id': os.environ['GITHUB_RUN_ID'], 'run_attempt': int(os.environ['GITHUB_RUN_ATTEMPT']),
        'job': os.environ['GITHUB_JOB'], 'selected_runner': os.environ['CI_RUNNER_LABEL'],
        'execution_context': 'github-actions' if os.environ.get('GITHUB_ACTIONS') == 'true' else 'local-replay',
        'actual_os': platform.system(), 'os_version': platform.mac_ver()[0] if mac else platform.release(),
        'architecture': platform.machine(), 'image_os': os.environ.get('ImageOS', 'unavailable'),
        'image_version': os.environ.get('ImageVersion', 'unavailable'), 'python': platform.python_version(),
        'selected_xcode': os.environ.get('DEVELOPER_DIR', 'not used'),
        'xcode': version(['/usr/bin/xcodebuild', '-version']) if mac else 'not used',
        'swift': version(['/usr/bin/xcrun', 'swift', '--version']) if mac else 'not used',
        'llvm_cov': version(['/usr/bin/xcrun', 'llvm-cov', '--version']) if os.environ['GITHUB_JOB'] == 'tests' else 'not used',
        'actionlint': 'not collected' if os.environ['GITHUB_JOB'] == 'workflow' else 'not used',
    }
    (reports / 'metadata.json').write_text(json.dumps(value, indent=2) + '\n')
    print('Recorded allowlisted run and tool versions')


def write_identity() -> None:
    swift = subprocess.run(['/usr/bin/xcrun', 'swift', '--version'],
                           capture_output=True, text=True, check=True, timeout=10)
    identity = {'commit': os.environ['GITHUB_SHA'], 'run_id': os.environ['GITHUB_RUN_ID'],
                'run_attempt': int(os.environ['GITHUB_RUN_ATTEMPT']), 'platform': 'macos',
                'architecture': 'arm64', 'configuration': 'debug', 'xcode_build': '17F42',
                'swift_version': swift.stdout.strip()}
    root = Path(os.environ['RUNNER_TEMP']) / 'notch-pet-ci'
    root.mkdir(parents=True, exist_ok=True)
    text = json.dumps(identity, indent=2) + '\n'
    (root / 'identity.json').write_text(text)
    (root / 'reports/expected-identity.json').write_text(text)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--identity", action="store_true", help="write independent expected build identity")
    arguments = parser.parse_args()
    if arguments.identity:
        write_identity()
    else:
        collect_metadata()


if __name__ == "__main__":
    main()
