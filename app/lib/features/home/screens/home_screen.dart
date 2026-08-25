import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/wave_clipper.dart';
import '../../../core/widgets/asset_logo.dart';
import '../../../core/di/service_locator.dart';

import '../../assets/models/local_asset.dart';
import '../../assets/models/local_category.dart';
import '../../assets/screens/add_asset_screen.dart';
import '../../assets/screens/edit_asset_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onTabSelected;

  const HomeScreen({
    super.key,
    this.onTabSelected,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _assetRepository = serviceLocator.assetRepository;
  final _categoryRepository = serviceLocator.categoryRepository;

  List<LocalAsset> _assets = [];
  List<LocalCategory> _categories = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    try {
      final assets =
          await _assetRepository.getAssets('local_user');

      final categories =
          await _categoryRepository.getCategories('local_user');

      if (!mounted) return;

      setState(() {
        _assets = assets;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Home local load error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _assets = [];
        _categories = [];
        _isLoading = false;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good morning,';
    }

    if (hour < 17) {
      return 'Good afternoon,';
    }

    return 'Good evening,';
  }

  String _categoryName(String? categoryId) {
    if (categoryId == null) {
      return 'Uncategorized';
    }

    for (final category in _categories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }

    return 'Uncategorized';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: RefreshIndicator(
        color: AppColors.primaryPurple,
        onRefresh: _loadHomeData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroHeader(context),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 18),

                    _buildAddAssetBanner(context),

                    const SizedBox(height: 20),

                    _buildMetrics(),

                    const SizedBox(height: 24),

                    if (_assets.isEmpty)
                      _buildEmptyGuidance()
                    else
                      _buildRecentAssets(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    return ClipPath(
      clipper: WaveClipper(),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.heroGradient,
        ),
        padding: const EdgeInsets.fromLTRB(
          20,
          52,
          20,
          38,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: const Color(0xFFC4BAE5),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          'My Collection',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '👋',
                          style: TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    widget.onTabSelected?.call(4);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: Text(
                    "Everything you own,\norganized in one place.",
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
          ],
        ),
      ),
    );
  }

  Widget _buildAddAssetBanner(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await AddAssetScreen.navigateTo(context);

        if (!mounted) return;

        await _loadHomeData();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7E43F8).withAlpha(70),
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
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    _assets.isEmpty
                        ? 'Add Your First Asset'
                        : 'Add Asset',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _assets.isEmpty
                        ? 'Start organizing your belongings.'
                        : 'Add another asset to your collection.',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white.withAlpha(220),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics() {
    return Row(
      children: [
        _buildMetricCard(
          icon: Icons.inventory_2_rounded,
          count: '${_assets.length}',
          label: 'Assets',
          onTap: () => widget.onTabSelected?.call(1),
        ),
        const SizedBox(width: 8),
        _buildMetricCard(
          icon: Icons.folder_rounded,
          count: '${_categories.length}',
          label: 'Categories',
          onTap: () => widget.onTabSelected?.call(1),
        ),
        const SizedBox(width: 8),
        _buildMetricCard(
          icon: Icons.task_alt_rounded,
          count: '0',
          label: 'Tasks',
          onTap: () => widget.onTabSelected?.call(3),
        ),
        const SizedBox(width: 8),
        _buildMetricCard(
          icon: Icons.group_rounded,
          count: '—',
          label: 'Family',
          onTap: () => widget.onTabSelected?.call(2),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String count,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 13,
            horizontal: 5,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFEFEBF6),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: AppColors.primaryPurple,
                size: 22,
              ),
              const SizedBox(height: 7),
              Text(
                count,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyGuidance() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEFEBF6),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 42,
            color: AppColors.primaryPurple,
          ),
          const SizedBox(height: 12),
          Text(
            'Your collection is empty',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Add your first asset to start managing your belongings.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAssets() {
    final recent =
        _assets.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Assets',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () =>
                  widget.onTabSelected?.call(1),
              child: Text(
                'View all',
                style: GoogleFonts.outfit(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        ...recent.map(
          (asset) => _buildAssetTile(asset),
        ),
      ],
    );
  }

  Widget _buildAssetTile(LocalAsset asset) {
    return GestureDetector(
      onTap: () async {
        await EditAssetScreen.navigateTo(
          context,
          asset,
        );

        if (!mounted) return;

        await _loadHomeData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFEFEBF6),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withAlpha(18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  asset.emoji ?? '📦',
                  style: const TextStyle(fontSize: 23),
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _categoryName(asset.categoryId),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (asset.location != null &&
                      asset.location!.isNotEmpty)
                    Text(
                      '📍 ${asset.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}