import 'package:flutter/material.dart';

import 'habit_store.dart';

const _teal = Color(0xFF4CAF9E);
const _ink = Color(0xFF253533);
const _muted = Color(0xFF82908D);
const _paper = Color(0xFFF5F8F7);

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key, required this.arabic});
  final bool arabic;

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  bool get _arabic => widget.arabic;
  String _t(String en, String ar) => _arabic ? ar : en;

  Map<String, bool> _prayers = {};
  List<StreakTracker> _customStreaks = [];
  List<HabitItem> _habits = [];
  List<HabitNote> _notes = [];
  bool _loading = true;

  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final prayers = await HabitStore.loadPrayers();
    final streaks = await HabitStore.loadCustomStreaks();
    final habits = await HabitStore.loadCustomHabits();
    final notes = await HabitStore.loadNotes();
    if (mounted) {
      setState(() {
        _prayers = prayers;
        _customStreaks = streaks;
        _habits = habits;
        _notes = notes;
        _loading = false;
      });
    }
  }

  Future<void> _togglePrayer(String prayer) async {
    await HabitStore.togglePrayer(prayer);
    final fresh = await HabitStore.loadPrayers();
    if (mounted) setState(() => _prayers = fresh);
  }

  Future<void> _addStreakDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('New streak tracker', 'إضافة سلسلة جديدة')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: _t('e.g. No Smoking, Cold Shower, No Sugar', 'مثال: الامتناع عن التدخين، الاستحمام بماء بارد'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('Cancel', 'إلغاء')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _teal),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(_t('Add', 'إضافة')),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await HabitStore.addCustomStreak(result, result);
      final fresh = await HabitStore.loadCustomStreaks();
      if (mounted) setState(() => _customStreaks = fresh);
    }
  }

  Future<void> _resetStreak(StreakTracker streak) async {
    final title = _arabic ? streak.titleAr : streak.titleEn;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Reset streak?', 'إعادة تعيين السلسلة؟')),
        content: Text(
          _t(
            'Are you sure you want to reset "$title"?',
            'هل أنت متأكد من رغبتك في إعادة تعيين سلسلة "$title"؟',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('Cancel', 'إلغاء')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC36E36)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('Reset', 'إعادة تعيين')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await HabitStore.resetCustomStreak(streak.id);
      final fresh = await HabitStore.loadCustomStreaks();
      if (mounted) setState(() => _customStreaks = fresh);
    }
  }

  Future<void> _deleteStreak(String id) async {
    await HabitStore.deleteCustomStreak(id);
    final fresh = await HabitStore.loadCustomStreaks();
    if (mounted) setState(() => _customStreaks = fresh);
  }

  Future<void> _toggleHabit(String id) async {
    await HabitStore.toggleHabitDone(id);
    final habits = await HabitStore.loadCustomHabits();
    if (mounted) setState(() => _habits = habits);
  }

  Future<void> _addCustomHabitDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('New habit', 'عادة جديدة')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: _t('e.g. Read 15 mins', 'مثال: قراءة ربع ساعة'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('Cancel', 'إلغاء')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _teal),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(_t('Add', 'إضافة')),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await HabitStore.addCustomHabit(result, result);
      final habits = await HabitStore.loadCustomHabits();
      if (mounted) setState(() => _habits = habits);
    }
  }

  Future<void> _deleteHabit(String id) async {
    await HabitStore.deleteCustomHabit(id);
    final habits = await HabitStore.loadCustomHabits();
    if (mounted) setState(() => _habits = habits);
  }

  Future<void> _addNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;
    _noteController.clear();
    FocusScope.of(context).unfocus();
    await HabitStore.addNote(text);
    final notes = await HabitStore.loadNotes();
    if (mounted) setState(() => _notes = notes);
  }

  Future<void> _deleteNote(String id) async {
    await HabitStore.deleteNote(id);
    final notes = await HabitStore.loadNotes();
    if (mounted) setState(() => _notes = notes);
  }

  int get _prayersCompleted => _prayers.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _paper,
        body: Center(child: CircularProgressIndicator(color: _teal)),
      );
    }

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
                _t('Lifestyle & Habits', 'نمط الحياة والعادات'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _t('Nurture discipline and consistency daily.', 'حافظ على الانضباط والالتزام يومياً.'),
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
              const SizedBox(height: 20),

              // ─── PRAYER TRACKER ──────────────────────────────────────────
              _buildPrayerCard(),
              const SizedBox(height: 18),

              // ─── CUSTOM STREAK TRACKERS ──────────────────────────────────
              _buildCustomStreaksSection(),
              const SizedBox(height: 18),

              // ─── CUSTOM HABITS ───────────────────────────────────────────
              _buildHabitsSection(),
              const SizedBox(height: 18),

              // ─── LIFESTYLE NOTES & REFLECTIONS ───────────────────────────
              _buildNotesSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerCard() => Container(
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.mosque_rounded, color: _teal, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Daily Prayers', 'الصلوات الخمس'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  Text(
                    '$_prayersCompleted / 5 ${_t('completed today', 'مكتملة اليوم')}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _prayersCompleted == 5 ? _teal : _muted,
                    ),
                  ),
                ],
              ),
            ),
            if (_prayersCompleted == 5)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: _teal),
                    const SizedBox(width: 4),
                    Text(
                      _t('All done', 'اكتملت'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _teal,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(5, (i) {
            final name = HabitStore.prayerNames[i];
            final nameAr = HabitStore.prayerNamesAr[i];
            final done = _prayers[name] == true;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == 4 ? 0 : 6,
                  left: i == 0 ? 0 : 6,
                ),
                child: GestureDetector(
                  onTap: () => _togglePrayer(name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: done ? _teal : _paper,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: done ? _teal : const Color(0xFFE2EBE8),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          done ? Icons.check_circle_rounded : Icons.circle_outlined,
                          size: 16,
                          color: done ? Colors.white : _muted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _arabic ? nameAr : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: done ? Colors.white : _ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    ),
  );

  Widget _buildCustomStreaksSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _t('Streak Trackers', 'سلاسل الالتزام'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          TextButton.icon(
            onPressed: _addStreakDialog,
            icon: const Icon(Icons.add_rounded, size: 16, color: _teal),
            label: Text(
              _t('Add Streak', 'إضافة سلسلة'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _teal,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (_customStreaks.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9EFED)),
          ),
          child: Center(
            child: Text(
              _t('No streak trackers yet. Tap "Add Streak" to create one!', 'لا توجد سلاسل بعد. اضغط "إضافة سلسلة" لإنشاء واحدة!'),
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ),
        )
      else
        ..._customStreaks.map((streak) {
          final title = _arabic ? streak.titleAr : streak.titleEn;
          final count = streak.daysCount;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE9EFED)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4EC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFE07A30),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        count == 0
                            ? _t('Day 0 — every journey starts today!', 'اليوم 0 — البداية تصنع الفارق!')
                            : _t('$count days clean and strong 🔥', '$count يوماً من الالتزام القوي 🔥'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE07A30),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _t('Reset streak', 'إعادة تعيين'),
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: _muted),
                  onPressed: () => _resetStreak(streak),
                ),
                IconButton(
                  tooltip: _t('Delete', 'حذف'),
                  icon: const Icon(Icons.close_rounded, size: 18, color: _muted),
                  onPressed: () => _deleteStreak(streak.id),
                ),
              ],
            ),
          );
        }),
    ],
  );

  Widget _buildHabitsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _t('Daily Habits', 'العادات اليومية'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          TextButton.icon(
            onPressed: _addCustomHabitDialog,
            icon: const Icon(Icons.add_rounded, size: 16, color: _teal),
            label: Text(
              _t('Add Habit', 'إضافة عادة'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _teal,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (_habits.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9EFED)),
          ),
          child: Center(
            child: Text(
              _t('No habits added yet.', 'لم تضف عادات بعد.'),
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ),
        )
      else
        ..._habits.map((habit) {
          final isDone = habit.isDoneToday();
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE9EFED)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleHabit(habit.id),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? _teal : Colors.transparent,
                      border: Border.all(
                        color: isDone ? _teal : const Color(0xFFB8C7C2),
                        width: 1.5,
                      ),
                    ),
                    child: isDone
                        ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _arabic ? habit.titleAr : habit.titleEn,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDone ? _muted : _ink,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (habit.streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4EC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '🔥 ${habit.streak}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE07A30),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16, color: _muted),
                  onPressed: () => _deleteHabit(habit.id),
                ),
              ],
            ),
          );
        }),
    ],
  );

  Widget _buildNotesSection() => Container(
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
            const Icon(Icons.edit_note_rounded, color: _teal, size: 22),
            const SizedBox(width: 8),
            Text(
              _t('Lifestyle Notes & Reflections', 'ملاحظات وتأملات اليوم'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: _t('Write a note or reflection…', 'اكتب ملاحظة أو فكرة…'),
                  filled: true,
                  fillColor: _paper,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _addNote(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: _teal),
              icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
              onPressed: _addNote,
            ),
          ],
        ),
        if (_notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE9EFED)),
          const SizedBox(height: 8),
          ..._notes.take(5).map((note) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.circle, size: 6, color: _teal),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.text,
                        style: const TextStyle(fontSize: 13, color: _ink),
                      ),
                      Text(
                        '${note.date.hour.toString().padLeft(2, '0')}:${note.date.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 10, color: _muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: _muted),
                  onPressed: () => _deleteNote(note.id),
                ),
              ],
            ),
          )),
        ],
      ],
    ),
  );
}
