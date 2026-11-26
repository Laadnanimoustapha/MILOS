import 'dart:async';

import 'package:flutter/material.dart';

import 'add_skill_sheet.dart';
import 'ai_chat_page.dart';
import 'habit_store.dart';
import 'reminder_service.dart';
import 'streak_store.dart';
import 'sync_service.dart';
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
  Map<String, int> _prayerCounts = {};
  Map<String, int> _weekPrayerTotals = {};
  Map<String, int> _allPrayerTotals = {};
  List<StreakTracker> _customStreaks = [];
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
      final prayerCounts = await HabitStore.loadPrayerCounts();
      final weekPrayerTotals = await HabitStore.loadPrayerTotals(lastDays: 7);
      final allPrayerTotals = await HabitStore.loadPrayerTotals();
      final streaks = await HabitStore.loadCustomStreaks();
      final habits = await HabitStore.loadCustomHabits();

      if (mounted) {
        setState(() {
          _tasks = tasks;
          _streak = streak;
          _weekDots = dots;
          _prayerCounts = prayerCounts;
          _weekPrayerTotals = weekPrayerTotals;
          _allPrayerTotals = allPrayerTotals;
          _customStreaks = streaks;
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

  Future<void> _addNewSkill() async {
    final skill = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSkillSheet(arabic: _arabic),
    );
    if (skill == null) return;
    final nextId = _tasks.isEmpty
        ? 1
        : _tasks.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
    final toAdd = Task(
      id: nextId,
      title: skill.title,
      remindAt: skill.remindAt,
      remindUntil: skill.remindUntil,
      importance: skill.importance,
      superReminderIntervalMinutes: skill.superReminderIntervalMinutes,
      scheduleMode: skill.scheduleMode,
      category: TaskCategory.learning,
      skillSteps: skill.skillSteps,
      steps: skill.steps,
      skillProgress: 0,
    );
    _tasks.add(toAdd);
    await _taskStore.save(_tasks);
    unawaited(SyncService.syncNow());
    await _loadData();
    try {
      await ReminderService.instance.refresh(_tasks);
    } catch (_) {}
  }

  void _runAiAnalysis([String? focusMode]) {
    final todayTasks = _tasks.where((t) => _isToday(t.remindAt)).toList();
    final todayDone = todayTasks.where((t) => t.done).length;
    final todayFailed = todayTasks.where((t) => t.failed).length;
    final totalFailed = TaskStore.countFailed(_tasks);
    final overdueCount = _tasks.where((t) => !t.done && !t.failed && _isOverdue(t.remindAt)).length;
    final prayersDone = _prayerCounts.values.where((v) => v > 0).length;
    final prayerSummary = HabitStore.prayerNames
        .map((p) => '$p: ${_allPrayerTotals[p] ?? 0}')
        .join(', ');
    final habitsDone = _habits.where((h) => h.isDoneToday()).length;
    final learningTasks = _tasks.where((t) => t.category == TaskCategory.learning).toList();

    String streakSummary = _customStreaks.map((s) => '${s.titleEn}: ${s.daysCount} days').join(', ');
    String streakSummaryAr = _customStreaks.map((s) => '${s.titleAr}: ${s.daysCount} يوماً').join('، ');

    String prompt;
    if (_arabic) {
      prompt = '''
مرحباً يا ميلوس، أحتاج تحليلك الصادق والشامل لتقدمي اليوم:
- المهام المحددة لليوم: $todayDone مكتملة، $todayFailed فاشلة، من أصل ${todayTasks.length} (إجمالي الفاشلة: $totalFailed)
- المهام المتأخرة: $overdueCount
- سلسلة الإنجاز اليومية: $_streak يوم
- الصلوات اليومية: $prayersDone من أصل 5 (الإجمالي المسجل: $prayerSummary)
- سلاسل الالتزام: ${streakSummaryAr.isEmpty ? "لا توجد بعد" : streakSummaryAr}
- العادات المنجزة اليوم: $habitsDone من أصل ${_habits.length}
${learningTasks.isNotEmpty ? '- مسار المهارات والتعلم: ${learningTasks.map((t) => "${t.title} (${t.effectiveSkillProgress}%)").join(", ")}' : ''}
${focusMode != null ? '- التركيز المطلوب: $focusMode' : ''}

بصفتك حكيماً وموجهاً، قيّم التزامي اليوم وقدم لي نصائح عملية لما يجب التركيز عليه لتحسين وتيرة إنجازي.
''';
    } else {
      prompt = '''
Hello Milos, please give me a comprehensive and honest review of my progress today:
- Today's tasks: $todayDone completed, $todayFailed failed, out of ${todayTasks.length} (all-time failed: $totalFailed)
- Overdue tasks: $overdueCount
- Daily streak: $_streak days
- Daily prayers: $prayersDone of 5 (recorded totals: $prayerSummary)
- Custom streaks: ${streakSummary.isEmpty ? "None yet" : streakSummary}
- Habits completed today: $habitsDone of ${_habits.length}
${learningTasks.isNotEmpty ? '- Learning skills: ${learningTasks.map((t) => "${t.title} (${t.effectiveSkillProgress}%)").join(", ")}' : ''}
${focusMode != null ? '- Focus requested: $focusMode' : ''}

As my coach and mentor, evaluate my discipline and give me practical advice on how to improve and stay consistent.
''';
    }

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
    final todayFailed = todayTasks.where((t) => t.failed).length;
    final todayTotal = todayTasks.length;
    final overdueCount = _tasks.where((t) => !t.done && !t.failed && _isOverdue(t.remindAt)).length;
    final prayersDone = _prayerCounts.values.where((v) => v > 0).length;
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
              _buildMetricsOverview(todayDone, todayTotal, todayFailed, overdueCount, progressPct),
              const SizedBox(height: 18),

              // ─── 7-DAY CONSISTENCY CHART ─────────────────────────────────
              _buildWeekConsistencyCard(),
              const SizedBox(height: 18),

              // ─── LIFESTYLE & DISCIPLINE HIGHLIGHTS ───────────────────────
              _buildLifestyleHighlights(prayersDone),
              const SizedBox(height: 18),

              // ─── PRAYERS COUNT BREAKDOWN ─────────────────────────────────
              _buildPrayersSummaryCard(),
              const SizedBox(height: 18),

              // ─── LEARNING & SKILLS (FEAT-5 & Point 2) ────────────────────
              _buildLearningSection(learningTasks),
              const SizedBox(height: 18),
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
            'Ask Milos to review your tasks, prayers, habits, and skill progress to give you wise, actionable insights.',
            'اطلب من ميلوس مراجعة مهامك وصلواتك وسلاسل التزامك ليعطيك توجيهات حكيمة.',
          ),
          style: const TextStyle(fontSize: 12, color: Color(0xFFD6E8E3), height: 1.4),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            onPressed: () => _runAiAnalysis(),
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

  Widget _buildMetricsOverview(int done, int total, int failed, int overdue, int pct) => Container(
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
                title: _t('Failed', 'فشلت'),
                value: '$failed',
                color: failed > 0 ? const Color(0xFFE74C3C) : _muted,
                icon: Icons.cancel_rounded,
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

    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final dayCounts = List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      final dayTasks = _tasks.where(
        (t) => t.remindAt.year == d.year && t.remindAt.month == d.month && t.remindAt.day == d.day,
      );
      var done = 0;
      var failed = 0;
      var pending = 0;
      for (final t in dayTasks) {
        if (t.done) {
          done++;
        } else if (t.failed) {
          failed++;
        } else {
          pending++;
        }
      }
      return (done: done, failed: failed, pending: pending);
    });
    final weekDone = dayCounts.fold(0, (s, c) => s + c.done);
    final weekFailed = dayCounts.fold(0, (s, c) => s + c.failed);
    final weekPending = dayCounts.fold(0, (s, c) => s + c.pending);

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
                    height: 38,
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
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE9EFED)),
          const SizedBox(height: 12),
          SizedBox(
            height: 68,
            width: double.infinity,
            child: CustomPaint(
              painter: _WeeklyTasksPainter(dayCounts),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              'This week: $weekDone done · $weekFailed failed · $weekPending pending',
              'هذا الأسبوع: $weekDone مكتملة · $weekFailed فاشلة · $weekPending قيد الانتظار',
            ),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayersSummaryCard() => Container(
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
            const Icon(Icons.mosque_rounded, color: _teal, size: 20),
            const SizedBox(width: 8),
            Text(
              _t('Prayers Count', 'إحصائيات الصلوات'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
            ),
            const Spacer(),
            Text(
              _t('7d / Total', '٧ أيام / الإجمالي'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _muted),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < HabitStore.prayerNames.length; i++) ...[
          Builder(builder: (_) {
            final name = HabitStore.prayerNames[i];
            final label = _arabic ? HabitStore.prayerNamesAr[i] : name;
            final week = _weekPrayerTotals[name] ?? 0;
            final total = _allPrayerTotals[name] ?? 0;
            final ratio = (week / 7).clamp(0.0, 1.0);
            final extra = week > 7 ? week - 7 : 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 68,
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFEFF4F2),
                        valueColor: const AlwaysStoppedAnimation<Color>(_teal),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$week/7${extra > 0 ? " (+$extra)" : ""} · ×$total',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: extra > 0 ? const Color(0xFFE07A30) : _muted,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    ),
  );

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
          _t('Lifestyle & Streaks', 'نمط الحياة والسلاسل'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _highlightTile(
                icon: Icons.mosque_rounded,
                title: _t('Daily Prayers', 'الصلوات'),
                subtitle: '$prayersDone / 5',
                color: _teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _highlightTile(
                icon: Icons.local_fire_department_rounded,
                title: _t('Task Streak', 'سلسلة المهام'),
                subtitle: '$_streak ${_t("days", "يوماً")}',
                color: const Color(0xFFE07A30),
              ),
            ),
          ],
        ),
        if (_customStreaks.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE9EFED)),
          const SizedBox(height: 10),
          Text(
            _t('Active Habit Streaks', 'سلاسل العادات النشطة'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _customStreaks.map((s) {
              final title = _arabic ? s.titleAr : s.titleEn;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _paper,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2EBE8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded, size: 14, color: Color(0xFFE07A30)),
                    const SizedBox(width: 4),
                    Text(
                      '$title: ${s.daysCount} ${_t("d", "ي")}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            TextButton.icon(
              onPressed: _addNewSkill,
              icon: const Icon(Icons.add_rounded, size: 16, color: _teal),
              label: Text(
                _t('New Skill', 'مهارة جديدة'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _teal),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (learningTasks.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _t('No learning skills yet. Tap "New Skill" to start!', 'لا توجد مسارات مهارات بعد. اضغط "مهارة جديدة" للبدء!'),
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ),
          )
        else
          ...learningTasks.map((t) {
            final progress = t.effectiveSkillProgress;
            final pendingSteps = t.skillSteps.where((s) => !s.done).toList();
            final nextStep = pendingSteps.isNotEmpty ? pendingSteps.first : null;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _paper,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
                      Text('$progress%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _teal)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress / 100.0,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFE2EBE8),
                      valueColor: const AlwaysStoppedAnimation<Color>(_teal),
                    ),
                  ),
                  if (nextStep != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.next_plan_outlined, size: 14, color: _teal),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${_t("Next:", "التالي:")} ${nextStep.title}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    ),
  );
}

class _WeeklyTasksPainter extends CustomPainter {
  _WeeklyTasksPainter(this.days);
  final List<({int done, int failed, int pending})> days;

  @override
  void paint(Canvas canvas, Size size) {
    final maxTotal = days.fold<int>(1, (m, d) {
      final sum = d.done + d.failed + d.pending;
      return sum > m ? sum : m;
    });
    final slotW = size.width / 7;
    final barW = (slotW * 0.48).clamp(12.0, 26.0);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 7; i++) {
      final d = days[i];
      final total = d.done + d.failed + d.pending;
      final x = i * slotW + (slotW - barW) / 2;
      if (total == 0) {
        paint.color = const Color(0xFFEFF4F2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height - 6, barW, 6),
            const Radius.circular(3),
          ),
          paint,
        );
        continue;
      }

      var bottom = size.height;
      void drawSegment(int count, Color color) {
        if (count <= 0) return;
        final h = (count / maxTotal) * size.height;
        paint.color = color;
        canvas.drawRect(Rect.fromLTWH(x, bottom - h, barW, h), paint);
        bottom -= h;
      }

      drawSegment(d.done, _teal);
      drawSegment(d.failed, const Color(0xFFE74C3C));
      drawSegment(d.pending, const Color(0xFFDCE5E2));
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyTasksPainter old) => old.days != days;
}

