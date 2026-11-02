#!/usr/bin/env python3
"""Archive and verify the debug app without executing either bundled binary."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import platform
import plistlib
import re
import stat
import struct
import subprocess
import sys
import tarfile
import tempfile
import unicodedata
from xml.parsers.expat import ExpatError

ROOT = Path(__file__).resolve().parents[2]
APP = "Notch Pet.app"
MAX_ENTRIES = 4096
MAX_PATH = 240
MAX_MANIFEST = 4 * 1024 * 1024
MAX_FILE = 64 * 1024 * 1024
MAX_TOTAL = 256 * 1024 * 1024
MAX_TAR = MAX_TOTAL + MAX_ENTRIES * 1024 + 10240
IDENTITY_FIELDS = {"commit", "run_id", "run_attempt", "platform", "architecture",
                   "configuration", "xcode_build", "swift_version"}


class BundleError(ValueError):
    pass


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise BundleError(reason)


def read_regular(path: Path, limit: int) -> bytes:
    # Refuse links and non-regular descriptors before reading their contents.
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, "rb") as stream:
        info = os.fstat(stream.fileno())
        require(stat.S_ISREG(info.st_mode) and info.st_size <= limit, "invalid file type or size")
        data = stream.read(limit + 1)
    require(len(data) <= limit and len(data) == info.st_size, "file size changed or exceeded limit")
    return data


def unique_object(pairs: list[tuple[str, object]]) -> dict:
    result: dict = {}
    for key, value in pairs:
        require(key not in result, "duplicate JSON field")
        result[key] = value
    return result


def json_object(data: bytes) -> dict:
    value = json.loads(data, object_pairs_hook=unique_object)
    require(type(value) is dict, "expected JSON object")
    return value


def identity_from(path: Path) -> dict:
    value = json_object(read_regular(path, MAX_MANIFEST))
    require(value.keys() == IDENTITY_FIELDS, "invalid identity fields")
    require(type(value["commit"]) is str and re.fullmatch(r"[0-9a-f]{40}", value["commit"]) is not None,
            "invalid commit identity")
    for key in ("run_id", "xcode_build"):
        require(type(value[key]) is str and re.fullmatch(r"[A-Za-z0-9_-]{1,64}", value[key]) is not None,
                "invalid run or toolchain identity")
    require(type(value["run_attempt"]) is int and 1 <= value["run_attempt"] <= 1_000_000,
            "invalid run attempt")
    require(value["platform"] == "macos" and value["architecture"] == "arm64"
            and value["configuration"] == "debug", "unsupported platform or configuration")
    version = value["swift_version"]
    require(type(version) is str and 1 <= len(version.encode("utf-8")) <= 1024
            and all(c == "\n" or 32 <= ord(c) < 127 for c in version), "invalid Swift identity")
    return value


def safe_path(name: str) -> None:
    require(type(name) is str and 0 < len(name.encode("utf-8")) <= MAX_PATH, "invalid archive path")
    pieces = name.split("/")
    require(pieces[0] == APP and all(p not in {"", ".", ".."} for p in pieces)
            and "\\" not in name and all(ord(c) >= 32 and ord(c) != 127 for c in name),
            "unsafe archive path")


def validate_entries(entries: dict) -> None:
    require(type(entries) is dict and 1 <= len(entries) <= MAX_ENTRIES, "invalid entry table")
    total = 0
    folded: set[str] = set()
    for name, entry in entries.items():
        safe_path(name)
        canonical = unicodedata.normalize("NFC", name).casefold()
        require(canonical not in folded, "colliding archive paths")
        folded.add(canonical)
        require(type(entry) is dict and entry.get("type") in {"file", "directory"}, "invalid entry type")
        expected = {"type", "mode", "size", "sha256"} if entry["type"] == "file" else {"type", "mode"}
        require(entry.keys() == expected, "invalid entry fields")
        mode = entry["mode"]
        require(type(mode) is int and 0 <= mode <= 0o777 and not mode & 0o022, "unsafe entry mode")
        require(bool(mode & 0o400), "entry is not readable")
        if entry["type"] == "file":
            require(type(entry["size"]) is int and 0 <= entry["size"] <= MAX_FILE, "invalid entry size")
            require(type(entry["sha256"]) is str and re.fullmatch(r"[0-9a-f]{64}", entry["sha256"]) is not None,
                    "invalid file checksum")
            total += entry["size"]
        else:
            require(bool(mode & 0o100), "directory is not searchable")
        if name != APP:
            parent = str(PurePosixPath(name).parent)
            parent_entry = entries.get(parent)
            require(type(parent_entry) is dict and parent_entry.get("type") == "directory",
                    "missing or invalid parent directory")
    require(entries.get(APP, {}).get("type") == "directory" and total <= MAX_TOTAL, "invalid bundle root or size")


def validate_app(entries: dict, payloads: dict[str, bytes]) -> None:
    for executable in ("NotchPet", "NotchPetHook"):
        name = f"{APP}/Contents/MacOS/{executable}"
        require(name in payloads and entries[name]["mode"] & 0o100 != 0, "missing executable or executable mode")
        data = payloads[name]
        # The foundation qualifies a thin arm64 Mach-O executable, not universal/release builds.
        require(len(data) >= 32, "invalid executable header")
        magic, cpu, _, file_type = struct.unpack("<IIII", data[:16])
        require((magic, cpu, file_type) == (0xFEEDFACF, 0x0100000C, 2), "executable architecture or type mismatch")
    plist = payloads.get(f"{APP}/Contents/Info.plist")
    require(plist is not None and len(plist) <= MAX_MANIFEST, "missing or oversized app plist")
    info = plistlib.loads(plist)
    require(type(info) is dict and info.get("CFBundleExecutable") == "NotchPet"
            and info.get("CFBundlePackageType") == "APPL"
            and info.get("CFBundleIdentifier") == "local.notchpet.dev", "invalid app plist identity")
    resource_root = f"{APP}/Contents/Resources/NotchPet_Pet.bundle"
    manifest = payloads.get(resource_root + "/manifest.json")
    require(manifest is not None and len(manifest) <= MAX_MANIFEST, "missing Pet manifest")
    pet = json_object(manifest)
    animations = pet.get("animations")
    require(type(pet.get("version")) is int and pet["version"] == 1
            and type(animations) is dict and "idle" in animations and 1 <= len(animations) <= 64,
            "invalid Pet manifest")
    for animation in animations.values():
        require(type(animation) is dict, "invalid Pet animation")
        frames = animation.get("frames")
        require(type(frames) is list and 1 <= len(frames) <= 256, "invalid Pet frames")
        for frame in frames:
            require(type(frame) is str and re.fullmatch(r"[A-Za-z0-9_-]{1,128}", frame) is not None,
                    "invalid Pet resource name")
            png = payloads.get(f"{resource_root}/{frame}.png", b"")
            require(png.startswith(b"\x89PNG\r\n\x1a\n") and len(png) >= 24, "missing or invalid Pet artwork")


def source_entries(app: Path) -> tuple[dict, dict[str, bytes]]:
    require(app.name == APP and stat.S_ISDIR(app.lstat().st_mode), "invalid source app directory")
    entries: dict = {}
    payloads: dict[str, bytes] = {}
    pending = [app]
    total = 0
    while pending:
        path = pending.pop()
        name = APP if path == app else APP + "/" + path.relative_to(app).as_posix()
        safe_path(name)
        require(len(entries) < MAX_ENTRIES, "too many source entries")
        info = path.lstat()
        mode = stat.S_IMODE(info.st_mode)
        if stat.S_ISDIR(info.st_mode):
            entries[name] = {"type": "directory", "mode": mode}
            pending.extend(sorted(path.iterdir(), reverse=True))
        else:
            require(stat.S_ISREG(info.st_mode) and info.st_nlink == 1, "unsupported source entry")
            data = read_regular(path, MAX_FILE)
            total += len(data)
            require(total <= MAX_TOTAL, "source bundle exceeds size limit")
            payloads[name] = data
            entries[name] = {"type": "file", "mode": mode, "size": len(data),
                             "sha256": hashlib.sha256(data).hexdigest()}
    validate_entries(entries)
    validate_app(entries, payloads)
    return entries, payloads


def tool_output(arguments: list[str]) -> str:
    result = subprocess.run(arguments, capture_output=True, timeout=10)
    require(result.returncode == 0 and len(result.stdout) + len(result.stderr) <= 4096,
            "toolchain metadata command failed")
    return result.stdout.decode("utf-8").strip()


def actual_metadata(identity: dict) -> dict:
    require(sys.platform == "darwin" and platform.machine() == identity["architecture"], "build host mismatch")
    xcode = tool_output(["/usr/bin/xcodebuild", "-version"])
    require(xcode.splitlines()[-1] == "Build version " + identity["xcode_build"], "Xcode identity mismatch")
    require(tool_output(["/usr/bin/xcrun", "swift", "--version"]) == identity["swift_version"],
            "Swift identity mismatch")
    return {"macos_version": platform.mac_ver()[0], "python_version": platform.python_version()}


def new_destination(path: Path) -> Path:
    resolved = path.resolve()
    require(not resolved.is_relative_to(ROOT), "destination must be outside the checkout")
    require(not os.path.lexists(path), "destination already exists")
    resolved.parent.mkdir(parents=True, exist_ok=True)
    return resolved


def create_bundle(app: Path, output: Path, identity: dict) -> None:
    entries, payloads = source_entries(app)
    metadata = actual_metadata(identity)
    archive_buffer = io.BytesIO()
    # USTAR avoids extension records with hidden paths or unbounded metadata.
    with tarfile.open(fileobj=archive_buffer, mode="w:", format=tarfile.USTAR_FORMAT) as archive:
        for name, entry in sorted(entries.items()):
            member = tarfile.TarInfo(name)
            member.mode = entry["mode"]
            member.type = tarfile.DIRTYPE if entry["type"] == "directory" else tarfile.REGTYPE
            member.size = entry.get("size", 0)
            archive.addfile(member, io.BytesIO(payloads[name]) if name in payloads else None)
    archive_data = gzip.compress(archive_buffer.getvalue(), mtime=0)
    require(len(archive_data) <= MAX_TOTAL, "compressed archive exceeds limit")
    manifest = {"schema_version": 1, "app": APP, "identity": identity, "metadata": metadata,
                "archive": {"name": "app.tar.gz", "size": len(archive_data),
                            "sha256": hashlib.sha256(archive_data).hexdigest()}, "entries": entries}
    manifest_data = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode("utf-8")
    require(len(manifest_data) <= MAX_MANIFEST, "manifest exceeds limit")
    output = new_destination(output)
    with tempfile.TemporaryDirectory(prefix="notch-bundle-", dir=output.parent) as temporary:
        staged = Path(temporary) / "bundle"
        staged.mkdir(mode=0o700)
        (staged / "app.tar.gz").write_bytes(archive_data)
        (staged / "manifest.json").write_bytes(manifest_data)
        require(not os.path.lexists(output), "destination appeared during creation")
        staged.rename(output)
    print(f"Created bundle: {len(payloads)} files, {len(archive_data)} archive bytes")


def verified_payloads(bundle: Path, identity: dict) -> tuple[dict, dict[str, bytes]]:
    require(stat.S_ISDIR(bundle.lstat().st_mode), "invalid bundle directory")
    require({path.name for path in bundle.iterdir()} == {"app.tar.gz", "manifest.json"}, "invalid bundle files")
    manifest = json_object(read_regular(bundle / "manifest.json", MAX_MANIFEST))
    require(manifest.keys() == {"schema_version", "app", "identity", "metadata", "archive", "entries"},
            "invalid manifest fields")
    require(type(manifest["schema_version"]) is int and manifest["schema_version"] == 1
            and manifest["app"] == APP, "unsupported bundle manifest")
    require(json.dumps(manifest["identity"], sort_keys=True) == json.dumps(identity, sort_keys=True),
            "bundle identity mismatch")
    metadata = manifest["metadata"]
    require(type(metadata) is dict and metadata.keys() == {"macos_version", "python_version"}
            and all(type(v) is str and re.fullmatch(r"[0-9.]{1,64}", v) is not None for v in metadata.values()),
            "invalid version metadata")
    entries = manifest["entries"]
    validate_entries(entries)
    archive_info = manifest["archive"]
    require(type(archive_info) is dict and archive_info.keys() == {"name", "size", "sha256"}
            and archive_info["name"] == "app.tar.gz", "invalid archive description")
    compressed = read_regular(bundle / "app.tar.gz", MAX_TOTAL)
    require(type(archive_info["size"]) is int and len(compressed) == archive_info["size"]
            and hashlib.sha256(compressed).hexdigest() == archive_info["sha256"], "archive checksum or size mismatch")
    with gzip.GzipFile(fileobj=io.BytesIO(compressed)) as stream:
        raw = stream.read(MAX_TAR + 1)
    require(len(raw) <= MAX_TAR and len(raw) % 512 == 0, "invalid uncompressed archive size")
    seen: set[str] = set()
    payloads: dict[str, bytes] = {}
    cursor = 0
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as archive:
        for member in archive:
            require(len(seen) < MAX_ENTRIES, "too many archive entries")
            safe_path(member.name)
            require(member.name not in seen and member.name in entries, "duplicate or unexpected archive entry")
            require(member.offset == cursor and member.offset_data == cursor + 512
                    and not member.pax_headers and not member.issparse(), "unsupported archive extension")
            seen.add(member.name)
            entry = entries[member.name]
            require(member.mode == entry["mode"], "entry mode mismatch")
            if entry["type"] == "directory":
                require(member.isdir() and member.size == 0, "entry type mismatch")
            else:
                require(member.isfile() and member.size == entry["size"], "entry type or size mismatch")
                stream = archive.extractfile(member)
                require(stream is not None, "missing archive payload")
                with stream:
                    data = stream.read(MAX_FILE + 1)
                require(len(data) == entry["size"] and hashlib.sha256(data).hexdigest() == entry["sha256"],
                        "file checksum or size mismatch")
                payloads[member.name] = data
            cursor = member.offset_data + ((member.size + 511) // 512) * 512
    require(seen == entries.keys(), "missing archive entry")
    require(len(raw) - cursor >= 1024 and not any(raw[cursor:]), "invalid archive end or trailing data")
    validate_app(entries, payloads)
    return entries, payloads


def verify_bundle(bundle: Path, identity: dict, extract_to: Path | None = None) -> None:
    # Snapshot and validate all bytes before publishing any extracted path.
    entries, payloads = verified_payloads(bundle, identity)
    if extract_to is not None:
        destination = new_destination(extract_to)
        with tempfile.TemporaryDirectory(prefix="notch-extract-", dir=destination.parent) as temporary:
            staged = Path(temporary) / "extracted"
            staged.mkdir(mode=0o700)
            directories = [name for name, entry in entries.items() if entry["type"] == "directory"]
            for name in sorted(directories, key=lambda value: (value.count("/"), value)):
                (staged / name).mkdir(mode=0o700)
            for name, data in payloads.items():
                path = staged / name
                with path.open("xb") as stream:
                    stream.write(data)
                path.chmod(entries[name]["mode"])
            for name in sorted(directories, key=lambda value: value.count("/"), reverse=True):
                (staged / name).chmod(entries[name]["mode"])
            require(not os.path.lexists(destination), "extraction destination appeared")
            staged.rename(destination)
    print(f"Verified bundle: {len(payloads)} files; identity, checksums and paths match")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--app", type=Path)
    mode.add_argument("--verify", type=Path, metavar="BUNDLE")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--identity", type=Path, required=True)
    parser.add_argument("--extract-to", type=Path)
    arguments = parser.parse_args()
    if arguments.app is not None and (arguments.output is None or arguments.extract_to is not None):
        parser.error("creation requires --output and does not accept --extract-to")
    if arguments.verify is not None and arguments.output is not None:
        parser.error("verification does not accept --output")
    try:
        identity = identity_from(arguments.identity)
        if arguments.app is not None:
            create_bundle(arguments.app, arguments.output, identity)
        else:
            verify_bundle(arguments.verify, identity, arguments.extract_to)
    except BundleError as error:
        print(f"Bundle verification failed: {error}", file=sys.stderr)
        return 1
    except (OSError, ValueError, TypeError, KeyError, RecursionError, tarfile.TarError,
            EOFError, ExpatError, subprocess.SubprocessError, struct.error):
        # Report a category, never raw paths, file content or decoder/tool output.
        print("Bundle verification failed: unreadable or malformed input", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
