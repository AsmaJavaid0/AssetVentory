import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/task_model.dart';

class TaskPriorityBadge extends StatelessWidget {
  final TaskPriority priority;
  final bool compact;

  const TaskPriorityBadge({
    super.key,
    required this.priority,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    IconData icon;

    switch (priority) {
      case TaskPriority.low:
        bg = const Color(0xFFE0E7FF);
        text = const Color(0xFF3730A3);
        icon = Icons.arrow_downward_rounded;
        break;
      case TaskPriority.medium:
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFF92400E);
        icon = Icons.remove_rounded;
        break;
      case TaskPriority.high:
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFF991B1B);
        icon = Icons.arrow_upward_rounded;
        break;
      case TaskPriority.urgent:
        bg = const Color(0xFF7F1D1D);
        text = Colors.white;
        icon = Icons.priority_high_rounded;
        break;
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: text),
            const SizedBox(width: 3),
            Text(
              priority.label,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: text),
          const SizedBox(width: 4),
          Text(
            priority.label,
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
