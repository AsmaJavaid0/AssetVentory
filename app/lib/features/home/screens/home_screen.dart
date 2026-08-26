import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_palette.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/wave_clipper.dart';
import '../../../core/widgets/asset_logo.dart';

import '../../assets/models/local_asset.dart';
import '../../assets/models/local_category.dart';
import '../../assets/screens/add_asset_screen.dart';
import '../../assets/screens/asset_details_screen.dart';
import '../../assets/screens/assets_screen.dart';
import '../../assets/screens/categories_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onTabSelected;
  const HomeScreen({super.key, this.onTabSelected});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _assetRepository = serviceLocator.assetRepository;
  final _categoryRepository = serviceLocator.categoryRepository;
  final _documentRepository = serviceLocator.assetDocumentRepository;
  List<LocalAsset> _assets = [];
  List<LocalCategory> _categories = [];
  int _documentCount = 0;
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
      final docs = await _documentRepository.countDocuments('local_user');
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _categories = categories;
        _documentCount = docs;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Home local load error: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _assets = [];
        _categories = [];
        _documentCount = 0;
        _isLoading = false;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  String _categoryName(String? categoryId) {
    if (categoryId == null) return 'Uncategorized';
    for (final category in _categories) {
      if (category.id == categoryId) return category.name;
    }
    return 'Uncategorized';
  }

  Future<void> _openAssetDetails(LocalAsset asset) async {
    await AssetDetailsScreen.navigateTo(context, asset);
    if (mounted) await _loadHomeData();
  }

  Future<void> _openCategories() async {
    await CategoriesScreen.navigateTo(context);
    if (mounted) await _loadHomeData();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: palette.isDark ? AppColors.heroDarkBg : AppColors.scaffoldBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: palette.isDark ? AppColors.heroDarkBg : AppColors.scaffoldBg,
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildAddAssetBanner(context),
                    const SizedBox(height: 20),
                    _buildMetrics(context),
                    const SizedBox(height: 24),
                    if (_assets.isEmpty)
                      _buildEmptyGuidance(context)
                    else
                      _buildRecentAssets(palette),
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
    final palette = AppPalette.of(context);
    final topPad = MediaQuery.of(context).padding.top;
    return ClipPath(
      clipper: WaveClipper(),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        padding: EdgeInsets.fromLTRB(20, topPad + 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          color: const Color(0xFFC4BAE5),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'My Collection 👋',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => widget.onTabSelected?.call(4),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Everything you own,\norganized in one place.',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: const Color(0xFFB8AED6),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const SizedBox(
                  width: 72,
                  height: 72,
                  child: AssetLogo(size: 54, showText: false, isDarkBackground: true),
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
        if (mounted) await _loadHomeData();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPurple.withAlpha(60),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _assets.isEmpty ? 'Add Your First Asset' : 'Add Asset',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
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
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width < 340 ? 2 : 3;
        final itemWidth = (width - (crossAxisCount - 1) * 10) / crossAxisCount;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: itemWidth,
              child: _metric(
                Icons.inventory_2_rounded,
                '${_assets.length}',
                'Assets',
                () => widget.onTabSelected?.call(1),
                isPrimary: true,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _metric(
                Icons.folder_rounded,
                '${_categories.length}',
                'Categories',
                _openCategories,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _metric(
                Icons.description_rounded,
                '$_documentCount',
                'Documents',
                () => widget.onTabSelected?.call(1),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _metric(IconData icon, String count, String label, VoidCallback onTap, {bool isPrimary = false}) {
    final palette = AppPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 90),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primaryPurple : palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary ? AppColors.primaryPurple : palette.border,
          ),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                ? AppColors.primaryPurple.withAlpha(60)
                : Colors.black.withAlpha(4),
              blurRadius: isPrimary ? 12 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isPrimary ? Colors.white : AppColors.primaryPurple,
              size: isPrimary ? 26 : 22,
            ),
            const SizedBox(height: 6),
            Text(
              count,
              style: GoogleFonts.outfit(
                fontSize: isPrimary ? 18 : 16,
                fontWeight: FontWeight.w700,
                color: isPrimary ? Colors.white : palette.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: isPrimary ? Colors.white70 : palette.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyGuidance(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightLavender,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 44,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your collection is empty',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: palette.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first asset to start managing your belongings and keeping them secure.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: palette.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await AddAssetScreen.navigateTo(context);
                if (mounted) _loadHomeData();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Get Started Now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAssets(AppPalette palette) {
    final recent = _assets.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent Assets',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: palette.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () => widget.onTabSelected?.call(1),
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
        ...recent.map((asset) => _buildAssetTile(asset, palette)),
      ],
    );
  }

  Widget _buildAssetTile(LocalAsset asset, AppPalette palette) {
    return GestureDetector(
      onTap: () => _openAssetDetails(asset),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 72,
                height: 56,
                color: AppColors.primaryPurple.withAlpha(18),
                child: asset.imagePath != null && asset.imagePath!.isNotEmpty
                    ? Image.file(
                        File(asset.imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _emojiFallback(asset),
                      )
                    : _emojiFallback(asset),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    asset.name,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _categoryName(asset.categoryId),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: palette.onSurfaceMuted,
                    ),
                  ),
                  if (asset.location != null && asset.location!.isNotEmpty)
                    Text(
                      '📍 ${asset.location}',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: palette.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _emojiFallback(LocalAsset asset) =>
      Center(child: Text(asset.emoji ?? '📦', style: const TextStyle(fontSize: 24)));
}
