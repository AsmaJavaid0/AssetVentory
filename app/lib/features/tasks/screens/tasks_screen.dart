import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../family/models/family_model.dart';
import '../models/task_model.dart';
import '../widgets/task_card.dart';
import '../widgets/task_empty_state.dart';
import '../widgets/task_filter_bar.dart';
import 'create_task_screen.dart';
import 'task_details_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _taskService = serviceLocator.taskService;
  final _familyRepository = serviceLocator.familyRepository;
  TaskFilterOption _selectedFilter = TaskFilterOption.all;
  String _searchQuery = '';
  bool _isSearching = false;
  final _searchController = TextEditingController();
  FamilyModel? _userFamily;

  @override
  void initState() {
    super.initState();
    _loadFamilyInfo();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFamilyInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final family = await _familyRepository.getUserFamily(user.uid);
        if (mounted) setState(() => _userFamily = family);
      } catch (_) {}
    }
  }

  List<TaskModel> _filterAndSearchTasks(List<TaskModel> tasks, String uid) {
    var result = tasks;
    switch (_selectedFilter) {
      case TaskFilterOption.all:
        result = result
            .where(
              (t) =>
                  t.status != TaskStatus.completed &&
                  t.status != TaskStatus.cancelled,
            )
            .toList();
        break;
      case TaskFilterOption.today:
        result = result
            .where((t) => t.isDueToday && t.status != TaskStatus.completed)
            .toList();
        break;
      case TaskFilterOption.upcoming:
        result = result
            .where(
              (t) =>
                  _isUpcomingForDisplay(t) &&
                  !t.isOverdue &&
                  t.status != TaskStatus.completed,
            )
            .toList();
        break;
      case TaskFilterOption.overdue:
        result = result
            .where((t) => t.isOverdue && t.status != TaskStatus.completed)
            .toList();
        break;
      case TaskFilterOption.assignedToMe:
        result = result
            .where((t) => t.assignedTo == uid && t.createdBy != uid)
            .toList();
        break;
      case TaskFilterOption.createdByMe:
        result = result.where((t) => t.createdBy == uid).toList();
        break;
      case TaskFilterOption.completed:
        result = result.where((t) => t.status == TaskStatus.completed).toList();
        break;
    }
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      result = result
          .where(
            (t) =>
                t.title.toLowerCase().contains(query) ||
                (t.description?.toLowerCase().contains(query) ?? false) ||
                (t.assetName?.toLowerCase().contains(query) ?? false),
          )
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid ?? 'local_user';
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      floatingActionButton: _buildTaskActions(context),
      body: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),
          TaskFilterBar(
            selectedFilter: _selectedFilter,
            onFilterSelected: (filter) =>
                setState(() => _selectedFilter = filter),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<TaskModel>>(
              stream: _taskService.streamVisibleTasks(
                uid,
                familyId: _userFamily?.id,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const TaskEmptyState(
                    title: 'Unable to load tasks',
                    message:
                        'Your personal tasks are stored on this device. Family tasks require an available family connection.',
                    icon: Icons.error_outline_rounded,
                  );
                }
                final displayTasks = _filterAndSearchTasks(
                  snapshot.data ?? [],
                  uid,
                );
                if (displayTasks.isEmpty) return _buildEmptyState();
                final overdue = displayTasks.where((t) => t.isOverdue).toList();
                final today = displayTasks
                    .where((t) => t.isDueToday && !t.isOverdue)
                    .toList();
                final upcoming = displayTasks
                    .where((t) => _isUpcomingForDisplay(t) && !t.isOverdue)
                    .toList();
                final other = displayTasks
                    .where(
                      (t) =>
                          !overdue.contains(t) &&
                          !today.contains(t) &&
                          !upcoming.contains(t),
                    )
                    .toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
                  children: [
                    if (overdue.isNotEmpty) ...[
                      _buildSectionHeader(
                        '🔴 Overdue',
                        overdue.length,
                        color: AppColors.error,
                      ),
                      ...overdue.map(_buildTaskTile),
                      const SizedBox(height: 16),
                    ],
                    if (today.isNotEmpty) ...[
                      _buildSectionHeader('📅 Today', today.length),
                      ...today.map(_buildTaskTile),
                      const SizedBox(height: 16),
                    ],
                    if (upcoming.isNotEmpty) ...[
                      _buildSectionHeader('⏰ Upcoming', upcoming.length),
                      ...upcoming.map(_buildTaskTile),
                      const SizedBox(height: 16),
                    ],
                    if (other.isNotEmpty) ...[
                      _buildSectionHeader(
                        _selectedFilter == TaskFilterOption.completed
                            ? '✅ Completed'
                            : '📋 Tasks',
                        other.length,
                      ),
                      ...other.map(_buildTaskTile),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isUpcomingForDisplay(TaskModel task) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduled = task.effectiveDueDateTime;
    final scheduledDay = DateTime(
      scheduled.year,
      scheduled.month,
      scheduled.day,
    );
    return scheduledDay.isAfter(today);
  }

  Widget _buildTaskActions(BuildContext context) =>
      FloatingActionButton.extended(
        heroTag: 'create_task_fab',
        onPressed: () => CreateTaskScreen.navigateTo(context),
        backgroundColor: AppColors.primaryPurple,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Create Task',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 16, 12, 20),
      decoration: const BoxDecoration(
        color: AppColors.heroDarkBg,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search tasks...',
                      hintStyle: TextStyle(color: Color(0xFFB8AED6)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  )
                : Text(
                    'Tasks & Reminders',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
            ),
            color: Colors.white,
            onPressed: () => setState(() {
              if (_isSearching) {
                _isSearching = false;
                _searchQuery = '';
                _searchController.clear();
              } else {
                _isSearching = true;
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, {Color? color}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Row(
          children: [
            Text(
              title.endsWith('Today') ? 'Today' : title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color ?? AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (color ?? AppColors.primaryPurple).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color ?? AppColors.primaryPurple,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildTaskTile(TaskModel task) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'local_user';
    final uname =
        user?.displayName ?? user?.email?.split('@').first ?? 'Local User';
    return TaskCard(
      task: task,
      onTap: () => TaskDetailsScreen.navigateTo(context, task),
      onToggleCompleted: (completed) async {
        if (completed == true) {
          await _taskService.completeTask(
            task,
            completedBy: uid,
            completedByName: uname,
          );
        } else {
          await _taskService.updateTask(
            task.copyWith(
              status: TaskStatus.pending,
              updatedAt: DateTime.now(),
            ),
          );
        }
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildEmptyState() {
    switch (_selectedFilter) {
      case TaskFilterOption.overdue:
        return const TaskEmptyState(
          title: 'No Overdue Tasks',
          message: 'You have no overdue tasks. Great job staying on track!',
          icon: Icons.check_circle_outline_rounded,
        );
      case TaskFilterOption.today:
        return const TaskEmptyState(
          title: 'No Tasks for Today',
          message: 'You are all caught up for today!',
          icon: Icons.wb_sunny_outlined,
        );
      case TaskFilterOption.upcoming:
        return const TaskEmptyState(
          title: 'No Upcoming Tasks',
          message: 'You have no upcoming tasks scheduled.',
          icon: Icons.event_available_rounded,
        );
      case TaskFilterOption.assignedToMe:
        return const TaskEmptyState(
          title: 'No Assigned Tasks',
          message: 'No tasks have been assigned to you by family members.',
          icon: Icons.group_outlined,
        );
      case TaskFilterOption.completed:
        return const TaskEmptyState(
          title: 'No Completed Tasks',
          message: 'Tasks you complete will appear here.',
          icon: Icons.task_alt_rounded,
        );
      default:
        return TaskEmptyState(
          title: 'No tasks found',
          message: _searchQuery.isNotEmpty
              ? 'No tasks match your search criteria.'
              : 'Create a reminder or task to keep your assets organized.',
          icon: Icons.task_alt_rounded,
        );
    }
  }
}
