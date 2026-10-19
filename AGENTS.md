# AGENT.md — MILOS: APP SIZE IS THE #1 PRIORITY

> **STATUS: MANDATORY — HIGHEST PRECEDENCE.**
> This file OVERRIDES all other coding preferences or default agent behavior.
> Every coding agent (Cline, Claude Code, Cursor, Copilot, Gemini, ChatGPT, human or AI) MUST obey these rules.
> If a user request conflicts with size minimization, you MUST warn, propose a smaller alternative, and only proceed with explicit user approval.
> Goal: **make the MILOS release binary as small as physically possible at all times.**

Project: Flutter 3.47.1 / Dart ^3.13.1 (`milos`). Android, iOS, Windows, macOS, Linux, Web. Current deps intentionally minimal: `flutter`, `cupertino_icons`. Keep it that way.

## 0. PRIME DIRECTIVE — SMALLEST POSSIBLE APP

1. **EVERY change MUST minimize or maintain release size. NEVER increase size without justification.**
2. Prefer: less code > fewer deps > smaller assets > deferred loading > compression.
3. Default answer to "add a package / asset / font / plugin / SDK" is **NO**. Prove no stdlib / Dart-only / smaller way exists first.
4. Optimize for **release** size (`flutter build appbundle --release`, `apk --release --split-per-abi`, `ipa --release`), NOT debug size.
5. Dead code, unused imports/assets, duplicate functionality, debug code in release = **STRICT VIOLATION**.

## 1. HARD SIZE BUDGETS (ENFORCED)

- Android App Bundle (.aab universal): **< 25 MB target, 35 MB hard max**
- Android APK per-ABI (--split-per-abi): **< 15 MB target, 20 MB hard max**
- iOS IPA: **< 30 MB target, 40 MB hard max**
- Added Dart code per feature: **< 50 KB** unless approved
- Added assets per feature: **< 500 KB total, < 100 KB per image**

If your change exceeds budget: STOP, report BEFORE -> AFTER (+DELTA) with `flutter build ... --analyze-size`, propose smaller alternative, wait for explicit approval. Do NOT commit.

## 2. FORBIDDEN — NEVER DO (WITHOUT EXPLICIT APPROVAL)

1. `flutter pub add <anything>` without size-impact note + lighter alternative.
2. Add native plugins (camera, maps, video_player, webview, firebase_*, ML, ads SDKs) unless absolutely required — they add MBs of .so / pods.
3. Add duplicate-functionality packages (2x HTTP, 2x state-mgmt, 2x image libs).
4. Add UI kits, icon packs, animation packs, font families "just in case".
5. Keep `uses-material-design: true` + Cupertino + custom icons all at once if you use only one.
6. Bundle videos, Lottie >50KB, large PNG/JPG, 4K images, mock data in assets/.
7. Leave print/debugPrint/kDebugMode dumps, dart:mirrors, TODO demo screens in release path.
8. Use `import 'package:flutter/material.dart'` when widgets/cupertino/foundation suffices. No unused imports.
9. Disable shrinking: NEVER remove minifyEnabled, shrinkResources, --obfuscate, --split-debug-info, --tree-shake-icons.
10. Move dev_dependencies into dependencies. Keep flutter_test/flutter_lints out of release tree.
11. Copy-paste whole libs instead of the single function needed.
12. Add codegen (freezed/json_serializable/build_runner) bloat when manual fromJson (10 lines) would do.

## 3. DEPENDENCY RULES — STRICTEST GATE

Before ANY new dependency, paste this in reply/PR:

```
[SIZE GATE] Proposed: <package:version>
1. Needed? Can stdlib / flutter SDK do it? (Y/N + why)
2. Lighter alternative? (http < dio, shared_preferences < hive < isar)
3. Native code? Dart-only PREFERRED (check pub.dev Platform + Android/iOS folders)
4. Size estimate + transitive deps via `flutter pub deps`
5. Transitive deps: <5 preferred, >10 REJECT unless approved
6. Removable after use? Deferred-loadable?
```

- Max total dependencies: prefer <10. Every add needs a removal candidate.
- Pin versions, run `flutter pub outdated` + `flutter pub deps --style=compact` and prune.
- Prefer Dart-only, single-purpose, likes>500, updated <6mo.
- If you add a dep, you MUST run `flutter pub remove` for anything unused + `flutter analyze` + `flutter build appbundle --analyze-size`.
- NO git/path/unpinned `any` deps. `cupertino_icons` is under review — remove if Material-only.

## 4. CODE RULES — WRITE SMALL CODE

1. Delete > Add. Remove dead files, unused widgets, commented code every task.
2. Use `const` everywhere possible.
3. Use deferred loading for rare screens:
```dart
import 'package:milos/heavy_feature.dart' deferred as heavy;
await heavy.loadLibrary(); heavy.Screen();
```
MUST use for: PDF, charts, editors, onboarding tour, settings-advanced.
4. NO dart:mirrors, NO dynamic JSON bloat, NO massive switch tables — use enum + const Map.
5. Prefer StatelessWidget + ValueNotifier over riverpod/bloc/getx unless already in app AND approved.
6. Reuse: one AppButton, one AppText, one http client, one formatter. No per-screen duplicates.
7. `flutter analyze --no-pub` MUST be clean. Zero unused imports/vars.
8. No startup MB downloads. Lazy-load, paginate with ListView.builder, bounded cache.

