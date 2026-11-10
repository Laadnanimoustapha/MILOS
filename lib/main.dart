import 'dart:async';

import 'package:flutter/material.dart';

import 'ai_chat_page.dart';
import 'app_language.dart';
import 'reminder_service.dart';
import 'task.dart';
import 'task_store.dart';

const _teal = Color(0xFF4CAF9E);
const _ink = Color(0xFF253533);
const _muted = Color(0xFF82908D);
const _paper = Color(0xFFF5F8F7);
String _localized(bool arabic, String english, String arabicText) =>
    arabic ? arabicText : english;

String _dateLabel(BuildContext context, DateTime date, bool arabic) {
  if (!arabic) return MaterialLocalizations.of(context).formatMediumDate(date);
  const months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'ماي', 'يونيو',
    'يوليو', 'غشت', 'شتنبر', 'أكتوبر', 'نونبر', 'دجنبر',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

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
    // The foreground response callback is a no-op here: the actual task
    // mutation (mark done / snooze) runs inside ReminderService._handleResponse.
    // TodayPage refreshes on the next AppLifecycleState.resumed event.
    await ReminderService.instance.initialize(onForegroundResponse: (_) {});
  } catch (_) {
    // The task list remains available if device notifications are unavailable.
  }
  runApp(const MilosApp());
}

class MilosApp extends StatefulWidget {
  const MilosApp({super.key});

  @override
  State<MilosApp> createState() => _MilosAppState();
}

class _MilosAppState extends State<MilosApp> {
  AppLanguage? _language;
  bool _loadingLanguage = true;

  @override
  void initState() {
    super.initState();
    AppLanguageStore.load().then((language) {
      if (mounted) {
        setState(() {
          _language = language;
          _loadingLanguage = false;
        });
      }
    });
  }

  Future<void> _setLanguage(AppLanguage language) async {
    await AppLanguageStore.save(language);
    if (mounted) setState(() => _language = language);
  }

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
    builder: (context, child) => Directionality(
      textDirection: _language == AppLanguage.arabic
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: child!,
    ),
    home: _loadingLanguage
        ? const Scaffold(
            body: Center(child: CircularProgressIndicator(color: _teal)),
          )
        : _language == null
        ? LanguageChoicePage(onSelected: _setLanguage)
        : TodayPage(language: _language!, onLanguageChanged: _setLanguage),
  );
}

