import 'package:flutter/material.dart';

import 'reminder_service.dart';
import 'task.dart';
import 'task_store.dart';

const _teal = Color(0xFF4CAF9E);
const _ink = Color(0xFF253533);
const _muted = Color(0xFF82908D);
const _paper = Color(0xFFF5F8F7);
const _importanceLabels = {
  TaskImportance.normal: 'NORMAL',
  TaskImportance.necessary: 'NECESSARY',
  TaskImportance.superNecessary: 'SUPER NECESSARY',
};
const _importanceColors = {
  TaskImportance.normal: _teal,
  TaskImportance.necessary: Color(0xFF3988A0),
  TaskImportance.superNecessary: Color(0xFFC36E36),
};
const _superReminderIntervals = [5, 10, 15, 30, 60];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ReminderService.instance.initialize();
  } catch (_) {
    // The task list remains available if device notifications are unavailable.
  }
  runApp(const MilosApp());
}

class MilosApp extends StatelessWidget {
  const MilosApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Milos',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _paper,
      colorScheme: ColorScheme.fromSeed(seedColor: _teal),
      fontFamily: 'Roboto',
    ),
    home: const TodayPage(),
  );
}

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final _store = TaskStore();
  final List<Task> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      _tasks.addAll(await _store.load());
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveTasks() async {
    try { await _store.save(_tasks); } catch (_) {}
  }

  int get _completed => _tasks.where((task) => task.done).length;

  String get _todayLabel {
    final now = DateTime.now();
    const weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    const months = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  Future<void> _addTask() async {
    final draft = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddTaskSheet(),
    );
    if (draft == null) return;

    final task = Task(
      id: _tasks.isEmpty ? 1 : _tasks.last.id + 1,
      title: draft.title,
      remindAt: draft.remindAt,
      remindUntil: draft.remindUntil,
      importance: draft.importance,
      superReminderIntervalMinutes: draft.superReminderIntervalMinutes,
    );
    try {
      if (await ReminderService.instance.requestPermission()) {
        await ReminderService.instance.schedule(task);
      }
    } catch (_) {}

    setState(() => _tasks.add(task));
    await _saveTasks();
  }

  Future<void> _toggleTask(Task task, bool? value) async {
    final updated = task.copyWith(done: value ?? false);
    setState(() => _tasks[_tasks.indexOf(task)] = updated);
    try {
      if (updated.done) {
        await ReminderService.instance.cancel(updated);
      } else if (updated.remindUntil.isAfter(DateTime.now())) {
        await ReminderService.instance.schedule(updated);
      }
    } catch (_) {}
    await _saveTasks();
  }

  Future<void> _remindTomorrow(Task task) async {
    DateTime tomorrowAt(DateTime value) => DateTime(
      value.year,
      value.month,
      value.day + 1,
      value.hour,
      value.minute,
    );

    final updated = task.copyWith(
      remindAt: tomorrowAt(task.remindAt),
      remindUntil: tomorrowAt(task.remindUntil),
    );
    try {
      await ReminderService.instance.cancel(task);
      await ReminderService.instance.schedule(updated);
    } catch (_) {}
    setState(() => _tasks[_tasks.indexOf(task)] = updated);
    await _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _tasks.isEmpty ? 0.0 : _completed / _tasks.length;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTask,
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New task', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(children: [
          SizedBox(
            height: 174,
            width: double.infinity,
            child: ClipPath(
              clipper: _NotchClipper(),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Column(children: [
                  const SizedBox(height: 12),
                  Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_todayLabel, style: const TextStyle(fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: _muted)),
                      SizedBox(height: 5),
                      Text('Good morning,', style: TextStyle(fontSize: 15, color: _ink)),
                    ]),
                  ]),
                  const Spacer(),
                  const Text('Today', style: TextStyle(fontSize: 40, height: 1, letterSpacing: -1.6, fontWeight: FontWeight.w800, color: _ink)),
                  const SizedBox(height: 8),
                  const Text('A fresh page, at your own pace.', style: TextStyle(fontSize: 13, color: _muted)),
                  const SizedBox(height: 22),
                ]),
              ),
            ),
          ),
          Padding(
                padding: const EdgeInsets.fromLTRB(22, 3, 22, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _ProgressPanel(completed: _completed, total: _tasks.length, progress: progress),
                      const SizedBox(height: 25),
                      Row(children: [
                        const Text('Your tasks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.4, color: _ink)),
                        const SizedBox(width: 9),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFE8F5F2), borderRadius: BorderRadius.circular(20)), child: Text(_tasks.isEmpty ? 'Start fresh' : '${_tasks.length - _completed} left', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _teal))),
                        const Spacer(),
                        const Text('See all', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted)),
                      ]),
                      const SizedBox(height: 13),
                      if (_loading)
                        const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: _teal)))
                      else if (_tasks.isEmpty)
                        const _EmptyTasks()
                      else
                        ..._tasks.map((task) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TaskTile(
                            task: task,
                            onChanged: (value) => _toggleTask(task, value),
                            onRemindTomorrow: () => _remindTomorrow(task),
                          ),
                        )),
                      const SizedBox(height: 5),
                      const _GentleNote(),
                    ]),
                  ),
                ),
          ),
        ]),
        ),
      ),
    );
  }
}

