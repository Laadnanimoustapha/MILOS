import 'package:flutter/material.dart';

const _teal = Color(0xFF4CAF9E);
const _sky = Color(0xFFA3DAF5);
const _ink = Color(0xFF253533);
const _muted = Color(0xFF82908D);
const _paper = Color(0xFFF5F8F7);

void main() => runApp(const MilosApp());

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

class _Task {
  _Task(this.title, this.category, this.time, {this.done = false});
  final String title;
  final String category;
  final String time;
  bool done;
}

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final List<_Task> _tasks = [];

  int get _completed => _tasks.where((task) => task.done).length;

  String get _todayLabel {
    final now = DateTime.now();
    const weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    const months = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  Future<void> _addTask() async {
    final controller = TextEditingController();
    final title = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 34, height: 4, decoration: BoxDecoration(color: const Color(0xFFDCE5E2), borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 22),
              const Text('A little something to do', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Write your task...',
                  filled: true,
                  fillColor: _paper,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                onSubmitted: (value) => Navigator.pop(context, value),
              ),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Add to today'))),
            ]),
          ),
        ),
      ),
    );
    controller.dispose();
    if (title != null && title.trim().isNotEmpty) {
      setState(() => _tasks.add(_Task(title.trim(), 'PERSONAL', 'Anytime')));
    }
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
                    const Spacer(),
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: const Color(0xFFE8F5F2), borderRadius: BorderRadius.circular(15)),
                      child: const Icon(Icons.wb_sunny_outlined, color: _teal, size: 21),
                    ),
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
                      if (_tasks.isEmpty)
                        const _EmptyTasks()
                      else
                        ..._tasks.asMap().entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TaskTile(task: entry.value, onChanged: (value) => setState(() => entry.value.done = value ?? false)),
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
  const _TaskTile({required this.task, required this.onChanged});
  final _Task task;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE9EFED))),
    child: Row(children: [
      SizedBox(width: 27, height: 27, child: Checkbox(value: task.done, onChanged: onChanged, shape: const CircleBorder(), side: const BorderSide(color: Color(0xFFB8C7C2), width: 1.5), activeColor: _teal, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: task.done ? _muted : _ink, decoration: task.done ? TextDecoration.lineThrough : null)),
        const SizedBox(height: 7),
        Row(children: [
          Text(task.category, style: const TextStyle(fontSize: 9, letterSpacing: .9, fontWeight: FontWeight.w800, color: _teal)),
          Container(width: 3, height: 3, margin: const EdgeInsets.symmetric(horizontal: 7), decoration: const BoxDecoration(color: _sky, shape: BoxShape.circle)),
          Text(task.time, style: const TextStyle(fontSize: 10, color: _muted)),
        ]),
      ])),
      const SizedBox(width: 7),
      const Icon(Icons.drag_indicator_rounded, size: 18, color: Color(0xFFCAD5D2)),
    ]),
  );
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
