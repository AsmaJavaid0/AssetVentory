import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../assets/models/local_asset.dart';
import '../../assets/models/local_category.dart';
import '../../assets/screens/asset_details_screen.dart';
import '../../tasks/models/task_model.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onTabSelected;
  const HomeScreen({super.key, this.onTabSelected});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _assetRepository = serviceLocator.assetRepository;
  final _categoryRepository = serviceLocator.categoryRepository;
  final _taskService = serviceLocator.taskService;

  List<LocalAsset> _assets = [];
  List<LocalCategory> _categories = [];
  List<TaskModel> _upcomingTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    try {
      final assets = await _assetRepository.getAssets('local_user');
      final categories = await _categoryRepository.getCategories('local_user');
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'local_user';
      List<TaskModel> tasks = [];
      try {
        tasks = await _taskService.streamVisibleTasks(uid).first;
      } catch (_) {}

      final now = DateTime.now();
      tasks = tasks
          .where((t) => t.status != TaskStatus.completed && t.status != TaskStatus.cancelled)
          .where((t) => !t.effectiveDueDateTime.isBefore(now))
          .toList()
        ..sort((a, b) => a.effectiveDueDateTime.compareTo(b.effectiveDueDateTime));

      if (!mounted) return;
      setState(() {
        _assets = assets;
        _categories = categories;
        _upcomingTasks = tasks.take(3).toList();
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('Home load error: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _categoryName(String? id) {
    if (id == null) return 'Uncategorized';
    for (final category in _categories) {
      if (category.id == id) return category.name;
    }
    return 'Uncategorized';
  }

  Future<void> _openAsset(LocalAsset asset) async {
    await AssetDetailsScreen.navigateTo(context, asset);
    if (mounted) await _loadHomeData();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (mounted) await _loadHomeData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: RefreshIndicator(
        color: AppColors.primaryPurple,
        onRefresh: _loadHomeData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildMetrics(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Upcoming Reminders', 'View all', () => widget.onTabSelected?.call(3)),
                  const SizedBox(height: 10),
                  _buildUpcomingReminders(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Recent Assets', 'View all', () => widget.onTabSelected?.call(1)),
                  const SizedBox(height: 10),
                  _buildRecentAssets(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 18, 16, 28),
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'AssetVentory',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          _headerButton(Icons.notifications_none_rounded, _openNotifications),
          const SizedBox(width: 8),
          _headerButton(Icons.person_outline_rounded, () => widget.onTabSelected?.call(4)),
        ],
      ),
    );
  }

  Widget _headerButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withAlpha(24),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildMetrics() {
    final cards = <Widget>[
      _metric(Icons.inventory_2_rounded, '${_assets.length}', 'Assets', true, () => widget.onTabSelected?.call(1)),
      _metric(Icons.folder_rounded, '${_categories.length}', 'Categories', false, () => widget.onTabSelected?.call(1)),
      _metric(Icons.task_alt_rounded, '${_upcomingTasks.length}', 'Reminders', false, () => widget.onTabSelected?.call(3)),
      _metric(Icons.groups_rounded, 'Family', 'Sharing', false, () => widget.onTabSelected?.call(2)),
    ];

    return GridView.count(
      crossAxisCount: 4,
      crossAxisSpacing: 8,
      childAspectRatio: .78,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards,
    );
  }

  Widget _metric(IconData icon, String value, String label, bool primary, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          gradient: primary ? AppColors.primaryGradient : null,
          color: primary ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primary ? Colors.transparent : const Color(0xFFE9E4F1)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: primary ? Colors.white : AppColors.primaryPurple),
            const SizedBox(height: 6),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: primary ? Colors.white : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w600, color: primary ? Colors.white70 : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action, VoidCallback onTap) {
    return Row(
      children: [
        Expanded(child: Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
        TextButton(onPressed: onTap, child: Text(action, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.primaryPurple))),
      ],
    );
  }

  Widget _buildUpcomingReminders() {
    if (_upcomingTasks.isEmpty) {
      return _emptySection(Icons.notifications_none_rounded, 'No upcoming reminders', 'Your next reminders will appear here.');
    }
    return Column(children: _upcomingTasks.map(_reminderTile).toList());
  }

  Widget _reminderTile(TaskModel task) {
    final due = task.effectiveDueDateTime;
    final today = DateTime.now();
    final isToday = due.year == today.year && due.month == today.month && due.day == today.day;
    final date = isToday ? 'Today' : '${_month(due.month)} ${due.day}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFECE7F4)), boxShadow: [BoxShadow(color: Colors.black.withAlpha(4), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(13)), alignment: Alignment.center, child: Text(task.taskType.icon, style: const TextStyle(fontSize: 20))),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)), const SizedBox(height: 3), Text(date + (task.dueTime == null ? '' : ' • ${_time(due)}'), style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600))])),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }

  Widget _buildRecentAssets() {
    final recent = _assets.take(3).toList();
    if (recent.isEmpty) return _emptySection(Icons.inventory_2_outlined, 'No assets yet', 'Your recently added assets will appear here.');
    return Column(children: recent.map(_assetTile).toList());
  }

  Widget _assetTile(LocalAsset asset) {
    return GestureDetector(
      onTap: () => _openAsset(asset),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFECE7F4)), boxShadow: [BoxShadow(color: Colors.black.withAlpha(4), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: Container(width: 58, height: 50, color: AppColors.primaryPurple.withAlpha(14), child: asset.imagePath?.isNotEmpty == true ? Image.file(File(asset.imagePath!), fit: BoxFit.cover, errorBuilder: (_, _, _) => _emoji(asset)) : _emoji(asset))),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)), const SizedBox(height: 3), Text(_categoryName(asset.categoryId), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)), if (asset.location?.isNotEmpty == true) Text('📍 ${asset.location}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textMuted))])),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
        ]),
      ),
    );
  }

  Widget _emoji(LocalAsset asset) => Center(child: Text(asset.emoji ?? '📦', style: const TextStyle(fontSize: 24)));

  Widget _emptySection(IconData icon, String title, String subtitle) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFECE7F4))), child: Column(children: [Icon(icon, size: 32, color: AppColors.primaryPurple), const SizedBox(height: 8), Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary))]));
  }

  String _month(int month) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month];

  String _time(DateTime value) {
    final hour = value.hour == 0 ? 12 : value.hour > 12 ? value.hour - 12 : value.hour;
    return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'PM' : 'AM'}';
  }
}
