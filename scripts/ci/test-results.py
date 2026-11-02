#!/usr/bin/env python3
"""Validate the native Swift Testing stream and summarize its actual outcomes."""

import json
import os
from pathlib import Path
import sys


def main() -> None:
    reports = Path(os.environ['RUNNER_TEMP']) / 'notch-pet-ci/reports'
    def require(condition):
        if not condition:
            raise ValueError('malformed native results')
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result)
            result[key] = value
        return result
    try:
        path = reports / 'tests.jsonl'
        require(path.is_file() and not path.is_symlink() and 0 < path.stat().st_size <= 32 * 1024 * 1024)
        raw = path.read_bytes()
        require(raw.endswith(b'\n'))
        definitions, events = {}, []
        lines = raw.splitlines()
        require(len(lines) <= 100000)
        for line in lines:
            require(len(line) <= 1024 * 1024)
            row = json.loads(line, object_pairs_hook=unique)
            require(type(row) is dict and row.get('version') == '6.3.0')
            value = row.get('payload')
            require(type(value) is dict)
            if row.get('kind') == 'test':
                identity = value.get('id')
                require(type(identity) is str and 0 < len(identity) <= 4096 and identity not in definitions)
                require(value.get('kind') in ('function', 'suite') and type(value.get('name')) is str)
                if value['kind'] == 'function':
                    require(type(value.get('isParameterized')) is bool)
                definitions[identity] = value
            elif row.get('kind') == 'event':
                require(type(value.get('kind')) is str)
                events.append(value)
            else:
                raise ValueError('unsupported native record')
        beginnings = [i for i, event in enumerate(events) if event['kind'] == 'runStarted']
        endings = [i for i, event in enumerate(events) if event['kind'] == 'runEnded']
        require(len(beginnings) == len(endings) == 1 and beginnings[0] < endings[0])
        started, ended, skipped, failed, cancelled = set(), set(), set(), set(), set()
        case_starts, case_ends = {}, {}
        failures = warnings = known = 0
        for i, event in enumerate(events):
            kind, identity = event['kind'], event.get('testID')
            if kind in ('runStarted', 'runEnded'):
                continue
            require(beginnings[0] < i < endings[0])
            if identity is not None:
                require(type(identity) is str and identity in definitions)
            if kind in ('testStarted', 'testEnded', 'testSkipped', 'testCancelled', 'testCaseCancelled', 'testCaseStarted', 'testCaseEnded'):
                require(identity is not None)
            if kind == 'testStarted':
                require(identity not in started)
                started.add(identity)
            elif kind == 'testEnded':
                require(identity in started and identity not in ended)
                ended.add(identity)
            elif kind == 'testSkipped':
                require(identity not in skipped and identity not in started)
                skipped.add(identity)
            elif kind in ('testCancelled', 'testCaseCancelled'):
                cancelled.add(identity)
            elif kind in ('testCaseStarted', 'testCaseEnded'):
                counts = case_starts if kind == 'testCaseStarted' else case_ends
                counts[identity] = counts.get(identity, 0) + 1
            elif kind == 'issueRecorded':
                issue = event.get('issue')
                require(type(issue) is dict and type(issue.get('isFailure')) is bool)
                is_known = issue.get('isKnown', False)
                require(type(is_known) in (str, bool))
                if is_known is True or type(is_known) is str:
                    known += 1
                elif issue['isFailure']:
                    failures += 1
                    if identity is not None:
                        failed.add(identity)
                else:
                    warnings += 1
        functions = {identity: value for identity, value in definitions.items() if value['kind'] == 'function'}
        require(bool(functions))
        outcomes = []
        counts = dict.fromkeys(('passed', 'failed', 'skipped', 'cancelled', 'incomplete'), 0)
        for identity, value in sorted(functions.items()):
            status = ('skipped' if identity in skipped else 'cancelled' if identity in cancelled
                      else 'failed' if identity in failed else 'passed' if identity in ended else 'incomplete')
            if case_starts.get(identity, 0) != case_ends.get(identity, 0) and status != 'cancelled':
                status = 'incomplete'
            counts[status] += 1
            outcomes.append({'id': identity, 'name': value['name'], 'status': status,
                             'is_parameterized': value['isParameterized'], 'parameterized_cases': case_ends.get(identity, 0)})
        exit_code = int((reports / 'tests-exit-code.txt').read_text())
        complete = not counts['incomplete']
        success = (exit_code == 0 and complete and counts['passed'] > 0 and failures == 0
                   and counts['failed'] == counts['cancelled'] == 0)
        summary = {'schema_version': 1, 'native_schema': '6.3.0', 'command_exit_code': exit_code,
                   'complete': complete, 'outcome': 'success' if success else 'failure', 'counts': counts,
                   'test_functions': len(functions), 'suites': len(definitions)-len(functions),
                   'parameterized_cases': sum(case_ends.values()), 'failing_issues': failures,
                   'warnings': warnings, 'known_issues': known, 'tests': outcomes}
        (reports / 'test-summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as output:
            output.write('## Swift test results\n\n' + ', '.join(f'{name}: {count}' for name, count in counts.items()) + '\n')
        print('Native Swift results:', len(functions), 'functions;', counts)
        sys.exit(0 if success else 1)
    except (OSError, ValueError, TypeError, KeyError, RecursionError):
        reports.mkdir(parents=True, exist_ok=True)
        (reports / 'tests-summary-error.txt').write_text('Native results are missing, malformed or incomplete\n')
        print('Native results are missing, malformed or incomplete', file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
