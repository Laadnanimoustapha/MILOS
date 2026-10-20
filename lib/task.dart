enum TaskImportance { normal, necessary, superNecessary }
enum TaskScheduleMode { range, fixed }
enum TaskRepeat { none, daily, weekly, monthly, custom }
enum TaskRepeatUnit { days, weeks, months }

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
  );

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
  );
}
