import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/custom_button.dart';
import '../models/task_model.dart';
import '../widgets/snooze_sheet.dart';
import '../widgets/task_priority_badge.dart';
import '../widgets/task_status_badge.dart';
import 'edit_task_screen.dart';

class TaskDetailsScreen extends StatefulWidget {
  final TaskModel task;

  const TaskDetailsScreen({
    super.key,
    required this.task,
  });

  static Future<void> navigateTo(BuildContext context, TaskModel task) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsScreen(task: task),
      ),
    );
  }

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  late TaskModel _task;
  final _taskService = serviceLocator.taskService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  Future<void> _completeTask() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'local_user';
    final uname = user?.displayName ?? user?.email?.split('@').first ?? 'Local User';

    setState(() => _isLoading = true);

    try {
      await _taskService.completeTask(
        _task,
        completedBy: uid,
        completedByName: uname,
      );

      final updatedTask = _task.copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime.now(),
        completedBy: uid,
        completedByName: uname,
      );

      if (mounted) {
        setState(() {
          _task = updatedTask;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task marked as completed!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorFormatter.format(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _snoozeTask() async {
    final snoozeTarget = await SnoozeSheet.show(context);
    if (snoozeTarget == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await _taskService.snoozeTask(_task, snoozeTarget);
      final updatedTask = _task.copyWith(snoozedUntil: snoozeTarget);

      if (mounted) {
        setState(() {
          _task = updatedTask;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Snoozed until ${DateFormat('MMM d, h:mm a').format(snoozeTarget)}',
            ),
            backgroundColor: AppColors.primaryPurple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorFormatter.format(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rescheduleTask() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _task.dueDate,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _task.dueTime != null
          ? TimeOfDay.fromDateTime(_task.dueTime!)
          : TimeOfDay.now(),
    );

    if (!mounted) return;

    DateTime? dueTime;
    if (time != null) {
      dueTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    setState(() => _isLoading = true);

    try {
      final updatedTask = _task.copyWith(
        dueDate: date,
        dueTime: dueTime,
        snoozedUntil: null,
      );

      await _taskService.updateTask(updatedTask);

      if (mounted) {
        setState(() {
          _task = updatedTask;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task rescheduled successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorFormatter.format(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Task?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This task and its scheduled notifications will be permanently removed.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await _taskService.deleteTask(_task);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task deleted.'),
            backgroundColor: AppColors.textSecondary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorFormatter.format(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatDateTime() {
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(_task.dueDate);
    if (_task.dueTime != null && !_task.isAllDay) {
      final timeStr = DateFormat('h:mm a').format(_task.dueTime!);
      return '$dateStr at $timeStr';
    }
    return '$dateStr (All-day)';
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = _task.status == TaskStatus.completed;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Task Details',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primaryPurple),
            onPressed: () async {
              await EditTaskScreen.navigateTo(context, _task);
              final fresh = await _taskService.getTask(_task.id);
              if (fresh != null && mounted) {
                setState(() => _task = fresh);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: _deleteTask,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                // Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(6),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _task.taskType.icon,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _task.taskType.label,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                          ),
                          TaskPriorityBadge(priority: _task.priority),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _task.title,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isCompleted
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (_task.description != null &&
                          _task.description!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          _task.description!,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TaskStatusBadge(task: _task),
                          if (_task.snoozedUntil != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple.withAlpha(20),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.snooze_rounded, size: 14, color: AppColors.primaryPurple),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Snoozed',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryPurple,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Asset Info Card (if associated)
                if (_task.assetName != null && _task.assetName!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primaryPurple.withAlpha(30)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.lightLavender,
                          child: Text(
                            _task.assetEmoji ?? '📦',
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Associated Asset',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _task.assetName!,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Schedule & Details List
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.calendar_today_rounded, color: AppColors.primaryPurple),
                        title: Text(
                          'Due Date & Time',
                          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        subtitle: Text(
                          _formatDateTime(),
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _task.isOverdue ? AppColors.error : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: Icon(
                          _task.reminderEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                          color: _task.reminderEnabled ? AppColors.primaryPurple : AppColors.textMuted,
                        ),
                        title: Text(
                          'Reminder',
                          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        subtitle: Text(
                          _task.reminderEnabled
                              ? '${_task.reminderMinutesBefore} minutes before'
                              : 'Disabled',
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.repeat_rounded, color: AppColors.primaryPurple),
                        title: Text(
                          'Repeat',
                          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        subtitle: Text(
                          _task.repeatType.label,
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_task.createdByName != null && _task.createdByName!.isNotEmpty) ...[
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: const Icon(Icons.person_outline_rounded, color: AppColors.primaryPurple),
                          title: Text(
                            'Created By',
                            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          subtitle: Text(
                            _task.createdByName!,
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      if (_task.assignedToName != null && _task.assignedToName!.isNotEmpty) ...[
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: const Icon(Icons.assignment_ind_outlined, color: AppColors.primaryPurple),
                          title: Text(
                            'Assigned To',
                            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          subtitle: Text(
                            _task.assignedToName!,
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      if (isCompleted && _task.completedAt != null) ...[
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: const Icon(Icons.check_circle_rounded, color: AppColors.success),
                          title: Text(
                            'Completed Information',
                            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          subtitle: Text(
                            'Completed on ${DateFormat('MMM d, yyyy • h:mm a').format(_task.completedAt!)}${_task.completedByName != null ? ' by ${_task.completedByName}' : ''}',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.success),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Action Buttons
                if (!isCompleted) ...[
                  GradientButton(
                    text: 'Mark as Completed',
                    icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                    onPressed: _completeTask,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _snoozeTask,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.snooze_rounded, size: 18),
                          label: const Text('Snooze'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _rescheduleTask,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                          label: const Text('Reschedule'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}
