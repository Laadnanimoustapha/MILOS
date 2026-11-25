# MILOS — Upcoming Features Plan

> **Prime directive:** Every feature must minimize or maintain release binary size.
> No new packages without SIZE GATE review. Zero dead code. All in Dart-only unless noted.

---

## Feature A — Task "Failed" State + Dashboard Integration

### A.1 — Add `failed` field to `Task` model
*File: `lib/task.dart`*

- Add `final bool failed;` field to `Task` (defaults `false`).
- Add `failed` to `copyWith()`, `toJson()`, `fromJson()`, `nextRecurrence()`.
- A task can only be `failed` **or** `done`, never both.
- `fromJson` reads `'failed': json['failed'] as bool? ?? false` — backwards compatible.

```dart
// In Task constructor
this.failed = false,

// In toJson (only write when true to save space)
if (failed) 'failed': failed,

// In fromJson
failed: json['failed'] as bool? ?? false,
```

**Size impact:** `+~0.1 KB` Dart compiled. No new packages.

---

### A.2 — Mark Task as Failed in UI
*File: `lib/main.dart`*

- In `_TaskTile` long-press menu (or task details sheet), add **"Mark as Failed"** option.
- Failed tasks show a red ❌ icon instead of the green checkmark ring.
- Failed tasks move out of the main list (like done tasks) into the **Archive**.
- In `archive_page.dart`: show failed tasks in a separate "Failed" section with a red left-border accent.

**Visual treatment:**
| State | Icon | Color |
|:------|:-----|:------|
| Pending | ○ ring | Teal `#4CAF9E` |
| Done | ✓ filled | Teal `#4CAF9E` |
| Failed | ✕ filled | Red `#E74C3C` |
| In Progress | ◑ half | Orange `#E67E22` |

**Size impact:** `+~0.3 KB` Dart. No new packages.

---

### A.3 — Failed Count in `TaskStore`
*File: `lib/task_store.dart`*

- No new storage key needed — `failed` field already on the task object in `milos.tasks.v1`.
- Expose a computed getter or static helper:
  ```dart
  static int countFailed(List<Task> tasks) =>
      tasks.where((t) => t.failed).length;
  static int countFailedToday(List<Task> tasks) =>
      tasks.where((t) => t.failed && _isToday(t.remindAt)).length;
  ```

**Size impact:** `~0 KB` (pure logic).

---

### A.4 — Dashboard Integration
*File: `lib/dashboard_page.dart`*

- In the **Today Overview** section, add a third stat tile alongside **Done** and **Pending**:
  - 🔴 **Failed** count (today)
- In the **Weekly Task Chart** (`CustomPainter`): add a red segment on each day's bar for failed tasks (stacked bar: green = done, red = failed, grey = remaining).
- Weekly summary text: *"This week: X done, Y failed, Z pending."*
- Pass `failedCount` to the AI Analysis prompt so Milos can comment on failure patterns.

**Changes:** Extend `_loadData()` to compute today's and weekly failed counts. All `CustomPainter` — zero packages.

**Size impact:** `+~0.4 KB` Dart. No new packages.

---

### A.5 — Streak Interaction
*File: `lib/streak_store.dart`*

- If ANY task today is marked `failed`, the streak is **not broken** (failure ≠ no effort).
- Only if zero tasks were attempted today (all skipped, no done and no failed) does the streak reset.
- Document this logic clearly in `StreakStore`.

---

## Feature B — Prayer Count History ("How many times each prayer was prayed")

### B.1 — Extend Prayer Storage to Count Sessions
*File: `lib/habit_store.dart`*

Currently prayers are stored per-day as `bool` (prayed / not prayed).
Extend the per-day prayer record from `bool` to `int` (count of times prayed that day).

**New storage format** (backwards compatible):
```json
// OLD (bool)
{ "Fajr": true, "Dhuhr": false, ... }

// NEW (int — number of times prayed; 0 = not prayed)
{ "Fajr": 2, "Dhuhr": 1, "Asr": 0, "Maghrib": 1, "Isha": 1 }
```

**Migration strategy** (in `loadPrayers`): if value is `bool`, read it as `1` (true) or `0` (false). No data loss.

