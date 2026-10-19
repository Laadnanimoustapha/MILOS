class Task {
  const Task({
    required this.id,
    required this.title,
    required this.remindAt,
    required this.remindUntil,
    this.done = false,
  });

  final int id;
  final String title;
  final DateTime remindAt;
  final DateTime remindUntil;
  final bool done;

  Task copyWith({bool? done}) => Task(
    id: id,
    title: title,
    remindAt: remindAt,
    remindUntil: remindUntil,
    done: done ?? this.done,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'remindAt': remindAt.toIso8601String(),
    'remindUntil': remindUntil.toIso8601String(),
    'done': done,
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as int,
    title: json['title'] as String,
    remindAt: DateTime.parse(json['remindAt'] as String),
    remindUntil: DateTime.parse(json['remindUntil'] as String),
    done: json['done'] as bool? ?? false,
  );
}
