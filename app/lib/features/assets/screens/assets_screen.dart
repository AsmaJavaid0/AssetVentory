import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_palette.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/local_file_storage.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/local_asset.dart';
import '../models/local_category.dart';
import '../repositories/asset_repository.dart';
import '../repositories/category_repository.dart';
import 'asset_details_screen.dart';
import 'categories_screen.dart';
import '../../home/widgets/add_quick_asset_sheet.dart';

enum _AssetFilter { all, categorized, uncategorized }

enum _AssetSort { newest, name, location }

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen>
    with SingleTickerProviderStateMixin {
  static const _localUserId = 'local_user';
  final _searchController = TextEditingController();
  late final AppDatabase _database;
  late final AssetRepository _assetRepository;
  late final CategoryRepository _categoryRepository;
  late final AnimationController _searchAnimController;
  late final Animation<double> _searchAnimation;

  List<LocalAsset> _assets = [];
  List<LocalCategory> _categories = [];
  bool _loading = true;
  bool _searchVisible = false;
  String _searchQuery = '';
  _AssetFilter _filter = _AssetFilter.all;
  _AssetSort _sort = _AssetSort.newest;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _assetRepository = AssetRepository(database: _database, fileStorage: LocalFileStorage());
    _categoryRepository = CategoryRepository(database: _database);
    _searchAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimController,
      curve: Curves.easeOutCubic,
    );
    _load();
  }

  Future<void> _load() async {
    try {
      final assets = await _assetRepository.getAssets(_localUserId);
      final categories = await _categoryRepository.getCategories(_localUserId);
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _categories = categories;
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Assets load error: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<LocalAsset> get _filteredAssets {
    final query = _searchQuery.toLowerCase();
    final result = _assets.where((asset) {
      final filterMatches = switch (_filter) {
        _AssetFilter.all => true,
        _AssetFilter.categorized => asset.categoryId != null,
        _AssetFilter.uncategorized => asset.categoryId == null,
      };
      final searchMatches = query.isEmpty ||
          asset.name.toLowerCase().contains(query) ||
          (asset.location?.toLowerCase().contains(query) ?? false) ||
          (asset.description?.toLowerCase().contains(query) ?? false);
      return filterMatches && searchMatches;
    }).toList();

    result.sort((a, b) {
      switch (_sort) {
        case _AssetSort.newest:
          return b.createdAt.compareTo(a.createdAt);
        case _AssetSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _AssetSort.location:
          return (a.location ?? '').toLowerCase().compareTo((b.location ?? '').toLowerCase());
      }
    });
    return result;
  }

  String _categoryName(String? id) {
    if (id == null) return 'Uncategorized';
    for (final category in _categories) {
      if (category.id == id) return category.name;
    }
    return 'Uncategorized';
  }

  Future<void> _openDetails(LocalAsset asset) async {
    await AssetDetailsScreen.navigateTo(context, asset);
    if (mounted) await _load();
  }

  Future<void> _openCategories() async {
    await CategoriesScreen.navigateTo(context);
    if (mounted) await _load();
  }

  void _toggleSearch() {
    setState(() => _searchVisible = !_searchVisible);
    if (_searchVisible) {
      _searchAnimController.forward();
    } else {
      _searchAnimController.reverse();
      _searchController.clear();
      setState(() => _searchQuery = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    if (_loading) {
      return Scaffold(
        backgroundColor: palette.isDark ? AppColors.heroDarkBg : AppColors.scaffoldBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final assets = _filteredAssets;
    return Scaffold(
      backgroundColor: palette.isDark ? AppColors.heroDarkBg : AppColors.scaffoldBg,
      body: Stack(
        children: [
          Column(
            children: [
              AppHeader.solid(
                title: 'My Assets',
                subtitle: '${_assets.length} item${_assets.length == 1 ? '' : 's'} in your collection',
                actions: [
                  HeaderIconButton(
                    icon: _searchVisible ? Icons.search_off_rounded : Icons.search_rounded,
                    tooltip: _searchVisible ? 'Close search' : 'Search assets',
                    onTap: _toggleSearch,
                    active: _searchVisible,
                  ),
                  HeaderIconButton(
                    icon: Icons.folder_outlined,
                    tooltip: 'Categories',
                    onTap: _openCategories,
                  ),
                  PopupMenuButton<_AssetSort>(
                    tooltip: 'Sort',
                    icon: const Icon(Icons.sort_rounded, color: Colors.white, size: 22),
                    color: palette.surface,
                    onSelected: (value) => setState(() => _sort = value),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: _AssetSort.newest, child: Text('Newest first')),
                      PopupMenuItem(value: _AssetSort.name, child: Text('Name A–Z')),
                      PopupMenuItem(value: _AssetSort.location, child: Text('Location A–Z')),
                    ],
                  ),
                ],
                bottom: _buildFilterPills(),
              ),
              Expanded(
                child: assets.isEmpty ? _buildEmptyState() : _buildAssetList(assets),
              ),
            ],
          ),
          if (_searchVisible)
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 16,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(14),
                child: _buildSearchBar(palette),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await AddQuickAssetSheet.show(context);
          if (mounted) await _load();
        },
        backgroundColor: AppColors.primaryPurple,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Add Asset',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSearchBar(AppPalette palette) {
    return Container(
      color: const Color(0xFF1F1040),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(35)),
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: (value) => setState(() => _searchQuery = value.trim()),
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by name, location…',
            hintStyle: GoogleFonts.outfit(color: const Color(0xFFB8AED6), fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFB8AED6), size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPills() {
    final palette = AppPalette.of(context);
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(
        children: [
          Expanded(child: _filterPill(palette, 'All', _AssetFilter.all)),
          const SizedBox(width: 8),
          Expanded(child: _filterPill(palette, 'Categorized', _AssetFilter.categorized)),
          const SizedBox(width: 8),
          Expanded(child: _filterPill(palette, 'Uncategorized', _AssetFilter.uncategorized)),
        ],
      ),
    );
  }

  Widget _filterPill(AppPalette palette, String label, _AssetFilter filter) {
    final selected = _filter == filter;
    return GestureDetector(
      onTap: () => setState(() => _filter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withAlpha(16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.white : Colors.white.withAlpha(35),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primaryPurple : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAssetList(List<LocalAsset> assets) {
    final palette = AppPalette.of(context);
    return RefreshIndicator(
      color: AppColors.primaryPurple,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: assets.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _buildAssetCard(assets[index], palette),
      ),
    );
  }

  Widget _buildAssetCard(LocalAsset asset, AppPalette palette) {
    return GestureDetector(
      onTap: () => _openDetails(asset),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _thumbnail(asset),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    asset.name,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.folder_outlined, size: 12, color: AppColors.primaryPurple),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _categoryName(asset.categoryId),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: palette.onSurfaceMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (asset.location?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            asset.location!,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: palette.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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

  Widget _thumbnail(LocalAsset asset) {
    final path = asset.imagePath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 80,
        height: 68,
        color: AppColors.primaryPurple.withAlpha(15),
        child: path != null && path.isNotEmpty
            ? Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, _, _) => _emoji(asset))
            : _emoji(asset),
      ),
    );
  }

  Widget _emoji(LocalAsset asset) =>
      Center(child: Text(asset.emoji ?? '📦', style: const TextStyle(fontSize: 32)));

  Widget _buildEmptyState() {
    final palette = AppPalette.of(context);
    final label = switch (_filter) {
      _AssetFilter.all => 'No assets yet.',
      _AssetFilter.categorized => 'No categorized assets.',
      _AssetFilter.uncategorized => 'No uncategorized assets.',
    };
    return RefreshIndicator(
      color: AppColors.primaryPurple,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: EmptyState(
              icon: Icons.inventory_2_outlined,
              title: label,
              message: 'Your inventory is looking a bit empty. Start adding your belongings to keep everything organized!',
              actionLabel: 'Add Your First Asset',
              onAction: () async {
                await AddQuickAssetSheet.show(context);
                if (mounted) await _load();
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchAnimController.dispose();
    _database.close();
    super.dispose();
  }
}