**New API additions:**
```dart
// Load prayer COUNTS (not bool) for a date
static Future<Map<String, int>> loadPrayerCounts([String? dateKey]) async { ... }

// Increment count for a specific prayer
static Future<void> incrementPrayer(String prayer, [String? dateKey]) async { ... }

// Decrement (in case of accidental tap) — floor at 0
static Future<void> decrementPrayer(String prayer, [String? dateKey]) async { ... }

// Convenience bool: has user prayed at least once?
static Future<Map<String, bool>> loadPrayers([String? dateKey]) async { ... } // keep same signature
```

**Keep existing `togglePrayer` for backward compat** — it now increments/decrements instead of toggling.

**Size impact:** `+~0.4 KB` Dart. No new packages. No new SharedPreferences keys (same key structure, different value format).

---

### B.2 — Prayer Count UI in `habits_page.dart`
*File: `lib/habits_page.dart`*

- Replace the single ✓/✗ checkbox per prayer with a **counter row**:
  ```
  [−]  Fajr · الفجر   ×2  [+]
  ```
- Tapping `[+]` calls `incrementPrayer`. Tapping `[−]` calls `decrementPrayer`.
- When count ≥ 1, the row gets a teal fill. When count = 0, grey. When count ≥ 2, show a small amber badge `×N` to indicate extra prayers (e.g. making up missed ones).
- Keep the prayer streak working: streak = consecutive days with count ≥ 1 for all 5 prayers.

**Size impact:** `+~0.3 KB` Dart. No new packages.

---

### B.3 — Prayer History View (last 30 days)
*File: `lib/habits_page.dart`* (or expandable card in habits page)

- A "History" expand/collapse section under the prayers card.
- Shows last 7 days as a mini calendar grid:
  - Each cell: day label + count dots per prayer.
  - Pure `CustomPainter` or `GridView` with `Container` widgets.
- Tapping a cell shows that day's full prayer counts in a bottom sheet.

**Size impact:** `+~0.5 KB` Dart. No new packages.

---

### B.4 — Prayer Stats in Dashboard
*File: `lib/dashboard_page.dart`*

- Add a **"Prayers This Week"** section to the Dashboard.
- For each prayer (Fajr → Isha): show total count this week (sum of daily counts).
- Bar chart row: `CustomPainter` horizontal bars, one per prayer, colored teal, length proportional to count vs. 7 (expected daily = 7 for the week).
- If any prayer total > 7: show amber `+N` to reflect extra voluntary prayers.

**Size impact:** `+~0.4 KB` Dart. No new packages.

---

## Feature C — Self-Update via GitHub Releases (OTA)

> [!IMPORTANT]
> This feature requires the user to set up a GitHub repository with Actions enabled and a Personal Access Token (PAT) with `contents: write` permission stored as a repository secret named `GH_TOKEN`. No new pub.dev packages are added — HTTP is done via `dart:io` / `dart:convert` which are already in the Flutter SDK.

---

### C.1 — GitHub Actions Workflow (Build & Release APK)
*New file: `.github/workflows/release.yml`*

**Trigger:** Manual (`workflow_dispatch`) only — you trigger it; the app never pushes to GitHub.

**What it does:**
1. Checks out repo.
2. Sets up Flutter `3.47.1`.
3. Reads current version from `pubspec.yaml` (e.g. `1.0.0+1`).
4. Bumps patch version automatically: `1.0.0` → `1.0.1`, `1.0.1` → `1.0.2`, etc.
5. Writes bumped version back to `pubspec.yaml` and commits + tags `v1.0.1`.
6. Builds:
   ```bash
   flutter build apk --release --split-per-abi \
     --obfuscate --split-debug-info=build/debug-info \
     --tree-shake-icons --analyze-size
   ```
7. Creates a GitHub Release tagged `v1.x.x` with:
   - `app-arm64-v8a-release.apk` (primary)
   - `app-armeabi-v7a-release.apk` (legacy)
   - Auto-generated release notes (commit messages since last tag).
8. Pushes the version bump commit + tag back to `main`.

