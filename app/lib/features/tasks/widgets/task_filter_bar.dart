import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

enum TaskFilterOption {
  all('All'),
  today('Today'),
  upcoming('Upcoming'),
  overdue('Overdue'),
  assignedToMe('Assigned to Me'),
  createdByMe('Created by Me'),
  completed('Completed');

  final String label;
  const TaskFilterOption(this.label);
}

class TaskFilterBar extends StatelessWidget {
  final TaskFilterOption selectedFilter;
  final ValueChanged<TaskFilterOption> onFilterSelected;

  const TaskFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: TaskFilterOption.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = TaskFilterOption.values[index];
          final isSelected = option == selectedFilter;

          return ChoiceChip(
            label: Text(
              option.label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.primaryPurple,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected ? AppColors.primaryPurple : const Color(0xFFE5E2F0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onSelected: (_) => onFilterSelected(option),
          );
        },
      ),
    );
  }
}
