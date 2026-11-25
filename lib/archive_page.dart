import 'package:flutter/material.dart';

import 'task.dart';

const _teal = Color(0xFF4CAF9E);
const _ink = Color(0xFF253533);
const _muted = Color(0xFF82908D);
const _paper = Color(0xFFF5F8F7);
const _red = Color(0xFFE74C3C);

/// Displays all tasks where task.done == true or task.failed == true.
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
    final failed = tasks.where((t) => t.failed).toList()
      ..sort((a, b) => b.remindAt.compareTo(a.remindAt));

    final isEmpty = done.isEmpty && failed.isEmpty;

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
      body: isEmpty
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              children: [
                // ── Done section ──
                if (done.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.check_circle_rounded,
                    label: _t('Completed', 'مكتملة'),
                    count: done.length,
                    color: _teal,
                  ),
                  const SizedBox(height: 8),
                  ...done.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ArchivedTaskCard(task: t, arabic: arabic),
                      )),
                ],
                // ── Failed section ──
                if (failed.isNotEmpty) ...[
                  if (done.isNotEmpty) const SizedBox(height: 10),
                  _SectionHeader(
                    icon: Icons.cancel_rounded,
                    label: _t('Failed', 'فشلت'),
                    count: failed.length,
                    color: _red,
                  ),
                  const SizedBox(height: 8),
                  ...failed.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ArchivedTaskCard(task: t, arabic: arabic, failed: true),
                      )),
                ],
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    ],
  );
}

class _ArchivedTaskCard extends StatelessWidget {
  const _ArchivedTaskCard({
    required this.task,
    required this.arabic,
    this.failed = false,
  });

  final Task task;
  final bool arabic;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final timeStr = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(task.remindAt),
    );
    final dateStr = _dateLabel(context, task.remindAt);
    final color = failed ? _red : _teal;
    final icon = failed ? Icons.cancel_rounded : Icons.check_circle_rounded;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: color, width: 3),
          right: BorderSide(color: const Color(0xFFE9EFED)),
          top: BorderSide(color: const Color(0xFFE9EFED)),
          bottom: BorderSide(color: const Color(0xFFE9EFED)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: failed ? _red : _muted,
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

