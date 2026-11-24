#!/usr/bin/env python3
"""Package an ad-hoc Bunlet ZIP and a signed Sparkle appcast for an existing HTTPS host."""

import argparse
import base64
import binascii
import plistlib
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urlsplit


SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"


def validate(args):
    feed = urlsplit(args.feed_url)
    downloads = urlsplit(args.download_prefix)
    for url in (feed, downloads):
        local_http = args.local_test and url.scheme == "http" and url.hostname in ("127.0.0.1", "localhost")
        if (url.scheme != "https" and not local_http) or not url.hostname or url.username or url.password or url.query or url.fragment:
            raise ValueError("The feed and download prefix must be HTTPS URLs without credentials or query parameters.")
    if args.local_test and (feed.scheme != "http" or feed.hostname not in ("127.0.0.1", "localhost")
                            or (feed.scheme, feed.netloc) != (downloads.scheme, downloads.netloc)):
        raise ValueError("A local test requires both URLs on the same HTTP loopback origin.")
    if not downloads.path.endswith("/") or not feed.path.endswith("/appcast.xml"):
        raise ValueError("The feed URL must end in /appcast.xml and the download prefix must end in /.")
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", args.version) or not re.fullmatch(r"[1-9][0-9]*", args.build):
        raise ValueError("Use an X.Y.Z release version and a positive numeric build number.")
    try:
        if len(base64.b64decode(args.public_key, validate=True)) != 32:
            raise ValueError("The update public key must be a base64-encoded 32-byte Ed25519 key.")
    except binascii.Error as error:
        raise ValueError("The update public key must be base64-encoded.") from error


def make_relocatable(executable):
    commands = subprocess.check_output(["/usr/bin/otool", "-l", executable], text=True)
    rpaths = re.findall(r"cmd LC_RPATH\n\s+cmdsize \d+\n\s+path (.*?) \(offset \d+\)", commands)
    build_paths = dict.fromkeys(path for path in rpaths if path.startswith("/") and path != "/usr/lib/swift")
    if build_paths:
        flags = [item for path in build_paths for item in ("-delete_rpath", path)]
        subprocess.run(["/usr/bin/install_name_tool", *flags, executable], check=True)
    return rpaths


def package(args):
    validate(args)
    if args.output.exists():
        raise ValueError("Choose a new output directory.")
    with tempfile.TemporaryDirectory(prefix="bunlet-package-") as directory:
        stage = Path(directory)
        app = stage / "Bunlet.app"
        subprocess.run(["/usr/bin/ditto", args.app, app], check=True)
        contents = app / "Contents"
        framework = contents / "Frameworks" / "Sparkle.framework"
        if not (framework / "Sparkle").is_file():
            raise ValueError("Build Bunlet with BUNLET_ENABLE_SPARKLE=1 before packaging.")
        # The app resolves its SwiftPM resource bundles only from Contents/Resources.
        for name in ("NotchPet_Pet.bundle", "NotchPet_NotchPet.bundle"):
            if not (contents / "Resources" / name).is_dir():
                raise ValueError(f"The app is missing Contents/Resources/{name}.")
        info = contents / "Info.plist"
        with info.open("rb") as stream:
            metadata = plistlib.load(stream)
        if args.local_test:
            if not metadata.get("CFBundleIdentifier", "").startswith("local.notchpet.update-qa."):
                raise ValueError("Use a disposable bundle identifier for a loopback test.")
            metadata["NSAppTransportSecurity"] = {"NSAllowsLocalNetworking": True}
        metadata.update(
            CFBundleShortVersionString=args.version,
            CFBundleVersion=args.build,
            SUFeedURL=args.feed_url,
            SUPublicEDKey=args.public_key,
            SUEnableAutomaticChecks=False,
            SUAutomaticallyUpdate=False,
            SUAllowsAutomaticUpdates=False,
            SUVerifyUpdateBeforeExtraction=True,
            SURequireSignedFeed=True,
            SUSignedFeedFailureExpirationInterval=0,
        )
        with info.open("wb") as stream:
            plistlib.dump(metadata, stream)

        main = contents / "MacOS" / "NotchPet"
        if subprocess.check_output(["/usr/bin/lipo", "-archs", main], text=True).strip() != "arm64":
            raise ValueError("Build this release on Apple silicon for arm64.")
        if "@executable_path/../Frameworks" not in make_relocatable(main):
            raise ValueError("The app does not have a search path for the embedded Sparkle framework.")

        # Sign nested code before sealing the outer bundle. This workflow is for ad-hoc releases.
        sign = ["/usr/bin/codesign", "--force", "--sign", "-", "--timestamp=none"]
        subprocess.run(sign + ["--deep", str(framework)], check=True)
        for helper in ("NotchPetHook", "NotchPetStatusLine", "NotchPetActionHook"):
            executable = contents / "MacOS" / helper
            make_relocatable(executable)
            subprocess.run(sign + [str(executable)], check=True)
        subprocess.run(sign + [str(app)], check=True)
        subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", app], check=True)

        assets = stage / "assets"
        assets.mkdir()
        archive = assets / f"Bunlet-{args.version}-{args.build}-macOS-arm64.zip"
        subprocess.run(["/usr/bin/ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app, archive], check=True)
        command = [str(args.generate_appcast), "--download-url-prefix", args.download_prefix, "--maximum-deltas", "0"]
        if args.key_file:
            command.extend(["--ed-key-file", str(args.key_file)])
        else:
            command.extend(["--account", args.account])
        subprocess.run(command + [str(assets)], check=True)
        feed = assets / "appcast.xml"
        enclosure = ET.parse(feed).find("./channel/item/enclosure")
        if (enclosure is None or not enclosure.get(SPARKLE + "edSignature")
                or enclosure.get("url") != args.download_prefix + archive.name
                or enclosure.get("length") != str(archive.stat().st_size)
                or b"<!-- sparkle-signatures:" not in feed.read_bytes()):
            raise ValueError("Sparkle did not emit a signed archive entry.")

        args.output.mkdir()
        for item in (archive, feed):
            subprocess.run(["/usr/bin/ditto", item, args.output / item.name], check=True)
            print(args.output / item.name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path, help="A new directory for the release assets")
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--feed-url", required=True)
    parser.add_argument("--download-prefix", required=True)
    parser.add_argument("--public-key", required=True)
    parser.add_argument("--generate-appcast", required=True, type=Path)
    parser.add_argument("--account", default="bunlet", help="Private signing key account in the macOS Keychain")
    parser.add_argument("--key-file", type=Path, help="Use a private key file instead of the macOS Keychain")
    parser.add_argument("--local-test", action="store_true", help="Allow a disposable app to check a loopback feed")
    args = parser.parse_args()
    try:
        package(args)
    except (ValueError, OSError, subprocess.CalledProcessError, ET.ParseError) as error:
        parser.exit(1, f"Could not package an update: {error}\n")


if __name__ == "__main__":
    main()
