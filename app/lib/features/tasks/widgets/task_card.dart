import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../models/task_model.dart';
import 'task_priority_badge.dart';
import 'task_status_badge.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;
  final ValueChanged<bool?>? onToggleCompleted;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    this.onToggleCompleted,
  });

  Color _getPriorityColor() {
    switch (task.priority) {
      case TaskPriority.low:
        return Colors.blue;
      case TaskPriority.medium:
        return AppColors.warning;
      case TaskPriority.high:
        return Colors.orange;
      case TaskPriority.urgent:
        return AppColors.error;
    }
  }

  String _formatDueDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final taskDay = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);

    String dateStr;
    if (taskDay == today) {
      dateStr = 'Today';
    } else if (taskDay == tomorrow) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = DateFormat('MMM d, yyyy').format(task.dueDate);
    }

    if (task.dueTime != null && !task.isAllDay) {
      final timeStr = DateFormat('h:mm a').format(task.dueTime!);
      return '$dateStr • $timeStr';
    }

    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == TaskStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: task.isOverdue
              ? AppColors.error.withAlpha(80)
              : const Color(0xFFEFEBF6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Priority strip indicator
              Container(
                width: 5,
                color: isCompleted ? AppColors.success : _getPriorityColor(),
              ),
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              task.taskType.icon,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                task.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isCompleted
                                      ? AppColors.textMuted
                                      : AppColors.textPrimary,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            if (onToggleCompleted != null) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: isCompleted,
                                  activeColor: AppColors.primaryPurple,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  onChanged: onToggleCompleted,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (task.assetName != null && task.assetName!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                task.assetEmoji ?? '📦',
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  task.assetName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: task.isOverdue
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDueDate(),
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: task.isOverdue
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                                fontWeight: task.isOverdue
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            const Spacer(),
                            TaskPriorityBadge(
                              priority: task.priority,
                              compact: true,
                            ),
                            const SizedBox(width: 6),
                            TaskStatusBadge(
                              task: task,
                              compact: true,
                            ),
                          ],
                        ),
                        if (task.assignedToName != null &&
                            task.assignedToName!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 13,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Assigned to: ${task.assignedToName}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
