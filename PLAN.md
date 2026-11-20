# MILOS — Implementation Plan

> **Prime directive:** Every feature must minimize or maintain release binary size. No new packages without a SIZE GATE review. Zero dead code.

---

## Architecture & Size Budget (All Phases)

| Item | Budget |
| :--- | :--- |
| New packages | **0** |
| New asset files | **0** |
| New `SharedPreferences` keys | ≤ 15 |
| Estimated Dart code delta | **< 15 KB** total compiled |

---

## Phase 1 — True "Today" Isolation & Dynamic Context
*Files: `lib/main.dart`*

- [ ] **1.1 Dynamic Time-Aware Greeting**
  - Replace hardcoded `'Good morning,'` (line 603) with a helper evaluating `DateTime.now().hour`:
    - 05–11 → "Good morning," / "صباح الخير،"
    - 12–16 → "Good afternoon," / "مساء الخير،"
    - 17–21 → "Good evening," / "مساء النور،"
    - 22–04 → "Rest well," / "تصبح على خير،"

- [ ] **1.2 Isolate Progress Ring to Today's Tasks**
  - Filter `_completed` and `_total` to only include tasks where `_isToday(t.remindAt)`.
  - Future and overdue tasks must not drag down today's ring.

- [ ] **1.3 Smart Contextual Subtext Under Header**
  - 0 tasks → *"No tasks today. Enjoy your day."*
  - Remaining > 0 → *"X tasks remaining."*
  - All done → *"All done! Outstanding."*

---

## Phase 2 — Daily Streak & Weekly Consistency
*Files: `lib/main.dart`, new `lib/streak_store.dart`*

- [ ] **2.1 Lightweight StreakStore**
  - `SharedPreferences` keys: `milos.streak.count` (int), `milos.streak.last_date` (string YYYY-MM-DD).
  - Increment when all today's tasks (≥ 1) are marked done.
  - Reset to 1 if previous `last_date` was not yesterday.

- [ ] **2.2 Streak Flame Badge in Header**
  - `🔥 X days` badge in progress panel using warm orange `#E67E22`.

- [ ] **2.3 7-Day Consistency Dots (Mon – Sun)**
  - Row of 7 small `Container` widgets under the progress ring:
    - Solid teal = fully completed day.
    - Teal ring = in progress (today).
    - Light gray = rest / missed day.
  - History stored as `milos.week.YYYY-Www` JSON string.

---

## Phase 3 — Day Flow, Focus & Clean Workspace
*Files: `lib/main.dart`*

- [ ] **3.1 "Focus Next" Active Task Highlight**
  - Detect earliest pending task for today (or current `inProgress` task).
  - Render a subtle left-border teal accent or "Now" badge.

- [ ] **3.2 Done Tasks Disappear from Main Screen → Archive**
  - When a task is marked done it immediately disappears from the main list.
  - A new **Archive screen** (or collapsible "Completed" drawer at bottom of main page) holds all done tasks, browsable and deletable.
  - `SharedPreferences` key: existing `milos.tasks.v1` already stores them. Just filter the display.

- [ ] **3.3 One-Tap Overdue Rollover ("Move to Today")**
  - Button on the "Overdue" section header.
  - Updates all overdue tasks' `remindAt` / `remindUntil` to today, reschedules notifications.

---

## Phase 4 — Notification Action Buttons (Bug Fix)
*Files: `lib/reminder_service.dart`*

- [ ] **4.1 Fix "Done" Action Button in Notification**
  - `notificationActionBackground` already calls `_markTaskDone`.
  - Verify `TaskStore.save()` path is accessible from the background isolate.
  - After marking done: cancel **all** notifications for that task ID (not just the tapped one) using `_plugin.cancel(id)` for all `task.id * 100 + index` IDs.

- [ ] **4.2 Fix "Wait 15 min" Action Button**
  - `_snoozeTask` calls `_scheduleSnooze`. Confirm the background isolate properly re-initialises the plugin before scheduling.
  - After snooze scheduled: dismiss the original notification using `_plugin.cancel(notificationId)`.

- [ ] **4.3 Fix "I started doing it" Action Button**
  - After `_startTask` saves state: cancel all intermediate reminder notifications for the task, leave only the final "Have you finished?" notification.

