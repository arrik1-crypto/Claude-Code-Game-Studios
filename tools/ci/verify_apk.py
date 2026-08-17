#!/usr/bin/env python3
"""Verify a built Android APK without an emulator or a device.

    python3 tools/ci/verify_apk.py build/android/crimson-vespers.apk

Checks, in order, and exits non-zero on the first hard failure:

1. **Signature** — via `apksigner`. Android 11+ (API 30+) will not install an
   APK signed only with the v1 JAR scheme, so v2 or v3 must be present.
2. **Manifest** — the `AndroidManifest.xml` inside an APK is compiled to binary
   AXML, not text, so `grep` finds nothing useful in it. This decodes the chunk
   format directly and asserts the package name, version, and — the one that
   actually bit us — the screen orientation.
3. **Native libraries** — every declared ABI must carry a Godot engine library,
   or the app installs and then dies on launch on that architecture.
4. **Payload** — the game's own scenes and data must be present, so a
   well-formed but empty shell is caught.
5. **Size** — against the project's stated export budget.

What this CANNOT tell you is whether the game runs. See `--help` output and the
closing report line: rendering, input, audio and performance are device-only.
"""

from __future__ import annotations

import argparse
import re
import struct
import subprocess
import sys
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

## The project's stated export budget, from .claude/docs/technical-preferences.md.
MAX_APK_MB = 80.0

## Expected identity.
EXPECTED_PACKAGE = "com.crimsonvespers.game"

## Android `screenOrientation` values that keep the long edge horizontal.
## 0 landscape, 8 reverseLandscape, 11 sensorLandscape, 6 userLandscape.
LANDSCAPE_VALUES = {0, 6, 8, 11}

ORIENTATION_NAMES = {
    -1: "unspecified", 0: "landscape", 1: "portrait", 2: "user", 3: "behind",
    4: "sensor", 5: "nosensor", 6: "sensorLandscape", 7: "sensorPortrait",
    8: "reverseLandscape", 9: "reversePortrait", 10: "fullSensor",
    11: "userLandscape", 12: "userPortrait", 13: "fullUser", 14: "locked",
}

## Files that prove the actual game shipped, not just an engine shell.
##
## Note the shapes here. Godot ships the *imported* form of any resource it
## converts — textures become `.ctex` and streamed audio becomes
## `.oggvorbisstr`, both under `.godot/imported/` with a content hash in the
## name — while plain data files it does not import (our JSON) ship as-is.
## Looking for the source `.ogg` finds nothing even in a perfectly good APK.
REQUIRED_PAYLOAD = [
    re.compile(r"assets/assets/data/game_balance\.json$"),
    re.compile(r"assets/assets/data/rooms/room_throne_of_ash\.json$"),
    re.compile(r"assets/\.godot/imported/hero\.png-.*\.ctex$"),
    re.compile(r"assets/\.godot/imported/boss\.ogg-.*\.oggvorbisstr$"),
    re.compile(r"assets/\.godot/imported/whip\.wav-.*\.sample$"),
]

## The uncompressed boss theme this project used to ship. If it reappears, the
## 9.8 MB WAV has come back and the transcode step has regressed.
STALE_PAYLOAD = re.compile(r"boss\.wav", re.IGNORECASE)

## Things that must NOT ship: dev tooling, tests, docs.
FORBIDDEN_PAYLOAD = re.compile(
    r"assets/(tests|tools|docs|design|production|prototypes)/", re.IGNORECASE)


# ---------------------------------------------------------------- AXML decoding


def _utf8_len(data: bytes, p: int) -> tuple[int, int]:
    b0 = data[p]
    if b0 & 0x80:
        return ((b0 & 0x7F) << 8) | data[p + 1], p + 2
    return b0, p + 1


def _utf16_len(data: bytes, p: int) -> tuple[int, int]:
    v = struct.unpack_from("<H", data, p)[0]
    if v & 0x8000:
        hi = v & 0x7FFF
        lo = struct.unpack_from("<H", data, p + 2)[0]
        return (hi << 16) | lo, p + 4
    return v, p + 2


def _read_string_pool(data: bytes, off: int) -> tuple[list[str], int]:
    _type, _hsize, csize = struct.unpack_from("<HHI", data, off)
    count, _styles, flags, str_off, _sty_off = struct.unpack_from("<IIIII", data, off + 8)
    is_utf8 = bool(flags & (1 << 8))
    offsets = struct.unpack_from("<%dI" % count, data, off + 28)
    base = off + str_off

    pool: list[str] = []
    for o in offsets:
        p = base + o
        if is_utf8:
            _chars, p = _utf8_len(data, p)
            nbytes, p = _utf8_len(data, p)
            pool.append(data[p:p + nbytes].decode("utf-8", "replace"))
        else:
            nchars, p = _utf16_len(data, p)
            pool.append(data[p:p + nchars * 2].decode("utf-16-le", "replace"))
    return pool, off + csize


