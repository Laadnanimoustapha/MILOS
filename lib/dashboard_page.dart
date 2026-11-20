import 'package:flutter/material.dart';

import 'ai_chat_page.dart';
import 'habit_store.dart';
import 'streak_store.dart';
import 'task.dart';
import 'task_store.dart';

const _teal = Color(0xFF4CAF9E);
const _ink = Color(0xFF253533);
const _muted = Color(0xFF82908D);
const _paper = Color(0xFFF5F8F7);

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.arabic,
    required this.addTasksCallback,
  });

  final bool arabic;
  final Future<void> Function(List<Task> tasks) addTasksCallback;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool get _arabic => widget.arabic;
  String _t(String en, String ar) => _arabic ? ar : en;

  final _taskStore = TaskStore();
  List<Task> _tasks = [];
  int _streak = 0;
  List<bool> _weekDots = List.filled(7, false);
  Map<String, bool> _prayers = {};
  int _smokeCleanDays = 0;
  List<HabitItem> _habits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final tasks = await _taskStore.load();
      final streak = await StreakStore.loadStreak();
      final dots = await StreakStore.currentWeekDots();
      final prayers = await HabitStore.loadPrayers();
      final smoke = await HabitStore.loadSmokingCleanDays();
      final habits = await HabitStore.loadCustomHabits();

      if (mounted) {
        setState(() {
          _tasks = tasks;
          _streak = streak;
          _weekDots = dots;
          _prayers = prayers;
          _smokeCleanDays = smoke;
          _habits = habits;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isOverdue(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(d.year, d.month, d.day);
    return taskDay.isBefore(today);
  }

  void _runAiAnalysis() {
    final todayTasks = _tasks.where((t) => _isToday(t.remindAt)).toList();
    final todayDone = todayTasks.where((t) => t.done).length;
    final overdueCount = _tasks.where((t) => !t.done && _isOverdue(t.remindAt)).length;
    final prayersDone = _prayers.values.where((v) => v).length;
    final habitsDone = _habits.where((h) => h.isDoneToday()).length;
    final learningTasks = _tasks.where((t) => t.category == TaskCategory.learning).toList();

    final prompt = _arabic
        ? '''
مرحباً يا ميلوس، أحتاج تحليلك الصادق والشامل لتقدمي اليوم:
- المهام المحددة لليوم: $todayDone مكتملة من أصل ${todayTasks.length}
- المهام المتأخرة: $overdueCount
- سلسلة الإنجاز اليومية: $_streak يوم
- الصلوات اليومية: $prayersDone من أصل 5
- أيام الامتناع عن التدخين: $_smokeCleanDays يوماً
- العادات المنجزة اليوم: $habitsDone من أصل ${_habits.length}
${learningTasks.isNotEmpty ? '- مسار المهارات والتعلم: ${learningTasks.map((t) => "${t.title} (${t.skillProgress}%)").join(", ")}' : ''}

بصفتك حكيماً وموجهاً، قيّم التزامي اليوم وقدم لي نصائح عملية لما يجب التركيز عليه لتحسين وتيرة إنجازي.
'''
        : '''
Hello Milos, please give me a comprehensive and honest review of my progress today:
- Today's tasks: $todayDone completed out of ${todayTasks.length}
- Overdue tasks: $overdueCount
- Daily streak: $_streak days
- Daily prayers: $prayersDone of 5
- Smoke-free streak: $_smokeCleanDays days
- Habits completed today: $habitsDone of ${_habits.length}
${learningTasks.isNotEmpty ? '- Learning skills: ${learningTasks.map((t) => "${t.title} (${t.skillProgress}%)").join(", ")}' : ''}

As my coach and mentor, evaluate my discipline and give me practical advice on how to improve and stay consistent.
''';

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiChatPage(
          arabic: _arabic,
          addTasksCallback: widget.addTasksCallback,
          initialPrompt: prompt.trim(),
          autoSend: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _paper,
        body: Center(child: CircularProgressIndicator(color: _teal)),
      );
    }

    final todayTasks = _tasks.where((t) => _isToday(t.remindAt)).toList();
    final todayDone = todayTasks.where((t) => t.done).length;
    final todayTotal = todayTasks.length;
    final overdueCount = _tasks.where((t) => !t.done && _isOverdue(t.remindAt)).length;
    final prayersDone = _prayers.values.where((v) => v).length;
    final learningTasks = _tasks.where((t) => t.category == TaskCategory.learning).toList();
    final progressPct = todayTotal == 0 ? 0 : ((todayDone / todayTotal) * 100).round();

    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                _t('Dashboard & Progress', 'لوحة التقدم والإحصائيات'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _t('Your life at a glance, monitored and analyzed.', 'نظرة شاملة على تقدمك والتزامك اليومي.'),
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
              const SizedBox(height: 18),

              // ─── AI COACH ANALYSIS BANNER ──────────────────────────────
              _buildAiCoachCard(),
              const SizedBox(height: 18),

              // ─── TODAY'S METRICS ─────────────────────────────────────────
              _buildMetricsOverview(todayDone, todayTotal, overdueCount, progressPct),
              const SizedBox(height: 18),

              // ─── 7-DAY CONSISTENCY CHART ─────────────────────────────────
              _buildWeekConsistencyCard(),
              const SizedBox(height: 18),

              // ─── LIFESTYLE & DISCIPLINE HIGHLIGHTS ───────────────────────
              _buildLifestyleHighlights(prayersDone),
              const SizedBox(height: 18),

              // ─── LEARNING & SKILLS (FEAT-5) ──────────────────────────────
              if (learningTasks.isNotEmpty) ...[
                _buildLearningSection(learningTasks),
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiCoachCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF2B4743), Color(0xFF1E3532)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: _ink.withValues(alpha: 0.15),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/milos_logo.webp',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Milos AI Progress Review', 'تحليل ميلوس الذكي للتقدم'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _t('Professional coaching, remarks & guidance', 'ملاحظات وتوجيهات عملية من ميلوس'),
                    style: const TextStyle(fontSize: 11, color: Color(0xFFB5CCC6)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          _t(
            'Tap below to let Milos analyze your current tasks, prayers, habits, and streaks to give you wise, actionable insights.',
            'اضغط على الزر أدناه ليقوم ميلوس بدراسة مهامك وصلواتك وعاداتك ويقدم لك نصائح مخصصة.',
          ),
          style: const TextStyle(fontSize: 12, color: Color(0xFFD6E8E3), height: 1.4),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            onPressed: _runAiAnalysis,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(_t('Analyse My Progress', 'حلل تقدمي الآن')),
            style: FilledButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildMetricsOverview(int done, int total, int overdue, int pct) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE9EFED)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('Today at a Glance', 'نظرة على اليوم'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _metricBox(
                title: _t('Completed', 'مكتملة'),
                value: '$done / $total',
                color: _teal,
                icon: Icons.task_alt_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricBox(
                title: _t('Overdue', 'متأخرة'),
                value: '$overdue',
                color: overdue > 0 ? const Color(0xFFC36E36) : _muted,
                icon: Icons.history_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricBox(
                title: _t('Streak', 'السلسلة'),
                value: '$_streak d',
                color: const Color(0xFFE07A30),
                icon: Icons.local_fire_department_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: total == 0 ? 0.0 : done / total,
            minHeight: 8,
            backgroundColor: const Color(0xFFEAF1EF),
            valueColor: const AlwaysStoppedAnimation<Color>(_teal),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$pct% ${_t("achieved today", "منجز اليوم")}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _muted),
          ),
        ),
      ],
    ),
  );

  Widget _metricBox({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: _muted, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _buildWeekConsistencyCard() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const daysAr = ['اثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت', 'أحد'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9EFED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t('7-Day Consistency', 'الالتزام خلال الأسبوع'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
              ),
              Text(
                '$_streak ${_t("days streak 🔥", "أيام متتالية 🔥")}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFE07A30)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final active = i < _weekDots.length && _weekDots[i];
              return Column(
                children: [
                  Container(
                    width: 32,
                    height: 52,
                    decoration: BoxDecoration(
                      color: active ? _teal : const Color(0xFFEFF4F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: active
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _arabic ? daysAr[i] : days[i],
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _muted),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLifestyleHighlights(int prayersDone) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE9EFED)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('Lifestyle Highlights', 'نمط الحياة والالتزام'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _highlightTile(
                icon: Icons.mosque_rounded,
                title: _t('Prayers', 'الصلوات'),
                subtitle: '$prayersDone / 5',
                color: _teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _highlightTile(
                icon: Icons.smoke_free_rounded,
                title: _t('No Smoking', 'بدون تدخين'),
                subtitle: '$_smokeCleanDays ${_t("days", "يوماً")}',
                color: const Color(0xFFE07A30),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _highlightTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildLearningSection(List<Task> learningTasks) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE9EFED)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.school_rounded, color: _teal, size: 20),
            const SizedBox(width: 8),
            Text(
              _t('Skill Learning Tracks', 'مسارات تعلم المهارات'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...learningTasks.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
                  Text('${t.skillProgress}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _teal)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: t.skillProgress / 100.0,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFEAF1EF),
                  valueColor: const AlwaysStoppedAnimation<Color>(_teal),
                ),
              ),
            ],
          ),
        )),
      ],
    ),
  );
}
