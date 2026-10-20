enum TaskImportance { normal, necessary, superNecessary }

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.remindAt,
    required this.remindUntil,
    this.done = false,
    this.importance = TaskImportance.normal,
    this.superReminderIntervalMinutes = 15,
  });

  final int id;
  final String title;
  final DateTime remindAt;
  final DateTime remindUntil;
  final bool done;
  final TaskImportance importance;
  final int superReminderIntervalMinutes;

  int get reminderIntervalMinutes => switch (importance) {
    TaskImportance.normal => 60,
    TaskImportance.necessary => 30,
    TaskImportance.superNecessary => superReminderIntervalMinutes,
  };

  Task copyWith({
    bool? done,
    TaskImportance? importance,
    int? superReminderIntervalMinutes,
  }) => Task(
    id: id,
    title: title,
    remindAt: remindAt,
    remindUntil: remindUntil,
    done: done ?? this.done,
    importance: importance ?? this.importance,
    superReminderIntervalMinutes:
        superReminderIntervalMinutes ?? this.superReminderIntervalMinutes,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'remindAt': remindAt.toIso8601String(),
    'remindUntil': remindUntil.toIso8601String(),
    'done': done,
    'importance': importance.name,
    'superReminderIntervalMinutes': superReminderIntervalMinutes,
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
  );
}