def decode_manifest(raw: bytes) -> tuple[list[dict], list[str]]:
    """Return (elements, string_pool) from a binary AndroidManifest.xml.

    Each element is {"tag": str, "attrs": {name: value}}. Attribute values are
    resolved to their raw string when the manifest stored one, and left as the
    integer otherwise — which is the case for every enum, orientation included.
    """
    if raw[0:2] != b"\x03\x00":
        raise ValueError("not a binary AXML file")

    pool, pos = _read_string_pool(raw, 8)
    elements: list[dict] = []

    while pos + 8 <= len(raw):
        ctype, _hsize, csize = struct.unpack_from("<HHI", raw, pos)
        if csize < 8:
            break
        if ctype == 0x0102:  # RES_XML_START_ELEMENT_TYPE
            name_idx = struct.unpack_from("<i", raw, pos + 20)[0]
            attr_start = struct.unpack_from("<H", raw, pos + 24)[0]
            attr_count = struct.unpack_from("<H", raw, pos + 28)[0]
            tag = pool[name_idx] if 0 <= name_idx < len(pool) else "?"

            attrs: dict[str, object] = {}
            abase = pos + 16 + attr_start
            for i in range(attr_count):
                a = abase + i * 20
                if a + 20 > len(raw):
                    break
                _ns, nm, rawval, typed, dat = struct.unpack_from("<iiiIi", raw, a)
                key = pool[nm] if 0 <= nm < len(pool) else "?"
                if 0 <= rawval < len(pool):
                    attrs[key] = pool[rawval]
                else:
                    data_type = (typed >> 24) & 0xFF
                    attrs[key] = bool(dat) if data_type == 0x12 else dat
            elements.append({"tag": tag, "attrs": attrs})
        pos += csize

    return elements, pool


# ------------------------------------------------------------------- the checks


class Report:
    def __init__(self) -> None:
        self.failures: list[str] = []
        self.warnings: list[str] = []

    def ok(self, label: str, detail: str = "") -> None:
        print(f"  PASS  {label}" + (f"  — {detail}" if detail else ""))

    def fail(self, label: str, detail: str) -> None:
        print(f"  FAIL  {label}  — {detail}")
        self.failures.append(f"{label}: {detail}")

    def warn(self, label: str, detail: str) -> None:
        print(f"  WARN  {label}  — {detail}")
        self.warnings.append(f"{label}: {detail}")


def check_signature(apk: Path, r: Report) -> None:
    print("\nSignature")
    try:
        proc = subprocess.run(["apksigner", "verify", "--verbose", apk.as_posix()],
                              capture_output=True, text=True, timeout=300)
    except FileNotFoundError:
        r.fail("apksigner", "not installed; cannot verify the signature")
        return

    out = proc.stdout
    if "Verifies" not in out:
        r.fail("signature", f"apksigner rejected the APK: {proc.stderr.strip()[:200]}")
        return

    schemes = {}
    for line in out.splitlines():
        m = re.match(r"Verified using (v\d) scheme.*: (true|false)", line)
        if m:
            schemes[m.group(1)] = m.group(2) == "true"

    r.ok("apksigner verify", "signature is valid")
    modern = schemes.get("v2", False) or schemes.get("v3", False)
    detail = ", ".join(f"{k}={'yes' if v else 'no'}" for k, v in sorted(schemes.items()))
    if modern:
        r.ok("modern signing scheme", detail)
    else:
        r.fail("modern signing scheme",
               f"Android 11+ refuses to install a v1-only APK ({detail})")


