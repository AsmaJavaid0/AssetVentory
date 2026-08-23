import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/wave_clipper.dart';
import '../../../core/widgets/asset_logo.dart';
import '../../../core/widgets/custom_button.dart';

import '../../auth/services/firestore_service.dart';
import '../../auth/models/user_model.dart';
import '../../assets/models/asset_model.dart';
import '../../tasks/models/reminder_model.dart';
import '../../tasks/models/task_model.dart';

import '../widgets/add_quick_asset_sheet.dart';
import '../widgets/asset_detail_modal.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onTabSelected;

  const HomeScreen({super.key, this.onTabSelected});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _showGuidanceBanner = true;

  // ---------------------------------------------------------------------
  // Streams are created ONCE here and reused for the lifetime of this
  // screen, instead of being called inline inside build(). Calling
  // `_firestoreService.streamXxx()` inside build() returns a brand-new
  // Stream object on every rebuild (e.g. every setState), which forces
  // every StreamBuilder listening to it to tear down its Firestore
  // listener and open a new one — that churn is what produces the visible
  // lag/flicker. Keeping the Stream instances stable means Firestore keeps
  // one long-lived listener per query and just delivers updates to it.
  // ---------------------------------------------------------------------
  late final String _uid;
  late final Stream<UserModel?> _userStream;
  late final Stream<List<AssetModel>> _assetsStream;
  late final Stream<List<ReminderModel>> _remindersStream;

  // The tasks/family-count streams depend on familyId, which only becomes
  // known once the user document loads (and could technically change).
  // We memoize them keyed by familyId so they are only recreated on an
  // actual familyId change, not on every rebuild.
  String? _cachedFamilyId;
  Stream<List<TaskModel>>? _tasksStream;
  Stream<int>? _familyCountStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _uid = user?.uid ?? '';
    _userStream = _firestoreService.streamUser(_uid);
    _assetsStream = _firestoreService.streamUserAssets(_uid);
    _remindersStream = _firestoreService.streamUpcomingReminders(_uid);
  }

  Stream<List<TaskModel>> _tasksStreamFor(String? familyId) {
    if (_tasksStream == null || _cachedFamilyId != familyId) {
      _cachedFamilyId = familyId;
      _tasksStream = _firestoreService.streamPendingTasks(_uid, familyId: familyId);
      _familyCountStream = _firestoreService.streamFamilyMembersCount(familyId);
    }
    return _tasksStream!;
  }

  Stream<int> _familyCountStreamFor(String? familyId) {
    _tasksStreamFor(familyId); // ensures both are (re)created together
    return _familyCountStream!;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning,';
    } else if (hour < 17) {
      return 'Good afternoon,';
    } else {
      return 'Good evening,';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<UserModel?>(
      stream: _userStream,
      builder: (context, userSnapshot) {
        final userModel = userSnapshot.data;
        final userName = userModel?.name.isNotEmpty == true
            ? userModel!.name
            : (user.displayName ?? user.email?.split('@').first ?? 'Friend');

        final photoUrl = userModel?.photoUrl.isNotEmpty == true
            ? userModel!.photoUrl
            : user.photoURL;

        return Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          body: RefreshIndicator(
            onRefresh: () async {
              // Streams are live already; this just gives the user
              // visible feedback without tearing down any listeners.
              await Future.delayed(const Duration(milliseconds: 400));
            },
            color: AppColors.primaryPurple,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reminders are needed by the hero header, the metric
                  // cards AND the reminders list below. Previously each of
                  // those subscribed to streamUpcomingReminders()
                  // independently (3 separate Firestore listeners for the
                  // same data). Now it's subscribed to once here and the
                  // result is threaded down to whoever needs it.
                  StreamBuilder<List<ReminderModel>>(
                    stream: _remindersStream,
                    builder: (context, reminderSnapshot) {
                      final reminders = reminderSnapshot.data ?? [];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Dark Hero Header
                          _buildHeroHeader(
                            context: context,
                            name: userName,
                            photoUrl: photoUrl,
                            unreadCount: reminders.length,
                          ),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),

                                // 2. Add Asset Quick Action Banner
                                StreamBuilder<List<AssetModel>>(
                                  stream: _assetsStream,
                                  builder: (context, assetSnapshot) {
                                    final totalAssets = assetSnapshot.data?.length ?? 0;
                                    final isEmptyState = totalAssets == 0;

                                    return Column(
                                      children: [
                                        _buildAddAssetBanner(
                                          context: context,
                                          isEmptyState: isEmptyState,
                                        ),
                                        const SizedBox(height: 20),

                                        // 3. Metric Summary Cards Row
                                        _buildMetricCardsSection(
                                          user: user,
                                          userModel: userModel,
                                          totalAssets: totalAssets,
                                          expiringSoonCount: reminders.length,
                                        ),

                                        const SizedBox(height: 20),

                                        // 4. Dismissible Guidance Tip Banner
                                        if (_showGuidanceBanner && totalAssets <= 1)
                                          _buildGuidanceBanner(),

                                        const SizedBox(height: 24),

                                        // 5. Upcoming Reminders Section
                                        _buildUpcomingRemindersSection(reminders),

                                        const SizedBox(height: 28),

                                        // 6. Recent Assets Section
                                        _buildRecentAssetsSection(
                                          assetSnapshot.data,
                                          assetSnapshot.connectionState,
                                        ),

                                        const SizedBox(height: 36),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Header Widget
  Widget _buildHeroHeader({
    required BuildContext context,
    required String name,
    required String? photoUrl,
    required int unreadCount,
  }) {
    return ClipPath(
      clipper: WaveClipper(),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.heroGradient,
        ),
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 36),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: const Color(0xFFC4BAE5),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('👋', style: TextStyle(fontSize: 20)),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        widget.onTabSelected?.call(1); // Navigate to Assets/Reminders
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  unreadCount > 9 ? '9+' : '$unreadCount',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        widget.onTabSelected?.call(4); // Navigate to Profile
                      },
                      child: CircleAvatar(
                        radius: 21,
                        backgroundColor: AppColors.primaryPurple,
                        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null || photoUrl.isEmpty
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Here's what's happening\nwith your assets today.",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: const Color(0xFFB8AED6),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 76,
                  height: 76,
                  child: AssetLogo(
                    size: 58,
                    showText: false,
                    isDarkBackground: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Quick Action Banner
  Widget _buildAddAssetBanner({required BuildContext context, required bool isEmptyState}) {
    return GestureDetector(
      onTap: () => AddQuickAssetSheet.show(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7E43F8).withAlpha(80),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEmptyState ? 'Add Your First Asset' : 'Add Asset',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEmptyState
                        ? 'Start by adding an asset to keep all its details, documents and dates organized.'
                        : 'Add a new asset and keep everything organized',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white.withAlpha(220),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
          ],
        ),
      ),
    );
  }

  // Metric Cards Section
  Widget _buildMetricCardsSection({
    required User user,
    required UserModel? userModel,
    required int totalAssets,
    required int expiringSoonCount,
  }) {
    return StreamBuilder<List<TaskModel>>(
      stream: _tasksStreamFor(userModel?.familyId),
      builder: (context, taskSnapshot) {
        final pendingTasksCount = taskSnapshot.data?.length ?? 0;

        return StreamBuilder<int>(
          stream: _familyCountStreamFor(userModel?.familyId),
          builder: (context, familySnapshot) {
            final familyMembersCount = familySnapshot.data ?? 0;

            return Row(
              children: [
                _buildMetricCard(
                  icon: Icons.inventory_2_rounded,
                  iconColor: const Color(0xFF8B47FA),
                  count: '$totalAssets',
                  label: 'Total Assets',
                  onTap: () => widget.onTabSelected?.call(1),
                ),
                const SizedBox(width: 8),
                _buildMetricCard(
                  icon: Icons.access_time_filled_rounded,
                  iconColor: const Color(0xFFFF9500),
                  count: '$expiringSoonCount',
                  label: 'Expiring Soon',
                  onTap: () => widget.onTabSelected?.call(1),
                ),
                const SizedBox(width: 8),
                _buildMetricCard(
                  icon: Icons.task_alt_rounded,
                  iconColor: const Color(0xFF10B981),
                  count: '$pendingTasksCount',
                  label: 'Pending Tasks',
                  onTap: () => widget.onTabSelected?.call(3),
                ),
                const SizedBox(width: 8),
                _buildMetricCard(
                  icon: Icons.group_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  count: '$familyMembersCount',
                  label: 'Family Members',
                  onTap: () => widget.onTabSelected?.call(2),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard({

    required IconData icon,
    required Color iconColor,
    required String count,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEFEBF6), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(height: 6),
              Text(
                count,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View all',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 10,
                    color: AppColors.primaryPurple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Guidance Tip Banner
  Widget _buildGuidanceBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EDFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2D9F8)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_outlined, color: AppColors.primaryPurple, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep Everything in One Place',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Add assets, set reminders, store documents and share with family.',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
            onPressed: () => setState(() => _showGuidanceBanner = false),
          ),
        ],
      ),
    );
  }

  // Upcoming Reminders Section
  Widget _buildUpcomingRemindersSection(List<ReminderModel> reminders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Reminders',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () => widget.onTabSelected?.call(1),
              child: Row(
                children: [
                  Text(
                    'View All',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primaryPurple),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Builder(
          builder: (context) {
            if (reminders.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEFEBF6), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE8FB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.alarm_on_rounded, color: AppColors.primaryPurple, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No upcoming reminders',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Warranties & due dates will appear here',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: reminders.map((reminder) {
                final dateStr = '${reminder.reminderDate.day}/${reminder.reminderDate.month}/${reminder.reminderDate.year}';
                final daysLeft = reminder.reminderDate.difference(DateTime.now()).inDays;
                final badgeText = daysLeft == 0
                    ? 'Due Today'
                    : daysLeft > 0
                        ? 'In $daysLeft days'
                        : dateStr;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEFEBF6), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.alarm, color: AppColors.warning, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reminder.title,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (reminder.notes != null && reminder.notes!.isNotEmpty)
                              Text(
                                reminder.notes!,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // Recent Assets Section
  Widget _buildRecentAssetsSection(
    List<AssetModel>? assets,
    ConnectionState connectionState,
  ) {
    final assetList = assets ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Assets',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () => widget.onTabSelected?.call(1),
              child: Row(
                children: [
                  Text(
                    'View All',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primaryPurple),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (connectionState == ConnectionState.waiting && assetList.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (assetList.isEmpty)
          // PDF Page 9 Exact Empty State
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEFEBF6), width: 1),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1EEFB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.primaryPurple,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Your collection is empty',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add your first asset to start organizing\nyour important belongings.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 160,
                  child: GradientButton(
                    height: 44,
                    text: '+ Add Asset',
                    onPressed: () => AddQuickAssetSheet.show(context),
                  ),
                ),
              ],
            ),
          )
        else
          // Populated State Horizontal List
          SizedBox(
            height: 138,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: assetList.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final asset = assetList[index];
                return GestureDetector(
                  onTap: () => AssetDetailModal.show(context, asset),
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFEFEBF6), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(6),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple.withAlpha(20),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  asset.emoji ?? '📦',
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                            const Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textMuted),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          asset.name,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          asset.categoryId ?? asset.location ?? 'Asset',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
