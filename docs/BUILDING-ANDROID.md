# Building the Android APK

How to produce `crimson-vespers.apk` from a clean checkout, and how to verify it.

Everything here runs headless on Linux with no Godot editor GUI and no Android
Studio.

---

## 1. What you need

| Component | Version used | Where it comes from |
|---|---|---|
| Godot editor binary | 4.6-stable, Linux x86_64 | <https://godotengine.org/download/linux/> |
| Godot export templates | 4.6-stable (must match exactly) | `Godot_v4.6-stable_export_templates.tpz` from the same release |
| JDK | 21 (17 or newer works) | `apt install openjdk-21-jdk` |
| `apksigner`, `zipalign` | 31.0.2 / 10.0.0 | `apt install apksigner zipalign` |
| `adb` | 1.0.41 | `apt install adb` |
| `ffmpeg` | 6.1 | `apt install ffmpeg` — only needed to re-run the asset importer |

### A note on the Android SDK

The full Android SDK is **not** required for this build. `gradle_build/use_gradle_build`
is `false`, so Godot repacks the prebuilt template APK rather than compiling Java,
and the only SDK binaries it ever invokes are `apksigner`, `zipalign` and `adb`.
Ubuntu packages all three, which matters because `dl.google.com` is blocked by
egress policy in the environment this was built in.

Godot still insists on an SDK *directory layout* before it will export, so
assemble a minimal one that points at the Ubuntu binaries:

```sh
sudo mkdir -p /opt/android-sdk/build-tools/34.0.0 /opt/android-sdk/platform-tools
sudo ln -sf /usr/bin/apksigner /opt/android-sdk/build-tools/34.0.0/apksigner
sudo ln -sf /usr/bin/zipalign  /opt/android-sdk/build-tools/34.0.0/zipalign
sudo ln -sf /usr/bin/adb       /opt/android-sdk/platform-tools/adb
```

If you have a real Android SDK, point Godot at that instead — nothing here
depends on the shim.

---

## 2. One-time setup

### Export templates

They must sit in the editor data directory under a folder named for the exact
engine version, or the export fails with an **empty** error message:

```sh
mkdir -p ~/.local/share/godot/export_templates/4.6.stable
unzip Godot_v4.6-stable_export_templates.tpz -d /tmp/tpl
cp /tmp/tpl/templates/* ~/.local/share/godot/export_templates/4.6.stable/
```

Verify: `~/.local/share/godot/export_templates/4.6.stable/version.txt` reads
`4.6.stable`, and `android_debug.apk` is present.

### Debug keystore

The standard Android debug credentials. These are public by convention and are
not a secret — but they are also not a *release* key, see below.

```sh
keytool -genkeypair -v -keystore /opt/android-sdk/debug.keystore \
  -storepass android -keypass android -alias androiddebugkey \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Android Debug,O=Android,C=US"
```

### Editor settings

Godot reads these from `~/.config/godot/editor_settings-4.6.tres`. Generate the
file once with `godot --headless --editor --quit`, then set:

```
export/android/android_sdk_path = "/opt/android-sdk"
export/android/java_sdk_path = "/usr/lib/jvm/java-21-openjdk-amd64"
export/android/debug_keystore = "/opt/android-sdk/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
```

These are machine-local and deliberately **not** in the repository.

---

## 3. Build

```sh
mkdir -p build/android
godot --headless --export-debug "Android" build/android/crimson-vespers.apk
```

The preset lives in `export_presets.cfg`, which *is* tracked — it is the build
definition and holds no secrets.

## 4. Verify

```sh
python3 tools/ci/verify_apk.py build/android/crimson-vespers.apk
```

This checks the signature scheme, decodes the binary `AndroidManifest.xml` to
assert package name, version, SDK range and screen orientation, confirms every
declared ABI carries the engine library, confirms the game's own data actually
shipped, and checks the size budget. It exits non-zero on any failure.

## 5. Install

