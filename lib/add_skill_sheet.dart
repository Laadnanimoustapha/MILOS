import 'package:flutter/material.dart';

import 'task.dart';

const _teal = Color(0xFF4CAF9E);
const _ink = Color(0xFF253533);
const _muted = Color(0xFF82908D);
const _paper = Color(0xFFF5F8F7);

class AddSkillSheet extends StatefulWidget {
  const AddSkillSheet({super.key, required this.arabic});
  final bool arabic;

  @override
  State<AddSkillSheet> createState() => _AddSkillSheetState();
}

class _AddSkillSheetState extends State<AddSkillSheet> {
  final _titleController = TextEditingController();
  final _stepTitleController = TextEditingController();

  DateTime _stepDate = DateTime.now();
  TimeOfDay _from = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _until = const TimeOfDay(hour: 10, minute: 30);
  TaskScheduleMode _scheduleMode = TaskScheduleMode.range;
  TaskImportance _importance = TaskImportance.necessary;
  final int _superReminderIntervalMinutes = 15;

  final List<SkillStep> _steps = [];
  String? _error;

  bool get _arabic => widget.arabic;
  String _t(String en, String ar) => _arabic ? ar : en;

  @override
  void dispose() {
    _titleController.dispose();
    _stepTitleController.dispose();
    super.dispose();
  }

