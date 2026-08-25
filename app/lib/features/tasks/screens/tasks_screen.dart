import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final List<_LocalTask> _tasks = [];

  void _showAddTaskDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Add Task',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. Service my bike',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;

                setState(() {
                  _tasks.add(_LocalTask(title: text));
                });

                Navigator.pop(dialogContext);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _tasks.where((task) => !task.completed).toList();
    final completed = _tasks.where((task) => task.completed).toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        backgroundColor: AppColors.primaryPurple,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Add Task',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(
          'Tasks',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.task_alt_rounded,
                    size: 64,
                    color: AppColors.primaryPurple.withAlpha(150),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tasks yet',
                    style: GoogleFonts.outfit(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap + to create your first task.',
                    style: GoogleFonts.outfit(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                if (pending.isNotEmpty) ...[
                  _sectionTitle('To Do'),
                  ...pending.map(_taskTile),
                ],
                if (completed.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionTitle('Completed'),
                  ...completed.map(_taskTile),
                ],
              ],
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _taskTile(_LocalTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFEBF6)),
      ),
      child: ListTile(
        leading: Checkbox(
          value: task.completed,
          activeColor: AppColors.primaryPurple,
          onChanged: (value) {
            setState(() {
              task.completed = value ?? false;
            });
          },
        ),
        title: Text(
          task.title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            decoration: task.completed ? TextDecoration.lineThrough : null,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.error,
          ),
          onPressed: () {
            setState(() {
              _tasks.remove(task);
            });
          },
        ),
      ),
    );
  }
}

class _LocalTask {
  final String title;
  bool completed = false;

  _LocalTask({required this.title});
}