def check_manifest(apk: Path, r: Report) -> None:
    print("\nManifest")
    with zipfile.ZipFile(apk) as z:
        raw = z.read("AndroidManifest.xml")
    elements, pool = decode_manifest(raw)

    manifest = next((e for e in elements if e["tag"] == "manifest"), None)
    activities = [e for e in elements if e["tag"] == "activity"]

    if manifest is None:
        r.fail("manifest element", "no <manifest> tag decoded")
        return

    package = manifest["attrs"].get("package", "")
    if package == EXPECTED_PACKAGE:
        r.ok("package name", package)
    else:
        r.fail("package name", f"expected {EXPECTED_PACKAGE}, got {package!r}")

    version_code = manifest["attrs"].get("versionCode")
    version_name = manifest["attrs"].get("versionName")
    r.ok("version", f"code={version_code} name={version_name}")

    sdk = next((e for e in elements if e["tag"] == "uses-sdk"), None)
    if sdk:
        r.ok("sdk range", f"min={sdk['attrs'].get('minSdkVersion')} "
                          f"target={sdk['attrs'].get('targetSdkVersion')}")

    # The orientation check. This is the one that caught a portrait-locked
    # landscape game, so it is a hard failure rather than a warning.
    orientations = [a["attrs"]["screenOrientation"] for a in activities
                    if "screenOrientation" in a["attrs"]]
    if not orientations:
        r.fail("screen orientation", "no activity declares screenOrientation")
    else:
        for value in orientations:
            name = ORIENTATION_NAMES.get(value, "?")
            if value in LANDSCAPE_VALUES:
                r.ok("screen orientation", f"{name} ({value})")
            else:
                r.fail("screen orientation",
                       f"{name} ({value}) — this game is landscape-only")

    permissions = sorted({e["attrs"].get("name", "?") for e in elements
                          if e["tag"] == "uses-permission"})
    # Fall back to the string pool when permission names are stored as
    # references rather than inline strings.
    if not permissions:
        permissions = sorted(s for s in pool if s.startswith("android.permission."))
    if permissions:
        r.warn("permissions", ", ".join(permissions) +
               "  (DUMP is added by the DEBUG template and is absent from release builds)")
    else:
        r.ok("permissions", "none requested")


def check_payload(apk: Path, r: Report) -> None:
    print("\nPayload")
    with zipfile.ZipFile(apk) as z:
        names = z.namelist()

    libs: dict[str, list[str]] = {}
    for n in names:
        m = re.match(r"lib/([^/]+)/(.+\.so)$", n)
        if m:
            libs.setdefault(m.group(1), []).append(m.group(2))

    if not libs:
        r.fail("native libraries", "no .so files — the app cannot start")
    for abi, sos in sorted(libs.items()):
        if any("libgodot_android" in s for s in sos):
            r.ok(f"abi {abi}", f"{len(sos)} libs incl. the engine")
        else:
            r.fail(f"abi {abi}", "no libgodot_android.so — this ABI would crash on launch")

    for pattern in REQUIRED_PAYLOAD:
        if any(pattern.search(n) for n in names):
            r.ok("payload", pattern.pattern)
        else:
            r.fail("payload", f"missing: {pattern.pattern}")

    leaked = [n for n in names if FORBIDDEN_PAYLOAD.search(n)]
    if leaked:
        r.fail("dev files", f"{len(leaked)} shipped, e.g. {leaked[:3]}")
    else:
        r.ok("dev files", "no tests/tools/docs in the package")

    stale = [n for n in names if STALE_PAYLOAD.search(n)]
    if stale:
        r.fail("stale audio", f"the uncompressed boss theme is back: {stale[:2]}")
    else:
        r.ok("stale audio", "no uncompressed boss.wav")


def check_size(apk: Path, r: Report) -> None:
    print("\nSize")
    mb = apk.stat().st_size / 1048576
    if mb <= MAX_APK_MB:
        r.ok("apk size", f"{mb:.1f} MB (budget {MAX_APK_MB:.0f} MB)")
    else:
        r.fail("apk size", f"{mb:.1f} MB exceeds the {MAX_APK_MB:.0f} MB budget")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("apk", nargs="?",
                        default=str(REPO_ROOT / "build/android/crimson-vespers.apk"))
    args = parser.parse_args()

    apk = Path(args.apk)
    if not apk.exists():
        print(f"error: {apk} not found", file=sys.stderr)
        return 1

    print(f"Verifying {apk}")
    r = Report()
    check_signature(apk, r)
    check_manifest(apk, r)
    check_payload(apk, r)
    check_size(apk, r)

    print("\n" + "=" * 62)
    if r.failures:
        print(f"RESULT: FAIL — {len(r.failures)} problem(s)")
        for f in r.failures:
            print(f"  - {f}")
        return 1

    print(f"RESULT: PASS — {len(r.warnings)} warning(s)")
    print("\nNOT verified here (requires a physical device or emulator):")
    print("  rendering and framerate, touch input, audio playback, save/load")
    print("  against real storage, memory ceiling, and install on a real ABI.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