```sh
adb install -r build/android/crimson-vespers.apk
```

Or copy the APK to the device and open it, with "install from unknown sources"
enabled.

---

## 6. Release builds

`--export-release` needs a real keystore, which must **not** be committed:

```sh
keytool -genkeypair -v -keystore ~/crimson-vespers-release.keystore \
  -storepass "$PASS" -keypass "$PASS" -alias crimsonvespers \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Crimson Vespers,O=...,C=..."

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=~/crimson-vespers-release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=crimsonvespers
export GODOT_ANDROID_KEYSTORE_RELEASE_PASS="$PASS"
godot --headless --export-release "Android" build/android/crimson-vespers-release.apk
```

Godot reads those environment variables so the credentials never touch
`export_presets.cfg`.

**Keep that keystore and back it up.** Android identifies an app by its signing
key: lose it and you can never ship an update to anyone who installed the old
build — they would have to uninstall first, losing their save.

A release build also drops `android.permission.DUMP`, which the debug template
adds for debugging. It is the only permission this game requests; there is no
network, storage, camera or location access.

---

## 7. Things that will waste your afternoon

Each of these actually happened while getting the first APK out.

**The export fails with a completely empty error message.** Godot's Android
validation contains one check that sets its failure flag without appending any
text:

```cpp
if (!ResourceImporterTextureSettings::should_import_etc2_astc()) {
    valid = false;   // no err += anything
}
```

The fix is `rendering/textures/vram_compression/import_etc2_astc=true` in
`project.godot`. This does *not* compress the pixel art — it only makes ETC2/ASTC
available to textures whose import mode asks for VRAM compression, and every
texture in this project imports at `compress/mode=0` (Lossless). A test in
`tests/unit/core/mobile_config_test.gd` keeps the setting on.

**`display/window/handheld/orientation` is an enum, and the value that reads like
"yes" is the wrong one.** `SCREEN_LANDSCAPE` is `0` and `SCREEN_PORTRAIT` is `1`.
This project shipped `1` for its entire history — a landscape-only game with a
16:9 viewport and a two-thumb touch layout, set to portrait. Desktop ignores the
setting completely, so every screenshot and every test looked correct. It is now
`4` (`SCREEN_SENSOR_LANDSCAPE` → Android `sensorLandscape`), asserted by a test
and re-checked against the built manifest by `verify_apk.py`.

**`FileAccess.file_exists("res://.../hero.png")` is false in every exported
build.** Godot ships the *imported* form — `.godot/imported/hero.png-<hash>.ctex`
— and never the source PNG. The boot self-check used `FileAccess` and therefore
reported four missing textures on every launch of the APK while the game rendered
them perfectly. Imported resources must be checked with `ResourceLoader.exists`.
Only files Godot ships verbatim, such as our JSON, belong in a `FileAccess`
check. The editor cannot reproduce this failure, because in the editor the source
PNG really is on disk.

**`grep` finds nothing useful in `AndroidManifest.xml`.** It is compiled to
binary AXML inside the APK. `tools/ci/verify_apk.py` contains a decoder.

---

## 8. What a green verify does *not* prove

`verify_apk.py` proves the APK is well-formed, correctly signed, correctly
configured and contains the game. It cannot prove the game runs. Not verified
without a physical device or emulator:

- rendering and framerate on a real GPU
- touch input against the on-screen controls
- audio playback
- save/load against real Android storage
- the 256 MB memory ceiling
- that it installs on a real arm64 or armv7 device

The closest available proxy is the exported **Linux** build (preset
`Linux Verify`), which runs the same packed, non-editor resources through the
same export pipeline:

```sh
godot --headless --export-debug "Linux Verify" build/linux/crimson-vespers.x86_64
xvfb-run -a ./build/linux/crimson-vespers.x86_64 --rendering-driver opengl3
```

A healthy run prints `Crimson Vespers 0.1.0 — boot checks passed.` That is how
the `FileAccess` bug above was found.
