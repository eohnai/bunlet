#!/usr/bin/env python3
"""Export production Swift coverage from a successful instrumented test build."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import html
from html.parser import HTMLParser
import json
import math
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
from urllib.parse import quote, unquote, urlsplit, urlunsplit

ROOT = Path(__file__).resolve().parents[2]
MAX_FILE = 64 * 1024 * 1024
MAX_JSON = 32 * 1024 * 1024
MAX_LOG = 65536
MAX_SOURCES = 4096
METRICS = ("lines", "functions", "regions")
URL_ATTRIBUTE = re.compile(r"\b(href|src)=(['\"])(.*?)\2", re.DOTALL)


class CoverageError(ValueError):
    pass


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise CoverageError(reason)


def read_regular(path: Path, limit: int) -> bytes:
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, "rb") as stream:
        info = os.fstat(stream.fileno())
        require(stat.S_ISREG(info.st_mode) and 0 < info.st_size <= limit, "missing, empty or oversized input")
        data = stream.read(limit + 1)
    require(len(data) == info.st_size and len(data) <= limit, "input changed or exceeded limit")
    return data


def unique_object(pairs: list[tuple[str, object]]) -> dict:
    value: dict = {}
    for key, item in pairs:
        require(key not in value, "duplicate JSON field")
        value[key] = item
    return value


def production_sources() -> set[Path]:
    sources: set[Path] = set()
    for path in (ROOT / "Sources").rglob("*"):
        require(not path.is_symlink(), "linked production source is unsupported")
        if path.is_file() and path.suffix == ".swift":
            require(len(path.relative_to(ROOT).parts) >= 3, "source has no module directory")
            sources.add(path.resolve())
            require(len(sources) <= MAX_SOURCES, "too many production sources")
    require(bool(sources), "no production Swift sources")
    return sources


def validated_metric(value: dict) -> tuple[int, int]:
    require(type(value) is dict, "invalid coverage metric")
    count, covered, percent = value.get("count"), value.get("covered"), value.get("percent")
    require(type(count) is int and type(covered) is int and 0 <= covered <= count,
            "invalid coverage counts")
    require(type(percent) in (int, float) and math.isfinite(percent), "invalid coverage percentage")
    expected = covered * 100 / count if count else 0
    require(abs(percent - expected) <= 0.000001, "inconsistent coverage percentage")
    if "notcovered" in value:
        require(type(value["notcovered"]) is int and value["notcovered"] == count - covered,
                "inconsistent uncovered count")
    return count, covered


def metric(count: int, covered: int) -> dict:
    return {"count": count, "covered": covered,
            "percent": round(covered * 100 / count, 4) if count else None}


def normalize_report(report: dict, sources: set[Path]) -> tuple[dict, dict]:
    require(type(report) is dict and report.get("type") == "llvm.coverage.json.export"
            and type(report.get("version")) is str and re.fullmatch(r"3\.\d+\.\d+", report["version"]) is not None,
            "unsupported LLVM coverage JSON")
    require(type(report.get("data")) is list and len(report["data"]) == 1, "invalid coverage data set")
    data = report["data"][0]
    require(type(data) is dict and data.keys() == {"files", "totals"}, "unfiltered or malformed coverage data")
    require(type(data["files"]) is list and len(data["files"]) == len(sources), "missing production file coverage")
    require(type(data["totals"]) is dict, "missing coverage totals")
    seen: set[Path] = set()
    modules: dict = {}
    total_counts = {name: [0, 0] for name in METRICS}
    for row in data["files"]:
        require(type(row) is dict and type(row.get("filename")) is str, "invalid coverage file")
        path = Path(row["filename"])
        path = (ROOT / path).resolve() if not path.is_absolute() else path.resolve()
        require(path in sources and path not in seen, "unexpected or duplicate production source")
        seen.add(path)
        relative = path.relative_to(ROOT).as_posix()
        row["filename"] = relative
        require(type(row.get("segments")) is list and type(row.get("branches")) is list
                and type(row.get("mcdc_records")) is list, "invalid coverage detail")
        for segment in row["segments"]:
            require(type(segment) is list and len(segment) == 6
                    and all(type(v) is int and v >= 1 for v in segment[:2])
                    and type(segment[2]) is int and segment[2] >= 0
                    and all(type(v) is bool for v in segment[3:]), "invalid coverage segment")
        summary = row.get("summary")
        require(type(summary) is dict, "missing file coverage summary")
        for value in summary.values():
            validated_metric(value)
        module = path.relative_to(ROOT / "Sources").parts[0]
        module_row = modules.setdefault(module, {"files": [], "counts": {name: [0, 0] for name in METRICS}})
        module_row["files"].append(relative)
        for name in METRICS:
            count, covered = validated_metric(summary.get(name))
            module_row["counts"][name][0] += count
            module_row["counts"][name][1] += covered
            total_counts[name][0] += count
            total_counts[name][1] += covered
    require(seen == sources, "incomplete production coverage")
    for name in METRICS:
        require(validated_metric(data["totals"].get(name)) == tuple(total_counts[name]),
                "coverage totals do not match source files")
    normalized_modules = {}
    for name, module in sorted(modules.items()):
        normalized_modules[name] = {"file_count": len(module["files"]), "files": sorted(module["files"]),
                                    **{key: metric(*module["counts"][key]) for key in METRICS}}
    summary = {"schema_version": 1, "scope": "Sources/**/*.swift",
               "excluded": ["Tests/**", "generated sources outside Sources/**"],
               "file_count": len(sources), "modules": normalized_modules,
               "totals": {key: metric(*total_counts[key]) for key in METRICS}}
    data["files"].sort(key=lambda row: row["filename"])
    return report, summary


def log_message(path: Path, data: bytes) -> None:
    remaining = max(0, MAX_LOG - path.stat().st_size)
    if remaining:
        with path.open("ab") as stream:
            stream.write(data[:remaining])


def run_native(arguments: list[str], stdout: Path, log: Path) -> None:
    stderr = stdout.with_suffix(stdout.suffix + ".stderr")
    with stdout.open("wb") as output, stderr.open("wb") as errors:
        try:
            result = subprocess.run(["/usr/bin/xcrun", "llvm-cov", *arguments],
                                    cwd=ROOT, stdout=output, stderr=errors, timeout=60)
        except subprocess.TimeoutExpired:
            log_message(log, b"llvm-cov timed out\n")
            raise CoverageError("coverage tool timed out") from None
    with stderr.open("rb") as stream:
        diagnostics = stream.read(MAX_LOG)
    log_message(log, ("llvm-cov " + arguments[0] + f": exit={result.returncode}\n").encode() + diagnostics)
    require(result.returncode == 0, "coverage tool failed; see coverage-tool.log")


def rewrite_link(value: str, old: Path, new: Path, mapping: dict[Path, Path]) -> str:
    parts = urlsplit(html.unescape(value))
    if parts.scheme or parts.netloc or not parts.path:
        return value
    target = (old.parent / unquote(parts.path)).resolve()
    require(target in mapping, "HTML refers to a missing report asset")
    relative = os.path.relpath(mapping[target], new.parent).replace(os.sep, "/")
    return html.escape(urlunsplit(("", "", quote(relative, safe="/._-"), parts.query, parts.fragment)), quote=True)


class PortableHTML(HTMLParser):
    def __init__(self, old: Path, new: Path, mapping: dict[Path, Path]):
        super().__init__(convert_charrefs=False)
        self.old, self.new, self.mapping = old, new, mapping
        self.parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list) -> None:
        def replace(match: re.Match) -> str:
            rewritten = rewrite_link(match[3], self.old, self.new, self.mapping)
            return match[1] + "=" + match[2] + rewritten + match[2]
        self.parts.append(URL_ATTRIBUTE.sub(replace, self.get_starttag_text()))

    def handle_startendtag(self, tag: str, attrs: list) -> None:
        self.handle_starttag(tag, attrs)

    def handle_endtag(self, tag: str) -> None:
        self.parts.append(f"</{tag}>")

    def handle_data(self, data: str) -> None:
        self.parts.append(data)

    def handle_entityref(self, name: str) -> None:
        self.parts.append(f"&{name};")

    def handle_charref(self, name: str) -> None:
        self.parts.append(f"&#{name};")

    def handle_decl(self, decl: str) -> None:
        self.parts.append(f"<!{decl}>")

    def handle_comment(self, data: str) -> None:
        self.parts.append(f"<!--{data}-->")


class LinkCheck(HTMLParser):
    def __init__(self, page: Path, root: Path):
        super().__init__()
        self.page, self.root = page, root

    def handle_starttag(self, tag: str, attrs: list) -> None:
        for name, value in attrs:
            if name not in {"href", "src"} or value is None:
                continue
            parts = urlsplit(value)
            if parts.scheme or parts.netloc or not parts.path:
                continue
            target = (self.page.parent / unquote(parts.path)).resolve()
            require(target.is_relative_to(self.root) and target.is_file(), "broken local HTML link")


def portable_html(raw: Path, output: Path, sources: set[Path]) -> None:
    mapping = {raw / name: output / name for name in ("index.html", "style.css", "control.js")}
    source_pages = {}
    for source in sources:
        old = raw / "coverage" / (source.as_posix().lstrip("/") + ".html")
        new = output / "coverage" / (source.relative_to(ROOT).as_posix() + ".html")
        mapping[old] = new
        source_pages[old] = source
    actual = set()
    total = 0
    for path in raw.rglob("*"):
        require(not path.is_symlink(), "linked HTML report file")
        if path.is_file():
            actual.add(path)
            total += path.stat().st_size
    require(actual == mapping.keys() and total <= MAX_FILE, "missing or unexpected HTML report files")
    for old, new in mapping.items():
        data = read_regular(old, MAX_FILE)
        new.parent.mkdir(parents=True, exist_ok=True)
        if old.suffix != ".html":
            new.write_bytes(data)
            continue
        body = data.decode("utf-8")
        if old in source_pages:
            source = source_pages[old]
            marker = "<div class='source-name-title'><pre>" + html.escape(str(source), quote=False) + "</pre>"
            require(body.count(marker) == 1, "unsupported LLVM source title")
            body = body.replace(marker, "<div class='source-name-title'><pre>"
                                + html.escape(source.relative_to(ROOT).as_posix(), quote=False) + "</pre>")
        parser = PortableHTML(old, new, mapping)
        parser.feed(body)
        parser.close()
        new.write_text("".join(parser.parts), encoding="utf-8")
    for page in output.rglob("*.html"):
        parser = LinkCheck(page, output)
        parser.feed(page.read_text(encoding="utf-8"))
        parser.close()


def write_summary(path: Path, summary: dict) -> None:
    rows = ["# Production Swift coverage", "",
            "Only Sources/**/*.swift is included. No coverage threshold is enforced.", "",
            "| Module | Files | Covered lines | Line coverage |", "|---|---:|---:|---:|"]
    for name, module in summary["modules"].items():
        lines = module["lines"]
        percent = f'{lines["percent"]:.2f}%' if lines["percent"] is not None else "not applicable"
        rows.append(f'| {name} | {module["file_count"]} | {lines["covered"]}/{lines["count"]} | {percent} |')
    rows.extend(["", "Coverage records execution. It does not establish test adequacy.", ""])
    path.write_text("\n".join(rows), encoding="utf-8")


def export_coverage(build_root: Path, output: Path) -> None:
    profiles = list(build_root.glob("*/debug/codecov/default.profdata"))
    binaries = list(build_root.glob("*/debug/NotchPetPackageTests.xctest/Contents/MacOS/NotchPetPackageTests"))
    require(len(profiles) == len(binaries) == 1, "missing or ambiguous test runner/profile")
    profile, binary = profiles[0], binaries[0]
    debug = profile.parent.parent
    require(binary.parents[3] == debug, "test runner and profile build mismatch")
    helper = debug / "NotchPetHook"
    fingerprints = {"profile_sha256": hashlib.sha256(read_regular(profile, MAX_FILE)).hexdigest(),
                    "test_runner_sha256": hashlib.sha256(read_regular(binary, MAX_FILE)).hexdigest(),
                    "helper_sha256": hashlib.sha256(read_regular(helper, MAX_FILE)).hexdigest()}
    sources = production_sources()
    output = output.resolve()
    require(not output.is_relative_to(ROOT), "coverage output must be outside the checkout")
    destination = output / "coverage"
    require(not os.path.lexists(destination), "coverage output already exists")
    output.mkdir(parents=True, exist_ok=True)
    log = output / "coverage-tool.log"
    with log.open("xb"):
        pass
    with tempfile.TemporaryDirectory(prefix="notch-coverage-", dir=output) as temporary:
        temporary = Path(temporary)
        staged = temporary / "coverage"
        staged.mkdir()
        arguments = [str(binary), "--object", str(helper), "--instr-profile", str(profile), "--debuginfod=false"]
        source_arguments = ["--sources", *map(str, sorted(sources))]
        exported = temporary / "llvm-export.json"
        run_native(["export", *arguments, "--skip-functions", "--skip-expansions", *source_arguments], exported, log)
        raw = json.loads(read_regular(exported, MAX_JSON), object_pairs_hook=unique_object)
        report, summary = normalize_report(raw, sources)
        run_native(["show", *arguments, "--format=html", "--output-dir", str(temporary / "raw-html"),
                    *source_arguments], temporary / "llvm-show.txt", log)
        portable_html(temporary / "raw-html", staged / "html", sources)
        run_native(["--version"], temporary / "llvm-version.txt", log)
        version = read_regular(temporary / "llvm-version.txt", MAX_LOG).decode("utf-8").strip()
        metadata = {"schema_version": 1, "generated_at": datetime.now(timezone.utc).isoformat(),
                    "llvm_cov_version": version, "llvm_json_version": report["version"], **fingerprints}
        for name, value in (("coverage.json", report), ("summary.json", summary), ("metadata.json", metadata)):
            (staged / name).write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")
        write_summary(staged / "summary.md", summary)
        require(not os.path.lexists(destination), "coverage output appeared during export")
        staged.rename(destination)
    print(f'Exported coverage: {summary["file_count"]} production files in {len(summary["modules"])} modules')
    print((destination / "summary.md").read_text())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    try:
        export_coverage(arguments.build_root, arguments.output)
    except CoverageError as error:
        print(f"Coverage export failed: {error}", file=sys.stderr)
        return 1
    except (OSError, ValueError, TypeError, KeyError, RecursionError, subprocess.SubprocessError):
        print("Coverage export failed: unreadable or malformed input", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
