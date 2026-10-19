# MILOS — Today page design

## Design intent

A calm, tactile home for one person's daily tasks. The page should feel like a fresh sheet of paper: quiet enough for focus, warm enough to invite a small next step. Keep it mobile-first, legible, and useful without implying that unfinished app sections exist.

## Visual system

- **Canvas:** cool near-white `#F5F8F7` gives the white header and task surfaces gentle separation.
- **Primary surface:** white `#FFFFFF` for the curved title header and task/progress surfaces.
- **Primary accent:** teal `#4CAF9E` for task completion, progress, and the add-task action.
- **Secondary accent:** sky `#A3DAF5` in small markers and supportive details only.
- **Text:** deep ink `#253533` for headings and task names; muted gray-green `#82908D` for date, time, and helper copy.
- **Typography:** system sans-serif, bold display title, compact uppercase metadata, and plain readable task labels. No bundled fonts.
- **Shape and spacing:** soft 16–20 px corners on working surfaces, light borders, generous breathing room. Use a shallow custom U-shaped dip in the white header as the page's memorable silhouette.

## Page structure

1. **Top greeting:** today's date, short greeting, and a small sun mark.
2. **Curved title header:** a compact white panel whose lower edge flows down into a broad centered valley; “Today” sits above the dip with a brief encouraging line. The header is part of the page scroll, so it moves out of view as tasks are browsed.
3. **Daily progress:** a compact circular completion indicator, count, and short supportive sentence. Start at 0% with no tasks; derive the ring and count from locally stored tasks the user creates and completes.
4. **Task list:** start empty and invite the user to add their first task. Each row has a completion circle, title, category, date, and reminder window. Completed work is crossed out and muted.
5. **Add task:** a teal floating action opens a rounded entry sheet with a task name, date picker, reminder start and end times, and an hourly repeat note. Persist tasks on-device and schedule local notifications on Android and iOS.
6. **Empty state:** when no tasks remain, replace the list with a clear, encouraging note.

## Interaction notes

- Check circles update completion and the progress summary immediately. The circle is completed tasks divided by all tasks created; with no tasks it remains at 0%.
- New task entry accepts a title, date, and same-day reminder window. It schedules a notification at the start and repeats hourly through the selected end time.
- Task details and completion state are stored locally on the device. Completing a task cancels its remaining reminders.
- Keep the home page as the only destination; omit bottom navigation until there are real additional screens.

## Size constraints

Use Flutter SDK widgets and a small `CustomClipper`. Use local notifications and device timezone support with no remote services. Avoid external fonts and bundled image assets. Use Material icons already available through the existing Material configuration.