**Version naming:** `v1.MINOR.PATCH` — minor bumped for significant features, patch for fixes. The workflow auto-bumps patch; you manually bump minor in `pubspec.yaml` for big releases.

```yaml
name: Build & Release APK
on:
  workflow_dispatch:
    inputs:
      bump:
        description: 'Version bump type'
        required: true
        default: 'patch'
        type: choice
        options: [patch, minor]
      release_notes:
        description: 'Release notes (optional)'
        required: false
        default: ''

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.GH_TOKEN }}
          fetch-depth: 0

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.47.1'
          channel: 'stable'
          cache: true

      - name: Bump version & tag
        id: version
        run: |
          # Read current version from pubspec.yaml
          VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
          BUILD=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f2)
          IFS='.' read -r MAJ MIN PAT <<< "$VERSION"
          if [ "${{ inputs.bump }}" = "minor" ]; then
            MIN=$((MIN+1)); PAT=0
          else
            PAT=$((PAT+1))
          fi
          NEW_VER="$MAJ.$MIN.$PAT"
          NEW_BUILD=$((BUILD+1))
          sed -i "s/^version: .*/version: $NEW_VER+$NEW_BUILD/" pubspec.yaml
          echo "NEW_VERSION=$NEW_VER" >> $GITHUB_OUTPUT
          echo "TAG=v$NEW_VER" >> $GITHUB_OUTPUT

      - name: Build APK
        run: |
          flutter pub get
          flutter build apk --release --split-per-abi \
            --obfuscate --split-debug-info=build/debug-info \
            --tree-shake-icons

      - name: Commit version bump & push tag
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add pubspec.yaml
          git commit -m "chore: bump version to ${{ steps.version.outputs.NEW_VERSION }}"
          git tag ${{ steps.version.outputs.TAG }}
          git push origin main --follow-tags

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ steps.version.outputs.TAG }}
          name: "MILOS ${{ steps.version.outputs.TAG }}"
          body: ${{ inputs.release_notes }}
          generate_release_notes: true
          files: |
            build/app/outputs/apk/release/app-arm64-v8a-release.apk
            build/app/outputs/apk/release/app-armeabi-v7a-release.apk
        env:
          GITHUB_TOKEN: ${{ secrets.GH_TOKEN }}
```

**SIZE GATE:** No new pub.dev packages. GitHub Actions runs on GitHub's servers — zero app size impact.

---

### C.2 — In-App Update Checker (Dart-only, no packages)
*New file: `lib/update_service.dart`*

Uses `dart:io` (`HttpClient`) and `dart:convert` (`jsonDecode`) — both already in the Flutter/Dart SDK, zero new packages.

```dart
import 'dart:convert';
import 'dart:io';

class UpdateService {
  // ← Replace with your actual GitHub repo
  static const _owner = 'YOUR_GITHUB_USERNAME';
  static const _repo  = 'milos';
  static const _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// Returns null when already up to date or on error.
  static Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final req = await client.getUrl(Uri.parse(_apiUrl));
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('User-Agent', 'milos-app');
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      client.close();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?)?.replaceFirst('v', '') ?? '';
      if (tag.isEmpty || tag == currentVersion) return null;
      // Find arm64 APK download URL
      final assets = (json['assets'] as List<dynamic>?) ?? [];
      final arm64 = assets.firstWhere(
        (a) => (a['name'] as String).contains('arm64-v8a'),
        orElse: () => null,
      );
      return UpdateInfo(
        version: tag,
        downloadUrl: arm64?['browser_download_url'] as String? ?? '',
        releaseNotes: json['body'] as String? ?? '',
      );
    } catch (_) {
      return null;  // Silent fail — never crash for update check
    }
  }
}

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
  });
  final String version;
  final String downloadUrl;
  final String releaseNotes;
}
```

**SIZE GATE:** No new packages. `dart:io` + `dart:convert` are already compiled into every Flutter app — zero binary delta for imports.

---

### C.3 — Periodic Background Check
*File: `lib/main.dart`*

- On app start (in `initState` of the root widget), check for updates **once per day** using `SharedPreferences`:
  ```dart
  static const _keyLastUpdateCheck = 'milos.update.last_check';
  ```