class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    required this.language,
    required this.onLanguageChanged,
  });
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> with WidgetsBindingObserver {
  final _store = TaskStore();
  final List<Task> _tasks = [];
  bool _loading = true;

  bool get _arabic => widget.language == AppLanguage.arabic;
  String _text(String english, String arabic) => _arabic ? arabic : english;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTasks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshReminders());
  }

  Future<void> _loadTasks() async {
    try {
      _tasks.addAll(await _store.load());
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
    await _refreshReminders();
  }

  Future<void> _refreshReminders() async {
    try {
      await ReminderService.instance.refresh(_tasks);
    } catch (_) {}
  }

  Future<void> _saveTasks() async {
    try {
      await _store.save(_tasks);
    } catch (_) {}
  }

  int get _completed => _tasks.where((task) => task.done).length;

  String get _todayLabel {
    final now = DateTime.now();
    const weekdays = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    if (_arabic) {
      const arabicWeekdays = [
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد',
      ];
      const arabicMonths = [
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'ماي',
        'يونيو',
        'يوليو',
        'غشت',
        'شتنبر',
        'أكتوبر',
        'نونبر',
        'دجنبر',
      ];
      return '${arabicWeekdays[now.weekday - 1]}، ${now.day} ${arabicMonths[now.month - 1]}';
    }
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  Future<void> _openMilos() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiChatPage(addTasksCallback: _addAiTasks),
      ),
    );
    setState(() {});
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LanguageSettingsPage(
          selected: widget.language,
          onSelected: (language) {
            widget.onLanguageChanged(language);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _addAiTasks(List<Task> drafts) async {
    int nextId = _tasks.isEmpty
        ? 1
        : _tasks.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
    final toAdd = drafts
        .map(
          (d) => Task(
            id: nextId++,
            title: d.title,
            remindAt: d.remindAt,
            remindUntil: d.remindUntil,
            importance: d.importance,
            superReminderIntervalMinutes: d.superReminderIntervalMinutes,
            scheduleMode: d.scheduleMode,
            repeat: d.repeat,
            customRepeatEvery: d.customRepeatEvery,
            customRepeatUnit: d.customRepeatUnit,
          ),
        )
        .toList();
    setState(() => _tasks.addAll(toAdd));
    await _saveTasks();
    try {
      if (await ReminderService.instance.requestPermission()) {
        await ReminderService.instance.refresh(_tasks);
      }
    } catch (_) {}
  }

  Future<void> _addTask() async {
    final draft = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddTaskSheet(arabic: _arabic),
    );
    if (draft == null) return;

    final task = Task(
      id: _tasks.isEmpty ? 1 : _tasks.last.id + 1,
      title: draft.title,
      remindAt: draft.remindAt,
      remindUntil: draft.remindUntil,
      importance: draft.importance,
      superReminderIntervalMinutes: draft.superReminderIntervalMinutes,
      scheduleMode: draft.scheduleMode,
      repeat: draft.repeat,
      customRepeatEvery: draft.customRepeatEvery,
      customRepeatUnit: draft.customRepeatUnit,
    );
    setState(() => _tasks.add(task));
    await _saveTasks();
    try {
      if (await ReminderService.instance.requestPermission()) {
        await ReminderService.instance.refresh(_tasks);
      }
    } catch (_) {}
  }

  Future<void> _toggleTask(Task task, bool? value) async {
    final isDone = value ?? false;
    final updated = task.copyWith(
      done: isDone,
      inProgress: isDone ? false : task.inProgress,
    );
    final taskIndex = _tasks.indexOf(task);
    if (taskIndex == -1) return;

    setState(() {
      _tasks[taskIndex] = updated;
      // If the task was just marked done and has repeat configured, spawn the next occurrence
      if (isDone && task.repeat != TaskRepeat.none) {
        final nextId = _tasks.isEmpty
            ? 1
            : _tasks.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
        _tasks.add(task.nextRecurrence(nextId));
      }
    });

    await _saveTasks();
    try {
      if (isDone) {
        await ReminderService.instance.cancel(task);
      }
      await ReminderService.instance.refresh(_tasks);
    } catch (_) {}
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text('Delete task?', 'حذف المهمة؟')),
        content: Text(
          _text(
            'Are you sure you want to delete "${task.title}"?',
            'هل أنت متأكد من حذف "${task.title}"؟',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_text('Cancel', 'إلغاء')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC36E36),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_text('Delete', 'حذف')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _tasks.remove(task));
    await _saveTasks();
    try {
      await ReminderService.instance.cancel(task);
      await ReminderService.instance.refresh(_tasks);
    } catch (_) {}
  }

  void _showTaskDetails(Task task) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TaskDetailsSheet(
        task: task,
        arabic: _arabic,
        onDelete: () {
          Navigator.pop(context);
          _deleteTask(task);
        },
      ),
    );
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
    setState(() => _tasks[_tasks.indexOf(task)] = updated);
    await _saveTasks();
    try {
      await ReminderService.instance.refresh(_tasks);
    } catch (_) {}
  }

  List<Widget> _buildGroupedTaskList() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    // Sort tasks chronologically by remindAt
    final sorted = List<Task>.from(_tasks)
      ..sort((a, b) => a.remindAt.compareTo(b.remindAt));

    // Group tasks by day (year, month, day)
    final groups = <DateTime, List<Task>>{};
    for (final task in sorted) {
      final taskDate = DateTime(
        task.remindAt.year,
        task.remindAt.month,
        task.remindAt.day,
      );
      groups.putIfAbsent(taskDate, () => []).add(task);
    }

    final widgets = <Widget>[];
    var isFirstSection = true;

    for (final entry in groups.entries) {
      final date = entry.key;
      final tasks = entry.value;

      String sectionTitle;
      Color? accentColor;
      if (date.isBefore(today)) {
        sectionTitle = _text('Overdue', 'متأخرة');
        accentColor = const Color(0xFFC36E36);
      } else if (date == today) {
        sectionTitle = _text('Today', 'اليوم');
        accentColor = _teal;
      } else if (date == tomorrow) {
        sectionTitle = _text('Tomorrow', 'غداً');
      } else {
        if (_arabic) {
          const weekdays = [
            'الاثنين',
            'الثلاثاء',
            'الأربعاء',
            'الخميس',
            'الجمعة',
            'السبت',
            'الأحد',
          ];
          const months = [
            'يناير',
            'فبراير',
            'مارس',
            'أبريل',
            'ماي',
            'يونيو',
            'يوليو',
            'غشت',
            'شتنبر',
            'أكتوبر',
            'نونبر',
            'دجنبر',
          ];
          sectionTitle =
              '${weekdays[date.weekday - 1]}، ${date.day} ${months[date.month - 1]}';
        } else {
          const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          const months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
          sectionTitle =
              '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
        }
      }

      widgets.add(
        _DateSectionHeader(
          title: sectionTitle,
          count: tasks.length,
          showDivider: !isFirstSection,
          accentColor: accentColor,
        ),
      );
      isFirstSection = false;

      for (final task in tasks) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TaskTile(
              task: task,
              arabic: _arabic,
              onTap: () => _showTaskDetails(task),
              onChanged: (value) => _toggleTask(task, value),
              onRemindTomorrow: () => _remindTomorrow(task),
              onDelete: () => _deleteTask(task),
            ),
          ),
        );
      }
    }

    return widgets;
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
        label: Text(
          _text('New task', 'مهمة جديدة'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            children: [
              SizedBox(
                height: 174,
                width: double.infinity,
                child: ClipPath(
                  clipper: _NotchClipper(),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _todayLabel,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 1.4,
                                    fontWeight: FontWeight.w700,
                                    color: _muted,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  _text('Good morning,', 'صباح الخير،'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: _ink,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.settings_outlined,
                                color: _muted,
                              ),
                              onPressed: _openSettings,
                            ),
                            _MilosButton(onTap: _openMilos),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          _text('Today', 'اليوم'),
                          style: const TextStyle(
                            fontSize: 40,
                            height: 1,
                            letterSpacing: -1.6,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _text(
                            'A fresh page, at your own pace.',
                            'يوم جديد، على مهل.',
                          ),
                          style: const TextStyle(fontSize: 13, color: _muted),
                        ),
                        const SizedBox(height: 22),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 3, 22, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProgressPanel(
                          completed: _completed,
                          total: _tasks.length,
                          progress: progress,
                          arabic: _arabic,
                        ),
                        const SizedBox(height: 25),
                        Row(
                          children: [
                            Text(
                              _text('Your tasks', 'مهامك'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.4,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5F2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _tasks.isEmpty
                                    ? _text('Start fresh', 'ابدأ الآن')
                                    : _text(
                                        '${_tasks.length - _completed} left',
                                        '${_tasks.length - _completed} متبقية',
                                      ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _teal,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _text('See all', 'عرض الكل'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        if (_loading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(color: _teal),
                            ),
                          )
                        else if (_tasks.isEmpty)
                          _EmptyTasks(arabic: _arabic)
                        else
                          ..._buildGroupedTaskList(),
                        const SizedBox(height: 5),
                        _GentleNote(arabic: _arabic),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet({required this.arabic});
  final bool arabic;

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
  TaskScheduleMode _scheduleMode = TaskScheduleMode.range;
  TaskRepeat _repeat = TaskRepeat.none;
  int _customRepeatEvery = 1;
  TaskRepeatUnit _customRepeatUnit = TaskRepeatUnit.days;
  String? _error;
  bool get _arabic => widget.arabic;
  String _text(String english, String arabic) =>
      _localized(_arabic, english, arabic);

  @override
  void initState() {
    super.initState();
    final nextHour = DateTime.now().add(const Duration(hours: 1));
    _date = DateTime(nextHour.year, nextHour.month, nextHour.day);
    _from = TimeOfDay.fromDateTime(nextHour);
    final endHour = nextHour.hour + 3;
    _until = TimeOfDay(hour: endHour > 23 ? 23 : endHour, minute: 0);
    if (_until.hour == _from.hour)
      _until = const TimeOfDay(hour: 23, minute: 59);
  }

  DateTime _at(TimeOfDay time) =>
      DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);

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
      initialTime: start || _scheduleMode == TaskScheduleMode.fixed
          ? _from
          : _until,
    );
    if (selected != null) {
      setState(() {
        if (start) {
          _from = selected;
          if (_scheduleMode == TaskScheduleMode.fixed) _until = selected;
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
    final until = _scheduleMode == TaskScheduleMode.fixed ? from : _at(_until);
    if (title.isEmpty) {
      setState(
        () => _error = _text(
          'Give your task a name first.',
          'اكتب اسماً للمهمة أولاً.',
        ),
      );
    } else if (!from.isAfter(DateTime.now())) {
      setState(
        () => _error = _text(
          'Choose a reminder time in the future.',
          'اختر وقت تذكير في المستقبل.',
        ),
      );
    } else if (_scheduleMode == TaskScheduleMode.range &&
        !until.isAfter(from)) {
      setState(
        () => _error = _text(
          'The reminder end must be after its start.',
          'يجب أن يكون وقت انتهاء التذكير بعد وقت بدايته.',
        ),
      );
    } else {
      final intervalMinutes = _scheduleMode == TaskScheduleMode.fixed
          ? 1
          : switch (_importance) {
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
          () => _error = _text(
            'Choose a longer interval or a shorter reminder window (max 60 reminders).',
            'اختر فاصلاً زمنياً أطول أو مدة تذكير أقصر (الحد الأقصى ٦٠ تذكيراً).',
          ),
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
          scheduleMode: _scheduleMode,
          repeat: _repeat,
          customRepeatEvery: _customRepeatEvery,
          customRepeatUnit: _customRepeatUnit,
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
                    Text(
                      _text('Make time for it', 'خصص وقتاً لها'),
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _text(
                        'A small nudge at the right time.',
                        'تذكير بسيط في الوقت المناسب.',
                      ),
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
                      _FormLabel(_text('TASK', 'المهمة')),
                      const SizedBox(height: 7),
                      TextField(
                        controller: _controller,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: _text(
                            'What would you like to do?',
                            'ما الذي ترغب في إنجازه؟',
                          ),
                          filled: true,
                          fillColor: _paper,
                          prefixIcon: const Icon(
                            Icons.edit_outlined,
                            color: _teal,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 17,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _save(),
                      ),
                      const SizedBox(height: 20),
                      _FormLabel(_text('PRIORITY', 'الأولوية')),
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
                                              TaskImportance.normal => _text(
                                                'Normal',
                                                'عادية',
                                              ),
                                              TaskImportance.necessary => _text(
                                                'Necessary',
                                                'مهمة',
                                              ),
                                              TaskImportance.superNecessary =>
                                                _text(
                                                  'Super\nnecessary',
                                                  'مهمة جداً',
                                                ),
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
                        _FormLabel(_text('REMIND ME EVERY', 'ذكّرني كل')),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 7,
                          children: [
                            for (final minutes in _superReminderIntervals)
                              ChoiceChip(
                                label: Text(
                                  minutes == 60
                                      ? _text('1 hour', 'ساعة واحدة')
                                      : _text('$minutes min', '$minutes دقيقة'),
                                ),
                                selected:
                                    _superReminderIntervalMinutes == minutes,
                                onSelected: (_) => setState(
                                  () => _superReminderIntervalMinutes = minutes,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      _FormLabel(_text('DATE', 'التاريخ')),
                      const SizedBox(height: 7),
                      _PickerButton(
                        icon: Icons.calendar_today_rounded,
                        title: _dateLabel(context, _date, _arabic),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 18),
                      _FormLabel(_text('REMINDER TYPE', 'نوع التذكير')),
                      const SizedBox(height: 7),
                      _ChoiceRow<TaskScheduleMode>(
                        values: TaskScheduleMode.values,
                        selected: _scheduleMode,
                        labels: [
                          _text('Time range', 'فترة زمنية'),
                          _text('One time', 'مرة واحدة'),
                        ],
                        onSelected: (mode) => setState(() {
                          _scheduleMode = mode;
                          if (mode == TaskScheduleMode.fixed) _until = _from;
                        }),
                      ),
                      const SizedBox(height: 18),
                      _FormLabel(_text('REPEAT', 'التكرار')),
                      const SizedBox(height: 7),
                      DropdownButtonFormField<TaskRepeat>(
                        initialValue: _repeat,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: _paper,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: TaskRepeat.none,
                            child: Text(_text('Does not repeat', 'لا يتكرر')),
                          ),
                          DropdownMenuItem(
                            value: TaskRepeat.daily,
                            child: Text(_text('Every day', 'كل يوم')),
                          ),
                          DropdownMenuItem(
                            value: TaskRepeat.weekly,
                            child: Text(_text('Every week', 'كل أسبوع')),
                          ),
                          DropdownMenuItem(
                            value: TaskRepeat.monthly,
                            child: Text(_text('Every month', 'كل شهر')),
                          ),
                          DropdownMenuItem(
                            value: TaskRepeat.custom,
                            child: Text(_text('Custom', 'مخصص')),
                          ),
                        ],
                        onChanged: (repeat) =>
                            setState(() => _repeat = repeat ?? TaskRepeat.none),
                      ),
                      if (_repeat == TaskRepeat.custom) ...[
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Text(
                              _text('Every', 'كل'),
                              style: const TextStyle(color: _muted),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 68,
                              child: TextFormField(
                                initialValue: '$_customRepeatEvery',
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: _paper,
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onChanged: (value) => _customRepeatEvery =
                                    (int.tryParse(value) ?? 1)
                                        .clamp(1, 365)
                                        .toInt(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<TaskRepeatUnit>(
                                initialValue: _customRepeatUnit,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: _paper,
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: TaskRepeatUnit.days,
                                    child: Text(_text('days', 'أيام')),
                                  ),
                                  DropdownMenuItem(
                                    value: TaskRepeatUnit.weeks,
                                    child: Text(_text('weeks', 'أسابيع')),
                                  ),
                                  DropdownMenuItem(
                                    value: TaskRepeatUnit.months,
                                    child: Text(_text('months', 'أشهر')),
                                  ),
                                ],
                                onChanged: (unit) => setState(
                                  () => _customRepeatUnit =
                                      unit ?? TaskRepeatUnit.days,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      _FormLabel(
                        _scheduleMode == TaskScheduleMode.fixed
                            ? _text('REMIND ME AT', 'ذكّرني عند')
                            : _text('REMINDER WINDOW', 'فترة التذكير'),
                      ),
                      const SizedBox(height: 7),
                      if (_scheduleMode == TaskScheduleMode.range)
                        Row(
                          children: [
                            Expanded(
                              child: _PickerButton(
                                icon: Icons.notifications_active_outlined,
                                title: _from.format(context),
                                subtitle: _text('FROM', 'من'),
                                onTap: () => _pickTime(start: true),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 17,
                                color: _muted,
                              ),
                            ),
                            Expanded(
                              child: _PickerButton(
                                icon: Icons.notifications_none_rounded,
                                title: _until.format(context),
                                subtitle: _text('UNTIL', 'إلى'),
                                onTap: () => _pickTime(start: false),
                              ),
                            ),
                          ],
                        )
                      else
                        _PickerButton(
                          icon: Icons.notifications_active_outlined,
                          title: _from.format(context),
                          onTap: () => _pickTime(start: true),
                        ),
                      const SizedBox(height: 10),
                      if (_scheduleMode == TaskScheduleMode.range)
                        Row(
                          children: [
                            const Icon(
                              Icons.repeat_rounded,
                              size: 16,
                              color: _teal,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                '${_intervalDescription()} · ${_text('final reminder at', 'آخر تذكير عند')} ${_until.format(context)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFB54141),
                            fontSize: 12,
                          ),
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
                    label: Text(_text('Create task', 'إنشاء المهمة')),
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
    TaskImportance.normal => _text('Every hour', 'كل ساعة'),
    TaskImportance.necessary => _text('Every 30 minutes', 'كل ٣٠ دقيقة'),
    TaskImportance.superNecessary => _text(
      'Every ${_superReminderIntervalMinutes == 60 ? 'hour' : '$_superReminderIntervalMinutes minutes'}',
      _superReminderIntervalMinutes == 60
          ? 'كل ساعة'
          : 'كل $_superReminderIntervalMinutes دقيقة',
    ),
  };
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.values,
    required this.selected,
    required this.labels,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final List<String> labels;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        for (var index = 0; index < values.length; index++)
          Expanded(
            child: Material(
              color: selected == values[index]
                  ? const Color(0xFFDDF2ED)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelected(values[index]),
                child: SizedBox(
                  height: 42,
                  child: Center(
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected == values[index] ? _teal : _muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
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
  const _ProgressPanel({
    required this.completed,
    required this.total,
    required this.progress,
    required this.arabic,
  });
  final int completed;
  final int total;
  final double progress;
  final bool arabic;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE9EFED)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 54,
          height: 54,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: const Color(0xFFEAF1EF),
                  valueColor: const AlwaysStoppedAnimation<Color>(_teal),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                total == 0
                    ? _localized(
                        arabic,
                        'No tasks added yet',
                        'لم تتم إضافة مهام بعد',
                      )
                    : _localized(
                        arabic,
                        '$completed of $total tasks complete',
                        'اكتملت $completed من أصل $total مهام',
                      ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                total == 0
                    ? _localized(
                        arabic,
                        'Add a task to start your progress.',
                        'أضف مهمة لبدء التقدم.',
                      )
                    : _localized(
                        arabic,
                        'Small steps still move you forward.',
                        'الخطوات الصغيرة تقرّبك من هدفك.',
                      ),
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
            ],
          ),
        ),
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7FC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.spa_outlined,
            size: 18,
            color: Color(0xFF65B8D8),
          ),
        ),
      ],
    ),
  );
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.arabic,
    required this.onTap,
    required this.onChanged,
    required this.onRemindTomorrow,
    required this.onDelete,
  });
  final Task task;
  final bool arabic;
  final VoidCallback onTap;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onRemindTomorrow;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final startTime = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(task.remindAt),
    );
    final reminderTime = task.scheduleMode == TaskScheduleMode.fixed
        ? '${_dateLabel(context, task.remindAt, arabic)} · ${_localized(arabic, 'at', 'عند')} $startTime${_repeatLabel(task)}'
        : '${_dateLabel(context, task.remindAt, arabic)} · $startTime'
              '–${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(task.remindUntil))}${_repeatLabel(task)}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE9EFED)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 27,
                height: 27,
                child: Checkbox(
                  value: task.done,
                  onChanged: onChanged,
                  shape: const CircleBorder(),
                  side: const BorderSide(color: Color(0xFFB8C7C2), width: 1.5),
                  activeColor: _teal,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: task.done ? _muted : _ink,
                        decoration: task.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Text(
                          _localized(
                            arabic,
                            _importanceLabels[task.importance]!,
                            switch (task.importance) {
                              TaskImportance.normal => 'عادية',
                              TaskImportance.necessary => 'مهمة',
                              TaskImportance.superNecessary => 'مهمة جداً',
                            },
                          ),
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: .5,
                            fontWeight: FontWeight.w800,
                            color: _importanceColors[task.importance]!,
                          ),
                        ),
                        Container(
                          width: 3,
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 7),
                          decoration: BoxDecoration(
                            color: _importanceColors[task.importance]!,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            reminderTime,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: _muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              PopupMenuButton<String>(
                tooltip: _localized(arabic, 'Task options', 'خيارات المهمة'),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 19,
                  color: Color(0xFF9EAEAA),
                ),
                onSelected: (value) {
                  if (value == 'tomorrow') onRemindTomorrow();
                  if (value == 'details') onTap();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'details',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: _teal,
                        ),
                        const SizedBox(width: 9),
                        Text(_localized(arabic, 'Details', 'التفاصيل')),
                      ],
                    ),
                  ),
                  if (!task.done)
                    PopupMenuItem<String>(
                      value: 'tomorrow',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_repeat_rounded,
                            size: 18,
                            color: _teal,
                          ),
                          const SizedBox(width: 9),
                          Text(
                            _localized(
                              arabic,
                              'Remind tomorrow',
                              'ذكّرني غداً',
                            ),
                          ),
                        ],
                      ),
                    ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Color(0xFFC36E36),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          _localized(arabic, 'Delete', 'حذف'),
                          style: const TextStyle(color: Color(0xFFC36E36)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _repeatLabel(Task task) => switch (task.repeat) {
    TaskRepeat.none => '',
    TaskRepeat.daily => _localized(arabic, ' · Daily', ' · يومياً'),
    TaskRepeat.weekly => _localized(arabic, ' · Weekly', ' · أسبوعياً'),
    TaskRepeat.monthly => _localized(arabic, ' · Monthly', ' · شهرياً'),
    TaskRepeat.custom => _localized(
      arabic,
      ' · Every ${task.customRepeatEvery} ${task.customRepeatUnit.name}',
      ' · كل ${task.customRepeatEvery} ${switch (task.customRepeatUnit) {
        TaskRepeatUnit.days => 'أيام',
        TaskRepeatUnit.weeks => 'أسابيع',
        TaskRepeatUnit.months => 'أشهر',
      }}',
    ),
  };
}

class _DateSectionHeader extends StatelessWidget {
  const _DateSectionHeader({
    required this.title,
    required this.count,
    this.showDivider = true,
    this.accentColor,
  });

  final String title;
  final int count;
  final bool showDivider;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: showDivider ? 18.0 : 4.0, bottom: 9.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFE4ECE9)),
          ),
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: .2,
                color: accentColor ?? _ink,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: (accentColor ?? _teal).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: accentColor ?? _teal,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.arabic});
  final bool arabic;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE9EFED)),
    ),
    child: Column(
      children: [
        const Icon(Icons.check_circle_outline_rounded, color: _teal, size: 28),
        const SizedBox(height: 8),
        Text(
          _localized(arabic, 'Your list is empty.', 'قائمتك فارغة.'),
          style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
        const SizedBox(height: 4),
        Text(
          _localized(
            arabic,
            'Tap New task to add your first one.',
            'اضغط على «مهمة جديدة» لإضافة أول مهمة.',
          ),
          style: const TextStyle(fontSize: 12, color: _muted),
        ),
      ],
    ),
  );
}

