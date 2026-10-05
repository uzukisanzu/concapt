# Releasing

`tool/package.ps1` builds both packages into `dist/` (gitignored):

| Package | File | Install |
|---|---|---|
| Android | `concapt-<version>.apk` | Sideload; allow installs from the source app |
| Windows | `concapt-<version>-windows-x64.zip` | Unzip anywhere, run `concapt.exe` |

## One-time setup: Android signing key

Every release must be signed with the same key, or phones refuse the update. Create the key once, then back up the keystore and its password outside the repo. Losing either means users must uninstall to update, which deletes their sessions.

```
keytool -genkeypair -v -keystore android/app/concapt-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias concapt
```

Then create `android/key.properties`:

```
storeFile=app/concapt-release.jks
storePassword=<password>
keyAlias=concapt
keyPassword=<password>
```

`storeFile` resolves against `android/`. Git ignores both files. Without `key.properties`, release builds fall back to the debug key, and the package script refuses to build the APK.

## One-time setup: GitHub secrets

`.github/workflows/release.yml` signs the APK with the same key, restored from four repository secrets. Run this from the repo root after `gh auth login`:

```powershell
$p = Get-Content android/key.properties | ConvertFrom-StringData
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android/app/concapt-release.jks")) | gh secret set ANDROID_KEYSTORE_BASE64
$p.storePassword | gh secret set ANDROID_STORE_PASSWORD
$p.keyAlias | gh secret set ANDROID_KEY_ALIAS
$p.keyPassword | gh secret set ANDROID_KEY_PASSWORD
```

## Each release

1. Bump `version` in `pubspec.yaml`. The part after `+` is Android's `versionCode` and must increase every release.
2. `flutter analyze` and `flutter test` pass, and `docs/manual-test-checklist.md` passes on a phone and on Windows.
3. Commit, then tag and push: `git tag v<version>` and `git push origin master v<version>`. The tag must match `pubspec.yaml`, or the workflow stops.
4. The workflow runs the checks, builds both packages with `tool/package.ps1`, and publishes a GitHub Release with generated notes.
5. Install the APK over the previous release to confirm the signature matches, and run the unzipped Windows build on a machine without the repo.

To build without releasing, run the workflow by hand from the Actions tab, which leaves the packages as artifacts. To build locally, run `powershell -ExecutionPolicy Bypass -File tool/package.ps1` (or `-Android` / `-Windows` for one).

## Notes

- The zip bundles the MSVC runtime DLLs from `System32`, so users don't need the Visual C++ redistributable.
- The Windows build isn't code-signed, so SmartScreen warns on first run ("More info" → "Run anyway").
- The APK is universal (arm64, armv7, x86_64), about 85 MB. `flutter build apk --split-per-abi` gives one APK per ABI at about a third of the size.
