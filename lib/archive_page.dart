import 'package:flutter/material.dart';

import 'task.dart';

const _teal = Color(0xFF4CAF9E);
const _ink = Color(0xFF253533);
const _muted = Color(0xFF82908D);
const _paper = Color(0xFFF5F8F7);

/// Displays all tasks where task.done == true.
/// Reached via Navigator.push from TodayPage.
class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key, required this.tasks, required this.arabic});

  final List<Task> tasks;
  final bool arabic;

  String _t(String en, String ar) => arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.done).toList()
      ..sort((a, b) => b.remindAt.compareTo(a.remindAt));

    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _t('Archive', 'الأرشيف'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE9EFED)),
        ),
      ),
      body: done.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    color: _teal,
                    size: 36,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _t('No completed tasks yet.', 'لا توجد مهام مكتملة بعد.'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t(
                      'Completed tasks will appear here.',
                      'ستظهر المهام المكتملة هنا.',
                    ),
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              itemCount: done.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _ArchivedTaskCard(
                task: done[i],
                arabic: arabic,
              ),
            ),
    );
  }
}

class _ArchivedTaskCard extends StatelessWidget {
  const _ArchivedTaskCard({required this.task, required this.arabic});

  final Task task;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final timeStr = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(task.remindAt),
    );
    final dateStr = _dateLabel(context, task.remindAt);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EFED)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: _teal,
            size: 22,
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$dateStr · $timeStr',
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(BuildContext context, DateTime date) {
    if (!arabic) {
      return MaterialLocalizations.of(context).formatMediumDate(date);
    }
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'ماي', 'يونيو',
      'يوليو', 'غشت', 'شتنبر', 'أكتوبر', 'نونبر', 'دجنبر',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