class _GentleNote extends StatelessWidget {
  const _GentleNote({required this.arabic});
  final bool arabic;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.wb_twilight_rounded,
          size: 14,
          color: Color(0xFF75BDD8),
        ),
        const SizedBox(width: 7),
        Text(
          _localized(
            arabic,
            'Leave a little room for the unexpected.',
            'اترك مساحة صغيرة لما هو غير متوقع.',
          ),
          style: const TextStyle(fontSize: 11, color: _muted),
        ),
      ],
    ),
  );
}

class _NotchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * .72);
    path.cubicTo(
      size.width * .83,
      size.height * .72,
      size.width * .79,
      size.height * .98,
      size.width * .5,
      size.height * .98,
    );
    path.cubicTo(
      size.width * .21,
      size.height * .98,
      size.width * .17,
      size.height * .72,
      0,
      size.height * .72,
    );
    return path..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _MilosButton extends StatelessWidget {
  const _MilosButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCDE8E1)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.elderly_rounded, size: 16, color: _teal),
          SizedBox(width: 5),
          Text(
            'Milos',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _teal,
            ),
          ),
        ],
      ),
    ),
  );
}

class _TaskDetailsSheet extends StatelessWidget {
  const _TaskDetailsSheet({
    required this.task,
    required this.arabic,
    required this.onDelete,
  });

