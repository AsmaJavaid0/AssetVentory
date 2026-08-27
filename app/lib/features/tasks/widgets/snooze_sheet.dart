import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

class SnoozeSheet extends StatelessWidget {
  const SnoozeSheet({super.key});

  static Future<DateTime?> show(BuildContext context) {
    return showModalBottomSheet<DateTime?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const SnoozeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final options = [
      {
        'label': '10 Minutes',
        'subtitle': 'In 10 minutes',
        'target': now.add(const Duration(minutes: 10)),
        'icon': Icons.timer_outlined,
      },
      {
        'label': '30 Minutes',
        'subtitle': 'In 30 minutes',
        'target': now.add(const Duration(minutes: 30)),
        'icon': Icons.timer_outlined,
      },
      {
        'label': '1 Hour',
        'subtitle': 'In 1 hour',
        'target': now.add(const Duration(hours: 1)),
        'icon': Icons.access_time_rounded,
      },
      {
        'label': 'Tomorrow Morning',
        'subtitle': 'Tomorrow at 9:00 AM',
        'target': DateTime(now.year, now.month, now.day + 1, 9, 0),
        'icon': Icons.wb_sunny_outlined,
      },
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              'Snooze Task',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ...options.map((opt) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  opt['icon'] as IconData,
                  color: AppColors.primaryPurple,
                  size: 22,
                ),
              ),
              title: Text(
                opt['label'] as String,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                opt['subtitle'] as String,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () => Navigator.pop(context, opt['target'] as DateTime),
            );
          }),
          const Divider(height: 1, indent: 20, endIndent: 20),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primaryBlue,
                size: 22,
              ),
            ),
            title: Text(
              'Pick Date & Time',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Choose a custom date and time',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: now.add(const Duration(days: 1)),
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
              );
              if (date == null || !context.mounted) return;

              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (time == null || !context.mounted) return;

              final result = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
              Navigator.pop(context, result);
            },
          ),
        ],
      ),
    );
  }
}
