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

  List<TaskModel> _filterAndSearchTasks(List<TaskModel> tasks, String currentUserId) {
    var result = tasks;

    // Apply Filter option
    switch (_selectedFilter) {
      case TaskFilterOption.all:
        result = result.where((t) => t.status != TaskStatus.completed && t.status != TaskStatus.cancelled).toList();
        break;
      case TaskFilterOption.today:
        result = result.where((t) => t.isDueToday && t.status != TaskStatus.completed).toList();
        break;
      case TaskFilterOption.upcoming:
        result = result.where((t) => t.isUpcoming && !t.isOverdue && t.status != TaskStatus.completed).toList();
        break;
      case TaskFilterOption.overdue:
        result = result.where((t) => t.isOverdue && t.status != TaskStatus.completed).toList();
        break;
      case TaskFilterOption.assignedToMe:
        result = result
            .where((t) => t.assignedTo == currentUserId && t.createdBy != currentUserId)
            .toList();
        break;
      case TaskFilterOption.createdByMe:
        result = result.where((t) => t.createdBy == currentUserId).toList();
        break;
      case TaskFilterOption.completed:
        result = result.where((t) => t.status == TaskStatus.completed).toList();
        break;
    }

    // Apply Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      result = result.where((t) {
        final titleMatch = t.title.toLowerCase().contains(query);
        final descMatch = t.description?.toLowerCase().contains(query) ?? false;
        final assetMatch = t.assetName?.toLowerCase().contains(query) ?? false;
        return titleMatch || descMatch || assetMatch;
      }).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid ?? 'local_user';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'tasks_fab',
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
      ),
      body: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),
          TaskFilterBar(
            selectedFilter: _selectedFilter,
            onFilterSelected: (filter) => setState(() => _selectedFilter = filter),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<TaskModel>>(
              stream: _taskService.streamVisibleTasks(uid, familyId: _userFamily?.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return TaskEmptyState(
                    title: 'Unable to load tasks',
                    message: 'Please check your connection and try again.',
                    icon: Icons.error_outline_rounded,
                  );
                }

                final rawTasks = snapshot.data ?? [];
                final displayTasks = _filterAndSearchTasks(rawTasks, uid);

                if (displayTasks.isEmpty) {
                  return _buildEmptyState();
                }

                final overdueTasks = displayTasks.where((t) => t.isOverdue).toList();
                final todayTasks = displayTasks.where((t) => t.isDueToday && !t.isOverdue).toList();
                final upcomingTasks = displayTasks.where((t) => t.isUpcoming && !t.isOverdue).toList();
                final otherTasks = displayTasks.where((t) =>
                    !overdueTasks.contains(t) &&
                    !todayTasks.contains(t) &&
                    !upcomingTasks.contains(t)).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  children: [
                    if (overdueTasks.isNotEmpty) ...[
                      _buildSectionHeader('🔴 Overdue', overdueTasks.length, color: AppColors.error),
                      ...overdueTasks.map(_buildTaskTile),
                      const SizedBox(height: 16),
                    ],
                    if (todayTasks.isNotEmpty) ...[
                      _buildSectionHeader('📅 Today', todayTasks.length),
                      ...todayTasks.map(_buildTaskTile),
                      const SizedBox(height: 16),
                    ],
                    if (upcomingTasks.isNotEmpty) ...[
                      _buildSectionHeader('⏰ Upcoming', upcomingTasks.length),
                      ...upcomingTasks.map(_buildTaskTile),
                      const SizedBox(height: 16),
                    ],
                    if (otherTasks.isNotEmpty) ...[
                      _buildSectionHeader(
                        _selectedFilter == TaskFilterOption.completed ? '✅ Completed' : '📋 Tasks',
                        otherTasks.length,
                      ),
                      ...otherTasks.map(_buildTaskTile),
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
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Search tasks...',
                      hintStyle: TextStyle(color: Color(0xFFB8AED6)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  )
                : Text(
                    'Tasks & Reminders',
                    style: GoogleFonts.outfit(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700),
                  ),
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            color: Colors.white,
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Text(
            title,
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
  }

  Widget _buildTaskTile(TaskModel task) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'local_user';
    final uname = user?.displayName ?? user?.email?.split('@').first ?? 'Local User';

    return TaskCard(
      task: task,
      onTap: () => TaskDetailsScreen.navigateTo(context, task),
      onToggleCompleted: (completed) async {
        if (completed == true) {
          await _taskService.completeTask(task, completedBy: uid, completedByName: uname);
        } else {
          await _taskService.updateTask(task.copyWith(status: TaskStatus.pending));
        }
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
          onAction: () => CreateTaskScreen.navigateTo(context),
          actionLabel: 'Create Task',
        );
    }
  }
}
