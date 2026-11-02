#!/usr/bin/env python3
"""Run a foundation check with bounded logs and its original exit status."""

import json
import os
from pathlib import Path
import subprocess
import sys


def main() -> None:
    root = Path(os.environ['RUNNER_TEMP']) / 'notch-pet-ci'
    reports = root / 'reports'
    reports.mkdir(parents=True, exist_ok=True)
    job = os.environ['GITHUB_JOB']
    commands = {
        'workflow': [str(root / 'tools/actionlint'), '.github/workflows/ci.yml'],
        'tests': ['swift', 'test', '--scratch-path', str(root / 'test-build'), '--enable-code-coverage',
                  '--event-stream-output-path', str(reports / 'tests.jsonl'), '--event-stream-version', '6.3'],
        'build': ['bash', 'scripts/run.sh', '--build-only'],
        'contract': [sys.executable, 'scripts/check-event-contract.py'],
        'helper': [sys.executable, 'scripts/check-event-bridge.py', '--helper',
                   str(root / 'extracted/Notch Pet.app/Contents/MacOS/NotchPetHook')],
    }
    if job not in commands:
        raise SystemExit('Unsupported check job')
    environment = dict(os.environ)
    if job == 'build':
        (root / 'package').mkdir(parents=True, exist_ok=True)
        environment['TMPDIR'] = str(root / 'package')
    limit = 2 * 1024 * 1024
    log = reports / (job + '.log')
    tail = bytearray()
    total = 0
    with log.open('wb') as stream:
        try:
            process = subprocess.Popen(commands[job], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=environment)
            while chunk := process.stdout.read(65536):
                if total < limit:
                    stream.write(chunk[:limit-total])
                    stream.flush()
                total += len(chunk)
                tail.extend(chunk)
                if len(tail) > limit:
                    del tail[:-limit]
            returned = process.wait()
            status = returned if returned >= 0 else 128 - returned
        except OSError:
            stream.write(b'Could not start the required check\n')
            status = 127
        if total > limit:
            marker = b'[log truncated; final output follows]\n'
            stream.seek(0)
            stream.write(marker + tail[-(limit-len(marker)):])
            stream.truncate()
    try:
        (reports / (job + '-exit-code.txt')).write_text(str(status) + '\n')
        metadata_path = reports / 'metadata.json'
        if metadata_path.exists():
            value = json.loads(metadata_path.read_text())
            value['check_exit_code'] = status
            if job == 'workflow':
                value['actionlint'] = (reports / 'validator-version.txt').read_text()[:4096].strip()
            metadata_path.write_text(json.dumps(value, indent=2) + '\n')
        with log.open('rb') as stream:
            stream.seek(max(0, log.stat().st_size - 4096))
            print(stream.read().decode('utf-8', errors='replace'))
        print('Check exit code:', status)
    except (OSError, ValueError, TypeError):
        print('Check report collection failed', file=sys.stderr)
        if status == 0:
            status = 1
    sys.exit(status)


if __name__ == "__main__":
    main()