  final Task task;
  final bool arabic;
  final VoidCallback onDelete;

  String _t(String en, String ar) => arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final startTime = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(task.remindAt),
    );
    final endTime = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(task.remindUntil),
    );
    final dateStr = _dateLabel(context, task.remindAt, arabic);

    return FractionallySizedBox(
      heightFactor: .78,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
                child: Column(
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
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          _t('Task Details', 'تفاصيل المهمة'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: task.done
                                ? const Color(0xFFE8F5F2)
                                : const Color(0xFFFFF4EC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            task.done
                                ? _t('Completed', 'مكتملة')
                                : (task.inProgress
                                      ? _t('In progress', 'قيد التنفيذ')
                                      : _t('Pending', 'قيد الانتظار')),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: task.done
                                  ? _teal
                                  : const Color(0xFFC36E36),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE9EFED)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _detailRow(
                        Icons.flag_rounded,
                        _t('Priority', 'الأولوية'),
                        _t(
                          _importanceLabels[task.importance]!,
                          switch (task.importance) {
                            TaskImportance.normal => 'عادية',
                            TaskImportance.necessary => 'مهمة',
                            TaskImportance.superNecessary => 'مهمة جداً',
                          },
                        ),
                        color: _importanceColors[task.importance],
                      ),
                      const SizedBox(height: 14),
                      _detailRow(
                        Icons.calendar_today_rounded,
                        _t('Date', 'التاريخ'),
                        dateStr,
                      ),
                      const SizedBox(height: 14),
                      _detailRow(
                        Icons.access_time_rounded,
                        _t('Schedule', 'الوقت'),
                        task.scheduleMode == TaskScheduleMode.fixed
                            ? '${_t("At", "عند")} $startTime'
                            : '$startTime – $endTime',
                      ),
                      const SizedBox(height: 14),
                      _detailRow(
                        Icons.repeat_rounded,
                        _t('Repeat', 'التكرار'),
                        _repeatText(),
                      ),
                      if (task.steps.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          _t('Steps', 'الخطوات'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (var i = 0; i < task.steps.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${i + 1}. ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _teal,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    task.steps[i],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE9EFED))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFC36E36),
                    ),
                    label: Text(
                      _t('Delete task', 'حذف المهمة'),
                      style: const TextStyle(
                        color: Color(0xFFC36E36),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFFD4C2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) => Row(
    children: [
      Icon(icon, size: 18, color: color ?? _teal),
      const SizedBox(width: 10),
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: _muted,
          fontWeight: FontWeight.w500,
        ),
      ),
      const Spacer(),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color ?? _ink,
        ),
      ),
    ],
  );

  String _repeatText() => switch (task.repeat) {
    TaskRepeat.none => _t('Does not repeat', 'لا يتكرر'),
    TaskRepeat.daily => _t('Daily', 'يومياً'),
    TaskRepeat.weekly => _t('Weekly', 'أسبوعياً'),
    TaskRepeat.monthly => _t('Monthly', 'شهرياً'),
    TaskRepeat.custom => _t(
      'Every ${task.customRepeatEvery} ${task.customRepeatUnit.name}',
      'كل ${task.customRepeatEvery} ${switch (task.customRepeatUnit) {
        TaskRepeatUnit.days => 'أيام',
        TaskRepeatUnit.weeks => 'أسابيع',
        TaskRepeatUnit.months => 'أشهر',
      }}',
    ),
  };
}