class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet();

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _controller = TextEditingController();
  late DateTime _date;
  late TimeOfDay _from;
  late TimeOfDay _until;
  TaskImportance _importance = TaskImportance.normal;
  int _superReminderIntervalMinutes = 15;
  String? _error;

  @override
  void initState() {
    super.initState();
    final nextHour = DateTime.now().add(const Duration(hours: 1));
    _date = DateTime(nextHour.year, nextHour.month, nextHour.day);
    _from = TimeOfDay.fromDateTime(nextHour);
    final endHour = nextHour.hour + 3;
    _until = TimeOfDay(hour: endHour > 23 ? 23 : endHour, minute: 0);
    if (_until.hour == _from.hour) _until = const TimeOfDay(hour: 23, minute: 59);
  }

  DateTime _at(TimeOfDay time) => DateTime(
    _date.year,
    _date.month,
    _date.day,
    time.hour,
    time.minute,
  );

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _pickTime({required bool start}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: start ? _from : _until,
    );
    if (selected != null) {
      setState(() {
        if (start) {
          _from = selected;
        } else {
          _until = selected;
        }
        _error = null;
      });
    }
  }

  void _save() {
    final title = _controller.text.trim();
    final from = _at(_from);
    final until = _at(_until);
    if (title.isEmpty) {
      setState(() => _error = 'Give your task a name first.');
    } else if (!from.isAfter(DateTime.now())) {
      setState(() => _error = 'Choose a reminder time in the future.');
    } else if (!until.isAfter(from)) {
      setState(() => _error = 'The reminder end must be after its start.');
    } else {
      final intervalMinutes = switch (_importance) {
        TaskImportance.normal => 60,
        TaskImportance.necessary => 30,
        TaskImportance.superNecessary => _superReminderIntervalMinutes,
      };
      final windowMinutes = until.difference(from).inMinutes;
      final reminderCount =
          windowMinutes ~/ intervalMinutes +
          1 +
          (windowMinutes % intervalMinutes == 0 ? 0 : 1);
      if (reminderCount > 60) {
        setState(
          () => _error =
              'Choose a longer interval or a shorter reminder window (max 60 reminders).',
        );
        return;
      }
      Navigator.pop(
        context,
        Task(
          id: 0,
          title: title,
          remindAt: from,
          remindUntil: until,
          importance: _importance,
          superReminderIntervalMinutes: _superReminderIntervalMinutes,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .92,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCE5E2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Make time for it',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'A small nudge at the right time.',
                      style: TextStyle(fontSize: 13, color: _muted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FormLabel('TASK'),
                      const SizedBox(height: 7),
                      TextField(
                        controller: _controller,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'What would you like to do?',
                          filled: true,
                          fillColor: _paper,
                          prefixIcon: const Icon(Icons.edit_outlined, color: _teal),
                          contentPadding: const EdgeInsets.symmetric(vertical: 17),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _save(),
                      ),
                      const SizedBox(height: 20),
                      const _FormLabel('PRIORITY'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _paper,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            for (final priority in TaskImportance.values)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Material(
                                    color: _importance == priority
                                        ? const Color(0xFFDDF2ED)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => setState(
                                        () => _importance = priority,
                                      ),
                                      child: SizedBox(
                                        height: 48,
                                        child: Center(
                                          child: Text(
                                            switch (priority) {
                                              TaskImportance.normal => 'Normal',
                                              TaskImportance.necessary => 'Necessary',
                                              TaskImportance.superNecessary =>
                                                'Super\nnecessary',
                                            },
                                            maxLines: 2,
                                            overflow: TextOverflow.clip,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _importance == priority
                                                  ? _teal
                                                  : _muted,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_importance == TaskImportance.superNecessary) ...[
                        const SizedBox(height: 14),
                        const _FormLabel('REMIND ME EVERY'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 7,
                          children: [
                            for (final minutes in _superReminderIntervals)
                              ChoiceChip(
                                label: Text(minutes == 60 ? '1 hour' : '$minutes min'),
                                selected: _superReminderIntervalMinutes == minutes,
                                onSelected: (_) => setState(
                                  () => _superReminderIntervalMinutes = minutes,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      const _FormLabel('DATE'),
                      const SizedBox(height: 7),
                      _PickerButton(
                        icon: Icons.calendar_today_rounded,
                        title: MaterialLocalizations.of(context).formatMediumDate(_date),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 18),
                      const _FormLabel('REMINDER WINDOW'),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: _PickerButton(
                              icon: Icons.notifications_active_outlined,
                              title: _from.format(context),
                              subtitle: 'FROM',
                              onTap: () => _pickTime(start: true),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward_rounded, size: 17, color: _muted),
                          ),
                          Expanded(
                            child: _PickerButton(
                              icon: Icons.notifications_none_rounded,
                              title: _until.format(context),
                              subtitle: 'UNTIL',
                              onTap: () => _pickTime(start: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.repeat_rounded, size: 16, color: _teal),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              '${_intervalDescription()} · final reminder at ${_until.format(context)}',
                              style: const TextStyle(fontSize: 12, color: _muted),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFB54141), fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE9EFED))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create task'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  String _intervalDescription() => switch (_importance) {
    TaskImportance.normal => 'Every hour',
    TaskImportance.necessary => 'Every 30 minutes',
    TaskImportance.superNecessary =>
      'Every ${_superReminderIntervalMinutes == 60 ? 'hour' : '$_superReminderIntervalMinutes minutes'}',
  };
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 10,
      letterSpacing: 1.1,
      fontWeight: FontWeight.w800,
      color: _muted,
    ),
  );
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: _paper,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: _teal, size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 9,
                        letterSpacing: .8,
                        fontWeight: FontWeight.w800,
                        color: _muted,
                      ),
                    ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.completed, required this.total, required this.progress});
  final int completed;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE9EFED))),
    child: Row(children: [
      SizedBox(
        width: 54, height: 54,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(width: 50, height: 50, child: CircularProgressIndicator(value: progress, strokeWidth: 4, backgroundColor: const Color(0xFFEAF1EF), valueColor: const AlwaysStoppedAnimation<Color>(_teal))),
          Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _ink)),
        ]),
      ),
      const SizedBox(width: 15),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          total == 0 ? 'No tasks added yet' : '$completed of $total tasks complete',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
        ),
        const SizedBox(height: 4),
        Text(
          total == 0 ? 'Add a task to start your progress.' : 'Small steps still move you forward.',
          style: const TextStyle(fontSize: 11, color: _muted),
        ),
      ])),
      Container(width: 35, height: 35, decoration: BoxDecoration(color: const Color(0xFFEAF7FC), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.spa_outlined, size: 18, color: Color(0xFF65B8D8))),
    ]),
  );
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onChanged,
    required this.onRemindTomorrow,
  });
  final Task task;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onRemindTomorrow;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final reminderTime =
        '${localizations.formatShortDate(task.remindAt)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(task.remindAt))}'
        '–${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(task.remindUntil))}';
    return Container(
    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE9EFED))),
    child: Row(children: [
      SizedBox(width: 27, height: 27, child: Checkbox(value: task.done, onChanged: onChanged, shape: const CircleBorder(), side: const BorderSide(color: Color(0xFFB8C7C2), width: 1.5), activeColor: _teal, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: task.done ? _muted : _ink, decoration: task.done ? TextDecoration.lineThrough : null)),
        const SizedBox(height: 7),
        Row(children: [
          Text(_importanceLabels[task.importance]!, style: TextStyle(fontSize: 9, letterSpacing: .5, fontWeight: FontWeight.w800, color: _importanceColors[task.importance]!)),
          Container(width: 3, height: 3, margin: const EdgeInsets.symmetric(horizontal: 7), decoration: BoxDecoration(color: _importanceColors[task.importance]!, shape: BoxShape.circle)),
          Expanded(child: Text(reminderTime, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _muted))),
        ]),
      ])),
      const SizedBox(width: 7),
      if (!task.done)
        PopupMenuButton<String>(
          tooltip: 'Task options',
          icon: const Icon(Icons.more_vert_rounded, size: 19, color: Color(0xFF9EAEAA)),
          onSelected: (_) => onRemindTomorrow(),
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              value: 'tomorrow',
              child: Row(
                children: [
                  Icon(Icons.event_repeat_rounded, size: 18, color: _teal),
                  SizedBox(width: 9),
                  Text('Remind tomorrow'),
                ],
              ),
            ),
          ],
        ),
    ]),
  );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE9EFED))),
    child: const Column(children: [Icon(Icons.check_circle_outline_rounded, color: _teal, size: 28), SizedBox(height: 8), Text('Your list is empty.', style: TextStyle(fontWeight: FontWeight.w700, color: _ink)), SizedBox(height: 4), Text('Tap New task to add your first one.', style: TextStyle(fontSize: 12, color: _muted))]),
  );
}

class _GentleNote extends StatelessWidget {
  const _GentleNote();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.wb_twilight_rounded, size: 14, color: Color(0xFF75BDD8)),
      SizedBox(width: 7),
      Text('Leave a little room for the unexpected.', style: TextStyle(fontSize: 11, color: _muted)),
    ]),
  );
}

class _NotchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..moveTo(0, 0)..lineTo(size.width, 0)..lineTo(size.width, size.height * .72);
    path.cubicTo(size.width * .83, size.height * .72, size.width * .79, size.height * .98, size.width * .5, size.height * .98);
    path.cubicTo(size.width * .21, size.height * .98, size.width * .17, size.height * .72, 0, size.height * .72);
    return path..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
