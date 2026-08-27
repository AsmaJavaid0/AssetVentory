import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../tasks/models/task_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _taskService = serviceLocator.taskService;

  @override
  Widget build(BuildContext context) {
    final uid = _taskService.currentUserId;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: _taskService.streamVisibleTasks(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final tasks = [...(snapshot.data ?? const <TaskModel>[])]
            ..removeWhere((t) => t.status == TaskStatus.completed || t.status == TaskStatus.cancelled)
            ..sort((a, b) => a.effectiveDueDateTime.compareTo(b.effectiveDueDateTime));

          if (tasks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: AppColors.primaryPurple.withAlpha(18), shape: BoxShape.circle),
                      child: const Icon(Icons.notifications_none_rounded, size: 42, color: AppColors.primaryPurple),
                    ),
                    const SizedBox(height: 16),
                    Text('You\'re all caught up', style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('New task reminders and alerts will appear here.', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) => _notificationCard(tasks[index]),
          );
        },
      ),
    );
  }

  Widget _notificationCard(TaskModel task) {
    final overdue = task.isOverdue;
    final date = task.effectiveDueDateTime;
    final dateText = overdue
        ? 'Overdue'
        : task.isDueToday
            ? 'Today${task.dueTime == null ? '' : ' • ${_time(date)}'}'
            : '${_month(date.month)} ${date.day}${task.dueTime == null ? '' : ' • ${_time(date)}'}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: overdue ? AppColors.error.withAlpha(70) : const Color(0xFFEEEAF5)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Text(task.taskType.icon, style: const TextStyle(fontSize: 21)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text(dateText, style: GoogleFonts.outfit(fontSize: 11, color: overdue ? AppColors.error : AppColors.textSecondary, fontWeight: FontWeight.w600)),
                if (task.assetName != null && task.assetName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(task.assetName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _time(DateTime value) {
    final hour = value.hour == 0 ? 12 : value.hour > 12 ? value.hour - 12 : value.hour;
    return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _month(int month) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month];
}