- If last check was ≥ 24 hours ago: call `UpdateService.checkForUpdate(currentVersion)`.
- If an update is found: show a non-intrusive **banner** (or `SnackBar`) at the bottom of the screen:
  *"MILOS v1.2.0 is available → Settings"*
- Tapping the banner navigates to the Settings page.
- Current app version is read from `pubspec.yaml` at build time via a Dart `const`:
  ```dart
  // In build.gradle or via --dart-define at build time
  // Simple approach: hardcode in a constants file, updated by CI
  const kAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  ```
  Or read from `package_info_plus` — but to stay zero-dependency, prefer `--dart-define=APP_VERSION=$NEW_VER` in the build command (the workflow injects it).

**Add to build command in workflow:**
```bash
flutter build apk --release ... --dart-define=APP_VERSION=${{ steps.version.outputs.NEW_VERSION }}
```

**SharedPreferences key added:** `milos.update.last_check` (1 new key — well within budget).

**SIZE GATE:** No new packages. +~0.5 KB Dart compiled. Total ≈ same as before.

---

### C.4 — Settings Page Update Button
*File: `lib/main.dart`* (Settings page / section)

In the existing Settings page, add an **"Check for Updates"** section:

```
┌─────────────────────────────────────────┐
│ App                                      │
│ Current version: v1.0.0                  │
│                                          │
│  [Check for Updates]  ← teal button      │
│                                          │
│ ✓ Up to date   /  ⬇ v1.2.0 available   │
│   [Open Download Page]  ← opens browser  │
└─────────────────────────────────────────┘
```

- **"Check for Updates"** button: calls `UpdateService.checkForUpdate()` on demand; shows a `CircularProgressIndicator` while loading.
- Result shown inline: "Up to date ✓" or "v1.x.x available — tap to download".
- **"Open Download Page"** link: opens the GitHub Releases page in the system browser using `dart:io` `Process.run(['am', 'start', ...])` on Android — or simpler: a plain `Text` with the URL the user can copy.

> [!NOTE]
> The app does **not** auto-install the APK — it directs the user to the download URL. Auto-install would require `REQUEST_INSTALL_PACKAGES` permission which adds complexity and app store friction. The user taps the link, downloads, and installs manually (or via browser). This is intentional.

**SIZE GATE:** No new packages (avoid `url_launcher` — it adds ~200KB native code). Instead show the URL in a selectable `Text` widget or use `dart:io` on Android to fire an Intent via `Process.run`.

---

## Shared Preferences Budget

| New key | Feature | Type |
|:--------|:--------|:-----|
| `milos.update.last_check` | C.3 Periodic check | String (ISO date) |
| (none new — prayers reuse existing key with new int format) | B.1 | — |
| (task `failed` field stored inside existing `milos.tasks.v1`) | A.1 | — |

**Total new keys: 1** — well within the ≤15 budget.

---

## Implementation Order (Suggested)

```
Phase 9  → Feature A (Task Failed state + Dashboard)
Phase 10 → Feature B (Prayer counts + history)
Phase 11 → Feature C (GitHub workflow first, then in-app checker)
```

---

## Verification Checklist (All Features)

```bash
flutter analyze --no-pub          # Must be clean
flutter pub deps --style=compact  # No new packages
flutter build appbundle --release --obfuscate \
  --split-debug-info=build/debug-info \
  --tree-shake-icons --analyze-size
# BEFORE -> AFTER delta must be < +100KB without approval
```

### Expected Size Report
```
Feature A (task failed):   +~0.4 KB Dart  | 0 new packages | 0 new assets
Feature B (prayer counts): +~0.8 KB Dart  | 0 new packages | 0 new assets
Feature C (self-update):   +~0.6 KB Dart  | 0 new packages | 0 new assets
─────────────────────────────────────────────────────────────────────────
TOTAL estimated delta:     +~1.8 KB Dart  | 0 new packages | 1 new pref key
```

*All compiled Dart deltas are estimates at ~100 Dart loc per feature. Actual binary delta measured with `--analyze-size` after implementation.*