  void _addStep() {
    final title = _stepTitleController.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _steps.add(SkillStep(
        title: title,
        date: DateTime(_stepDate.year, _stepDate.month, _stepDate.day),
      ));
      _stepTitleController.clear();
      // Auto-advance default date for next step by 2 days
      _stepDate = _stepDate.add(const Duration(days: 2));
      _error = null;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickStepDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _stepDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _stepDate = picked);
  }

  Future<void> _pickTime({required bool start}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showTimePicker(
      context: context,
      initialTime: start || _scheduleMode == TaskScheduleMode.fixed ? _from : _until,
    );
    if (selected != null) {
      setState(() {
        if (start) {
          _from = selected;
          if (_scheduleMode == TaskScheduleMode.fixed) _until = selected;
        } else {
          _until = selected;
        }
      });
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _saveSkill() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = _t('Please give your skill a name.', 'يرجى كتابة اسم للمهارة أولاً.'));
      return;
    }
    if (_steps.isEmpty) {
      setState(() => _error = _t('Please add at least one step with a date.', 'يرجى إضافة خطوة واحدة على الأقل مع تاريخها.'));
      return;
    }

    final firstStepDate = _steps.first.date;
    final startAt = DateTime(
      firstStepDate.year,
      firstStepDate.month,
      firstStepDate.day,
      _from.hour,
      _from.minute,
    );
    final endAt = _scheduleMode == TaskScheduleMode.fixed
        ? startAt
        : DateTime(
            firstStepDate.year,
            firstStepDate.month,
            firstStepDate.day,
            _until.hour,
            _until.minute,
          );

    final task = Task(
      id: 0,
      title: title,
      remindAt: startAt,
      remindUntil: endAt,
      importance: _importance,
      superReminderIntervalMinutes: _superReminderIntervalMinutes,
      scheduleMode: _scheduleMode,
      category: TaskCategory.learning,
      skillSteps: _steps,
      steps: _steps.map((s) => s.title).toList(),
      skillProgress: 0,
    );

    Navigator.of(context).pop(task);
  }

  String _dateLabel(DateTime date) {
    if (!_arabic) {
      return MaterialLocalizations.of(context).formatMediumDate(date);
    }
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'ماي', 'يونيو',
      'يوليو', 'غشت', 'شتنبر', 'أكتوبر', 'نونبر', 'دجنبر',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.94,
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
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.school_rounded, color: _teal, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t('Create Learning Skill', 'إنشاء مهارة جديدة'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                              Text(
                                _t('Break learning into dated milestone steps.', 'قسّم تعلم المهارة إلى خطوات وتواريخ محددة.'),
                                style: const TextStyle(fontSize: 12, color: _muted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE9EFED)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Skill Title
                        _label(_t('SKILL NAME', 'اسم المهارة')),
                        const SizedBox(height: 7),
                        TextField(
                          controller: _titleController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: _t('e.g. Flutter Development, French, Guitar', 'مثال: تعلم فلاتر، اللغة الإنجليزية، العزف'),
                            filled: true,
                            fillColor: _paper,
                            prefixIcon: const Icon(Icons.menu_book_rounded, color: _teal),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Priority / Importance
                        _label(_t('PRIORITY & REMINDERS', 'الأولوية وتكرار التذكير')),
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
                                  child: Material(
                                    color: _importance == priority
                                        ? const Color(0xFFDDF2ED)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => setState(() => _importance = priority),
                                      child: SizedBox(
                                        height: 44,
                                        child: Center(
                                          child: Text(
                                            switch (priority) {
                                              TaskImportance.normal => _t('Normal', 'عادية'),
                                              TaskImportance.necessary => _t('Important', 'مهمة'),
                                              TaskImportance.superNecessary => _t('High Priority', 'عالية جداً'),
                                            },
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _importance == priority ? _teal : _muted,
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
                        const SizedBox(height: 18),

                        // Reminder window mode
                        _label(_t('PRACTICE TIME MODE', 'نمط وقت الممارسة')),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _choicePill(
                                title: _t('Time Range', 'فترة زمنية'),
                                selected: _scheduleMode == TaskScheduleMode.range,
                                onTap: () => setState(() => _scheduleMode = TaskScheduleMode.range),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _choicePill(
                                title: _t('Exact Time', 'وقت محدد'),
                                selected: _scheduleMode == TaskScheduleMode.fixed,
                                onTap: () => setState(() => _scheduleMode = TaskScheduleMode.fixed),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Time pickers
                        if (_scheduleMode == TaskScheduleMode.range)
                          Row(
                            children: [
                              Expanded(
                                child: _pickerTile(
                                  label: _t('FROM', 'من'),
                                  time: _from.format(context),
                                  onTap: () => _pickTime(start: true),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _pickerTile(
                                  label: _t('UNTIL', 'إلى'),
                                  time: _until.format(context),
                                  onTap: () => _pickTime(start: false),
                                ),
                              ),
                            ],
                          )
                        else
                          _pickerTile(
                            label: _t('PRACTICE AT', 'وقت الممارسة'),
                            time: _from.format(context),
                            onTap: () => _pickTime(start: true),
                          ),
                        const SizedBox(height: 22),

                        // Milestone Steps
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _label(_t('SKILL MILESTONE STEPS', 'خطوات ومراحل المهارة')),
                            Text(
                              '${_steps.length} ${_t("steps", "خطوات")}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _teal),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Add step box
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _paper,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2EBE8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _stepTitleController,
                                decoration: InputDecoration(
                                  hintText: _t('Step title (e.g. Build UI layout)', 'عنوان الخطوة (مثال: بناء الواجهة)'),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onSubmitted: (_) => _addStep(),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: _pickStepDate,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.event_rounded, size: 16, color: _teal),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _dateLabel(_stepDate),
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _teal,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    onPressed: _addStep,
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    label: Text(_t('Add Step', 'إضافة')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Existing steps list
                        if (_steps.isNotEmpty)
                          ..._steps.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final step = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE9EFED)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: const Color(0xFFE8F5F2),
                                    child: Text(
                                      '${idx + 1}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _teal),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          step.title,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink),
                                        ),
                                        Text(
                                          _dateLabel(step.date),
                                          style: const TextStyle(fontSize: 11, color: _muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 16, color: _muted),
                                    onPressed: () => setState(() => _steps.removeAt(idx)),
                                  ),
                                ],
                              ),
                            );
                          }),

                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFC36E36), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Submit button
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE9EFED))),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _saveSkill,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        _t('Save Skill Track', 'حفظ مسار المهارة'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 10,
      letterSpacing: 1.1,
      fontWeight: FontWeight.w800,
      color: _muted,
    ),
  );

  Widget _choicePill({required String title, required bool selected, required VoidCallback onTap}) => Material(
    color: selected ? const Color(0xFFDDF2ED) : _paper,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? _teal : _muted,
          ),
        ),
      ),
    ),
  );

  Widget _pickerTile({required String label, required String time, required VoidCallback onTap}) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _muted)),
          const SizedBox(height: 2),
          Text(time, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
        ],
      ),
    ),
  );
}