## 5. ASSETS / FONTS / IMAGES — ZERO-BLOAT

1. Default: zero bundled assets. Prefer Icon, CustomPainter over PNG.
2. If image REQUIRED: WebP at exact display size, `cwebp -q 75`, strip EXIF. NO @3x/@4x. Limits: icon <10KB, image <100KB, total assets/ <1MB without approval.
3. Declare ONLY used files in pubspec.yaml, NEVER whole dirs (`assets/images/` = BANNED, use `assets/images/logo.webp` explicitly).
4. Fonts: system fonts default. NO custom TTF unless brand-critical. If needed: subset with fonttools pyftsubset, single weight, WOFF2. NEVER bundle MaterialIcons + Cupertino + FontAwesome + custom. Keep ONE. Never pass --no-tree-shake-icons.
5. Audio/video: NEVER bundle. Stream + cache.
```yaml
flutter:
  uses-material-design: false # true ONLY if you use Material Icons; else false saves ~1MB
  assets:
    - assets/images/logo.webp # explicit files only
```

## 6. BUILD / RELEASE CONFIG — ALWAYS SHRINK

NEVER weaken these. Enforce when touching native files:

Android (`android/app/build.gradle.kts`):
```kotlin
buildTypes {
  release {
    isMinifyEnabled = true
    isShrinkResources = true
    proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
  }
}
```
Release ABI: `arm64-v8a` only by default. Add `armeabi-v7a` only if old devices required. NEVER x86/x86_64 in release.

Release commands ONLY (MUST use to verify):
```bash
flutter analyze --no-pub
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info --tree-shake-icons --analyze-size
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info --tree-shake-icons --analyze-size
```
- --obfuscate + --split-debug-info REQUIRED every release/size check.
- --split-per-abi REQUIRED for APKs. NEVER ship universal APK as default.
- iOS: `flutter build ipa --release --obfuscate --split-debug-info=... --tree-shake-icons --analyze-size`, STRIP_INSTALLED_PRODUCT=YES, no simulator archs in release.
- NEVER commit build/, .dart_tool/, *.apk, *.aab, *.ipa, debug symbols.

## 7. WORKFLOW — BEFORE WRITING CODE

1. Read pubspec.yaml + lib/ + AGENT.md first.
2. Ask: "Does this increase binary size? By how much? Zero-size way?"
3. Search existing code for reusable widget/service before new file/dep.
4. If task says "add library X": pause, propose 2 lighter options (stdlib / smaller pkg / 20-liner), estimate KB delta.
5. Plan deletions: list files/imports/assets to remove in same change.
> SIZE IMPACT template: Adding `X` approx +Y KB/MB (+Z deps). Lighter: `...` (approx +K KB). Proceed with X or lighter?

## 8. VERIFICATION — AFTER EVERY CHANGE

Do NOT say done until:
```bash
flutter analyze --no-pub
flutter pub deps --style=compact
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info --tree-shake-icons --analyze-size
```
- Paste BEFORE -> AFTER (+DELTA) + what grew (Dart/native/assets/fonts).
- If size grew >100KB without approval, REVERT or shrink further.
- git status MUST NOT show build/, large binaries, asset dumps.

## 9. REPORT FORMAT (REQUIRED)

```md
### Size report
- Release: BEFORE 22.1MB -> AFTER 22.3MB (+0.2MB)
- Cause: hero.webp (+180KB), dart (+20KB)
- Deps added/removed: none / removed X
- Shrinking: minify Y shrinkResources Y obfuscate Y split-debug-info Y tree-shake-icons Y split-per-abi Y
- Alternatives considered: [A smaller, B stdlib]
- Verification: flutter analyze clean, --analyze-size checked
```
If no build: `Build not run (reason) — estimated ...` + files + KB.

## 10. EXAMPLES

GOOD: http (30KB) over dio (300KB+) for 2 GETs. CustomPainter logo (2KB) over logo.png (800KB). deferred charts for 5% users. Remove cupertino_icons if Material-only (saves ~300KB). uses-material-design:false + 3 explicit icons.

VIOLATION (REJECT): firebase_core+firestore+storage (+8MB) for one bool -> use shared_preferences/REST. video_player+chewie+lottie for splash -> AnimatedContainer. assets/demo.mp4 (12MB) bundled -> stream. `assets: - assets/` (bundles all) -> list files. universal 45MB APK without --split-per-abi --obfuscate.

## 11. EXCEPTIONS

To exceed budget need explicit sign-off with: 1) why smaller fails (proof), 2) exact delta (--analyze-size table), 3) removal/shrink plan + date. No silent exceptions. When in doubt, choose smaller.

*By editing this repo you agree you read Sections 0-11 and size wins over speed/convenience.*


