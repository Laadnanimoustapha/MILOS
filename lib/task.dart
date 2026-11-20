enum TaskImportance { normal, necessary, superNecessary }
enum TaskScheduleMode { range, fixed }
enum TaskRepeat { none, daily, weekly, monthly, custom }
enum TaskRepeatUnit { days, weeks, months }
enum TaskCategory { regular, learning }

class SkillStep {
  const SkillStep({
    required this.title,
    required this.date,
    this.done = false,
  });

  final String title;
  final DateTime date;
  final bool done;

  SkillStep copyWith({
    String? title,
    DateTime? date,
    bool? done,
  }) => SkillStep(
    title: title ?? this.title,
    date: date ?? this.date,
    done: done ?? this.done,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'date': date.toIso8601String(),
    'done': done,
  };

  factory SkillStep.fromJson(Map<String, dynamic> json) => SkillStep(
    title: json['title'] as String,
    date: DateTime.parse(json['date'] as String),
    done: json['done'] as bool? ?? false,
  );
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.remindAt,
    required this.remindUntil,
    this.done = false,
    this.importance = TaskImportance.normal,
    this.superReminderIntervalMinutes = 15,
    this.scheduleMode = TaskScheduleMode.range,
    this.repeat = TaskRepeat.none,
    this.customRepeatEvery = 1,
    this.customRepeatUnit = TaskRepeatUnit.days,
    this.steps = const [],
    this.completedSteps = const [],
    this.skillSteps = const [],
    this.inProgress = false,
    this.category = TaskCategory.regular,
    this.skillProgress = 0,
  });

  final int id;
  final String title;
  final DateTime remindAt;
  final DateTime remindUntil;
  final bool done;
  final TaskImportance importance;
  final int superReminderIntervalMinutes;
  final TaskScheduleMode scheduleMode;
  final TaskRepeat repeat;
  final int customRepeatEvery;
  final TaskRepeatUnit customRepeatUnit;
  /// Optional ordered steps. When non-empty each notification shows one step.
  final List<String> steps;
  /// Indices of steps marked as completed.
  final List<int> completedSteps;
  /// Steps with dates specifically for Learning Skill tasks.
  final List<SkillStep> skillSteps;
  /// Whether the user has tapped "I started doing it" / in progress.
  final bool inProgress;
  /// Regular to-do vs. Long-term Skill learning.
  final TaskCategory category;
  /// Progress percentage for learning tasks (0..100).
  final int skillProgress;

  int get effectiveSkillProgress {
    if (skillSteps.isNotEmpty) {
      final doneCount = skillSteps.where((s) => s.done).length;
      return ((doneCount / skillSteps.length) * 100).round();
    }
    return skillProgress;
  }

  int get reminderIntervalMinutes => switch (importance) {
    TaskImportance.normal => 60,
    TaskImportance.necessary => 30,
    TaskImportance.superNecessary => superReminderIntervalMinutes,
  };

  Task copyWith({
    bool? done,
    TaskImportance? importance,
    int? superReminderIntervalMinutes,
    TaskScheduleMode? scheduleMode,
    TaskRepeat? repeat,
    int? customRepeatEvery,
    TaskRepeatUnit? customRepeatUnit,
    DateTime? remindAt,
    DateTime? remindUntil,
    List<String>? steps,
    List<int>? completedSteps,
    List<SkillStep>? skillSteps,
    bool? inProgress,
    TaskCategory? category,
    int? skillProgress,
  }) => Task(
    id: id,
    title: title,
    remindAt: remindAt ?? this.remindAt,
    remindUntil: remindUntil ?? this.remindUntil,
    done: done ?? this.done,
    importance: importance ?? this.importance,
    superReminderIntervalMinutes:
        superReminderIntervalMinutes ?? this.superReminderIntervalMinutes,
    scheduleMode: scheduleMode ?? this.scheduleMode,
    repeat: repeat ?? this.repeat,
    customRepeatEvery: customRepeatEvery ?? this.customRepeatEvery,
    customRepeatUnit: customRepeatUnit ?? this.customRepeatUnit,
    steps: steps ?? this.steps,
    completedSteps: completedSteps ?? this.completedSteps,
    skillSteps: skillSteps ?? this.skillSteps,
    inProgress: inProgress ?? this.inProgress,
    category: category ?? this.category,
    skillProgress: skillProgress ?? this.skillProgress,
  );

  /// Calculates the next occurrence date for a repeating task.
  DateTime nextOccurrence(DateTime from) {
    final unit = switch (repeat) {
      TaskRepeat.daily => TaskRepeatUnit.days,
      TaskRepeat.weekly => TaskRepeatUnit.weeks,
      TaskRepeat.monthly => TaskRepeatUnit.months,
      TaskRepeat.custom => customRepeatUnit,
      TaskRepeat.none => TaskRepeatUnit.days,
    };
    final every = repeat == TaskRepeat.custom
        ? customRepeatEvery.clamp(1, 365).toInt()
        : 1;
    if (unit == TaskRepeatUnit.days) return from.add(Duration(days: every));
    if (unit == TaskRepeatUnit.weeks) return from.add(Duration(days: every * 7));
    final monthIndex = from.year * 12 + from.month - 1 + every;
    final year = monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(
      year,
      month,
      remindAt.day.clamp(1, lastDay).toInt(),
      from.hour,
      from.minute,
      from.second,
      from.millisecond,
    );
  }

  /// Returns a new Task representing the next recurrence.
  Task nextRecurrence(int newId) {
    final nextStart = nextOccurrence(remindAt);
    final duration = remindUntil.difference(remindAt);
    final nextEnd = scheduleMode == TaskScheduleMode.fixed
        ? nextStart
        : nextStart.add(duration);
    return Task(
      id: newId,
      title: title,
      remindAt: nextStart,
      remindUntil: nextEnd,
      done: false,
      importance: importance,
      superReminderIntervalMinutes: superReminderIntervalMinutes,
      scheduleMode: scheduleMode,
      repeat: repeat,
      customRepeatEvery: customRepeatEvery,
      customRepeatUnit: customRepeatUnit,
      steps: steps,
      completedSteps: const [],
      skillSteps: skillSteps.map((s) => s.copyWith(done: false)).toList(),
      inProgress: false,
      category: category,
      skillProgress: skillProgress,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'remindAt': remindAt.toIso8601String(),
    'remindUntil': remindUntil.toIso8601String(),
    'done': done,
    'importance': importance.name,
    'superReminderIntervalMinutes': superReminderIntervalMinutes,
    'scheduleMode': scheduleMode.name,
    'repeat': repeat.name,
    'customRepeatEvery': customRepeatEvery,
    'customRepeatUnit': customRepeatUnit.name,
    if (steps.isNotEmpty) 'steps': steps,
    if (completedSteps.isNotEmpty) 'completedSteps': completedSteps,
    if (skillSteps.isNotEmpty)
      'skillSteps': skillSteps.map((s) => s.toJson()).toList(),
    if (inProgress) 'inProgress': inProgress,
    if (category != TaskCategory.regular) 'category': category.name,
    if (skillProgress > 0) 'skillProgress': skillProgress,
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as int,
    title: json['title'] as String,
    remindAt: DateTime.parse(json['remindAt'] as String),
    remindUntil: DateTime.parse(json['remindUntil'] as String),
    done: json['done'] as bool? ?? false,
    importance: TaskImportance.values.firstWhere(
      (value) => value.name == json['importance'],
      orElse: () => TaskImportance.normal,
    ),
    superReminderIntervalMinutes:
        json['superReminderIntervalMinutes'] as int? ?? 15,
    scheduleMode: TaskScheduleMode.values.firstWhere(
      (value) => value.name == json['scheduleMode'],
      orElse: () => TaskScheduleMode.range,
    ),
    repeat: TaskRepeat.values.firstWhere(
      (value) => value.name == json['repeat'],
      orElse: () => TaskRepeat.none,
    ),
    customRepeatEvery: json['customRepeatEvery'] as int? ?? 1,
    customRepeatUnit: TaskRepeatUnit.values.firstWhere(
      (value) => value.name == json['customRepeatUnit'],
      orElse: () => TaskRepeatUnit.days,
    ),
    steps: (json['steps'] as List<dynamic>?)?.cast<String>() ?? const [],
    completedSteps:
        (json['completedSteps'] as List<dynamic>?)?.cast<int>() ?? const [],
    skillSteps: (json['skillSteps'] as List<dynamic>?)
            ?.map((e) => SkillStep.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    inProgress: json['inProgress'] as bool? ?? false,
    category: TaskCategory.values.firstWhere(
      (value) => value.name == json['category'],
      orElse: () => TaskCategory.regular,
    ),
    skillProgress: json['skillProgress'] as int? ?? 0,
  );
}