- [ ] **4.4 Clear All Related Notifications on Any Action**
  - Helper function `_cancelAllForTask(int taskId)` that cancels IDs `taskId * 100 + 0` through `taskId * 100 + 59` and snooze ID `900000 + taskId`.

---

## Phase 5 — Keyboard Bug Fixes
*Files: `lib/main.dart` (inside `_AddTaskSheetState`)*

- [ ] **5.1 Keyboard Should Not Auto-Open on Sheet Open**
  - The title `TextField` likely has `autofocus: true`. Set it to `false`.
  - Add a slight delay before focusing if desired (`Future.delayed(300ms, () => _titleFocus.requestFocus())`).

- [ ] **5.2 Keyboard Re-Opens After Closing Time Picker**
  - After `showTimePicker()` resolves, explicitly hide keyboard with `FocusManager.instance.primaryFocus?.unfocus()` before updating state.

---

## Phase 6 — Lifestyle Habits Page
*New file: `lib/habits_page.dart`, new `lib/habit_store.dart`*

- [ ] **6.1 Habit Data Model**
  - `Habit { id, name, type (boolean | counter | prayer_times), streak, lastDoneDate, history }`.
  - Stored in `shared_preferences` as JSON: `milos.habits.v1`.

- [ ] **6.2 Habit Types Supported**
  - **Boolean habit:** No smoking, early sleep, exercise — tap once to record for today.
  - **Prayer tracker:** 5 slots (Fajr, Dhuhr, Asr, Maghrib, Isha) — check each off individually.
  - **Counter habit:** Drink water (8 glasses), read (30 pages) — tap + / − to increment.
  - **Note / Journal:** A free-text daily note (1 per day, stored efficiently).

- [ ] **6.3 Habits Page UI**
  - Minimal card-based layout matching MILOS design system (white cards, teal accents, `#F5F8F7` background).
  - Each card shows: habit name, today's status, streak badge.
  - "Add Habit" bottom sheet (name, type selector, optional reminder).

- [ ] **6.4 Habit Streaks**
  - Each habit has its own streak counter using same logic as `StreakStore`.

---

## Phase 7 — Dashboard & Progress Page
*New file: `lib/dashboard_page.dart`*

- [ ] **7.1 Dashboard Route**
  - Add a navigation tab or dedicated page accessible from the main screen.
  - Sections: Today overview, weekly task chart (pure `CustomPainter` bar chart — no chart library), habits summary, learning skills progress.

- [ ] **7.2 Weekly Task Chart (Pure CustomPainter)**
  - 7-bar chart drawn with `Canvas.drawRect` — zero packages, ~1 KB of Dart code.
  - Shows tasks completed per day for the current week.

- [ ] **7.3 AI Progress Analysis Button**
  - A teal "Analyse with Milos" button in the Dashboard.
  - Collects: tasks completed this week, overdue count, habit streaks, learning progress %.
  - Passes a structured summary string to Milos AI (`ai_chat_page.dart` or new bottom sheet).
  - Milos responds as a professional life coach: highlights strengths, flags problems, gives 2–3 action tips.

---

## Phase 8 — Learning Skill Task Type
*Files: `lib/task.dart`, `lib/main.dart`, `lib/dashboard_page.dart`*

- [ ] **8.1 New Task Category: `TaskCategory` enum**
  - `task`, `habit`, `learning` — add to `Task` model (backwards compatible, defaults to `task`).

- [ ] **8.2 Learning Task Fields**
  - Add `skillName`, `targetHours` (optional), `loggedMinutes` (cumulative).
  - Each time the task is marked done a session is recorded (duration = `remindUntil - remindAt`).

- [ ] **8.3 Learning Progress Display**
  - In `_TaskTile` for learning tasks: show a small horizontal progress bar under the title.
  - In Dashboard: aggregate all learning tasks into a *"Skills"* section with per-skill progress rings.

- [ ] **8.4 AI Skill Coaching**
  - When analysing from Dashboard, Milos comments on each active skill (progress rate, projected completion, encouragement or gentle push).

---

## Verification Checklist (Before Closing Any Phase)

```
flutter analyze --no-pub          → No issues
flutter pub deps --style=compact  → No new packages
git status                        → No unintended files
```
