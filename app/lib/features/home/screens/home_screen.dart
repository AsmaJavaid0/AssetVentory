import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/wave_clipper.dart';
import '../../../core/widgets/asset_logo.dart';
import '../../../core/di/service_locator.dart';

import '../../assets/models/local_asset.dart';
import '../../assets/models/local_category.dart';
import '../../assets/screens/add_asset_screen.dart';
import '../../assets/screens/asset_details_screen.dart';
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
  List<LocalAsset> _assets = [];
  List<LocalCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadHomeData(); }

  Future<void> _loadHomeData() async {
    try {
      final assets = await _assetRepository.getAssets('local_user');
      final categories = await _categoryRepository.getCategories('local_user');
      if (!mounted) return;
      setState(() { _assets = assets; _categories = categories; _isLoading = false; });
    } catch (e, stackTrace) {
      debugPrint('Home local load error: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() { _assets = []; _categories = []; _isLoading = false; });
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
    for (final category in _categories) { if (category.id == categoryId) return category.name; }
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
    if (_isLoading) return const Scaffold(backgroundColor: AppColors.scaffoldBg, body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: RefreshIndicator(
        color: AppColors.primaryPurple,
        onRefresh: _loadHomeData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildHeroHeader(context),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
              const SizedBox(height: 18), _buildAddAssetBanner(context), const SizedBox(height: 20), _buildMetrics(), const SizedBox(height: 24),
              if (_assets.isEmpty) _buildEmptyGuidance() else _buildRecentAssets(), const SizedBox(height: 32),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) => ClipPath(
    clipper: WaveClipper(),
    child: Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 38),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_getGreeting(), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 16, color: const Color(0xFFC4BAE5))),
            const SizedBox(height: 3),
            Text('My Collection 👋', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700)),
          ])),
          const SizedBox(width: 10),
          GestureDetector(onTap: () => widget.onTabSelected?.call(4), child: Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withAlpha(25), shape: BoxShape.circle), child: const Icon(Icons.person_outline_rounded, color: Colors.white))),
        ]),
        const SizedBox(height: 18),
        Row(children: [Expanded(child: Text('Everything you own,\norganized in one place.', maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFFB8AED6), height: 1.4))), const SizedBox(width: 18), const SizedBox(width: 76, height: 76, child: AssetLogo(size: 58, showText: false, isDarkBackground: true))]),
      ]),
    ),
  );

  Widget _buildAddAssetBanner(BuildContext context) => GestureDetector(
    onTap: () async { await AddAssetScreen.navigateTo(context); if (mounted) await _loadHomeData(); },
    child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15), decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(22)), child: Row(children: [
      Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white.withAlpha(50), shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.white, size: 27)), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_assets.isEmpty ? 'Add Your First Asset' : 'Add Asset', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)), const SizedBox(height: 3), Text(_assets.isEmpty ? 'Start organizing your belongings.' : 'Add another asset to your collection.', maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 12, color: Colors.white.withAlpha(220)))])),
      const SizedBox(width: 6), const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 26),
    ])),
  );

  Widget _buildMetrics() {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 380;
      final itemWidth = isNarrow
          ? (constraints.maxWidth - 8) / 2
          : (constraints.maxWidth - 24) / 4;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(width: itemWidth, child: _metric(Icons.inventory_2_rounded, '${_assets.length}', 'Assets', () => widget.onTabSelected?.call(1))),
          SizedBox(width: itemWidth, child: _metric(Icons.folder_rounded, '${_categories.length}', 'Categories', _openCategories)),
          SizedBox(width: itemWidth, child: _metric(Icons.task_alt_rounded, '0', 'Tasks', () => widget.onTabSelected?.call(3))),
          SizedBox(width: itemWidth, child: _metric(Icons.group_rounded, '—', 'Family', () => widget.onTabSelected?.call(2))),
        ],
      );
    });
  }

  Widget _metric(IconData icon, String count, String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEFEBF6))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: AppColors.primaryPurple, size: 22),
        const SizedBox(height: 6),
        Text(count, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary)),
      ]),
    ),
  );

  Widget _buildEmptyGuidance() => Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEFEBF6))), child: Column(children: [const Icon(Icons.inventory_2_outlined, size: 42, color: AppColors.primaryPurple), const SizedBox(height: 12), Text('Your collection is empty', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)), const SizedBox(height: 5), Text('Add your first asset to start managing your belongings.', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary))]));

  Widget _buildRecentAssets() {
    final recent = _assets.take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text('Recent Assets', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))), TextButton(onPressed: () => widget.onTabSelected?.call(1), child: Text('View all', style: GoogleFonts.outfit(color: AppColors.primaryPurple, fontWeight: FontWeight.w600)))]),
      const SizedBox(height: 8), ...recent.map(_buildAssetTile),
    ]);
  }

  Widget _buildAssetTile(LocalAsset asset) => GestureDetector(
    onTap: () => _openAssetDetails(asset),
    child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEFEBF6))), child: Row(children: [
      ClipRRect(borderRadius: BorderRadius.circular(12), child: Container(width: 82, height: 58, color: AppColors.primaryPurple.withAlpha(18), child: asset.imagePath != null && asset.imagePath!.isNotEmpty ? Image.file(File(asset.imagePath!), fit: BoxFit.contain, errorBuilder: (_, _, _) => _emojiFallback(asset)) : _emojiFallback(asset))),
      const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)), const SizedBox(height: 3), Text(_categoryName(asset.categoryId), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)), if (asset.location != null && asset.location!.isNotEmpty) Text('📍 ${asset.location}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted))])), const SizedBox(width: 4), const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
    ])),
  );

  Widget _emojiFallback(LocalAsset asset) => Center(child: Text(asset.emoji ?? '📦', style: const TextStyle(fontSize: 25)));
}
