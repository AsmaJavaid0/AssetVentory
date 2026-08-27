import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../models/task_model.dart';

class TaskStatusBadge extends StatelessWidget {
  final TaskModel task;
  final bool compact;

  const TaskStatusBadge({
    super.key,
    required this.task,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label;
    IconData icon;

    if (task.isOverdue) {
      bg = AppColors.error.withAlpha(25);
      text = AppColors.error;
      label = 'Overdue';
      icon = Icons.error_outline_rounded;
    } else {
      switch (task.status) {
        case TaskStatus.pending:
          bg = AppColors.warning.withAlpha(25);
          text = AppColors.warning;
          label = 'Pending';
          icon = Icons.schedule_rounded;
          break;
        case TaskStatus.inProgress:
          bg = AppColors.info.withAlpha(25);
          text = AppColors.info;
          label = 'In Progress';
          icon = Icons.autorenew_rounded;
          break;
        case TaskStatus.completed:
          bg = AppColors.success.withAlpha(25);
          text = AppColors.success;
          label = 'Completed';
          icon = Icons.check_circle_outline_rounded;
          break;
        case TaskStatus.cancelled:
          bg = AppColors.textMuted.withAlpha(25);
          text = AppColors.textMuted;
          label = 'Cancelled';
          icon = Icons.cancel_outlined;
          break;
      }
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: text),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: text,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: text.withAlpha(50), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: text),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}
