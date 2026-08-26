import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_palette.dart';
import '../../../core/widgets/empty_state.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _LocalTask {
  _LocalTask({required this.title, this.done = false, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime(2024);

  final String title;
  bool done;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {'title': title, 'done': done};
}

class _TasksScreenState extends State<TasksScreen> {
  final List<_LocalTask> _tasks = [];
  bool _loading = true;
  static const _storageKey = 'local_user_tasks';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_storageKey) ?? [];
      final loaded = raw
          .map((e) {
            final map = json.decode(e) as Map<String, dynamic>;
            return _LocalTask(title: map['title'] as String, done: map['done'] as bool);
          })
          .toList();
      if (!mounted) return;
      setState(() {
        _tasks
          ..clear()
          ..addAll(loaded);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _storageKey,
        _tasks.map((t) => json.encode(t.toJson())).toList(),
      );
    } catch (e) {
      debugPrint('Task persist error: $e');
    }
  }

  void _showAddTaskDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add Task', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. Service my bike',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppPalette.of(context).inputBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              setState(() => _tasks.add(_LocalTask(title: text)));
              Navigator.pop(dialogContext);
              _persist();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _toggle(_LocalTask task) {
    setState(() => task.done = !task.done);
    _persist();
  }

  void _delete(_LocalTask task) {
    setState(() => _tasks.remove(task));
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final pending = _tasks.where((t) => !t.done).toList();
    final completed = _tasks.where((t) => t.done).toList();

    return Scaffold(
      backgroundColor: palette.isDark ? AppColors.heroDarkBg : AppColors.scaffoldBg,
      appBar: AppBar(title: const Text('Tasks')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppColors.primaryPurple,
              onRefresh: _load,
              child: _tasks.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: EmptyState(
                            icon: Icons.task_alt_rounded,
                            title: 'No tasks yet.',
                            message: 'Keep track of maintenance, renewals and reminders for your belongings.',',
                            actionLabel: 'Add Task',
                            onAction: _showAddTaskDialog,
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                      children: [
                        if (pending.isNotEmpty) ...[
                          _sectionHeader(palette, 'Pending', pending.length),
                          ...pending.map((t) => _taskTile(palette, t, false)),
                          const SizedBox(height: 18),
                        ],
                        if (completed.isNotEmpty) ...[
                          _sectionHeader(palette, 'Completed', completed.length),
                          ...completed.map((t) => _taskTile(palette, t, true)),
                        ],
                      ],
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        backgroundColor: AppColors.primaryPurple,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Task',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _sectionHeader(AppPalette palette, String title, int count) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Row(
          children: [
            Text(title,
                style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w700, color: palette.onSurface)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withAlpha(18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count',
                  style: GoogleFonts.outfit(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryPurple)),
            ),
          ],
        ),
      );

  Widget _taskTile(AppPalette palette, _LocalTask task, bool done) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _toggle(task),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggle(task),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: done ? AppColors.success : Colors.transparent,
                      border: Border.all(
                        color: done ? AppColors.success : palette.controlBorder,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: done
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    task.title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.onSurface,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  onPressed: () => _delete(task),
                ),
              ],
            ),
          ),
        ),
      );
}
