import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/local_file_storage.dart';
import '../../../core/utils/wave_clipper.dart';
import '../models/local_asset.dart';
import '../models/local_category.dart';
import '../repositories/asset_repository.dart';
import '../repositories/category_repository.dart';
import 'asset_details_screen.dart';
import 'add_asset_screen.dart';
import 'categories_screen.dart';
import '../../home/widgets/add_quick_asset_sheet.dart';

enum _AssetFilter { all, categorized, uncategorized }

enum _AssetSort { newest, name, location }

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  static const _localUserId = 'local_user';
  final _searchController = TextEditingController();
  late final AppDatabase _database;
  late final AssetRepository _assetRepository;
  late final CategoryRepository _categoryRepository;

  List<LocalAsset> _assets = [];
  List<LocalCategory> _categories = [];
  bool _loading = true;
  String _searchQuery = '';
  _AssetFilter _filter = _AssetFilter.all;
  _AssetSort _sort = _AssetSort.newest;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _assetRepository = AssetRepository(database: _database, fileStorage: LocalFileStorage());
    _categoryRepository = CategoryRepository(database: _database);
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final assets = _filteredAssets;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterPills(),
          Expanded(
            child: assets.isEmpty ? _buildEmptyState() : _buildAssetList(assets),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await AddQuickAssetSheet.show(context);
          if (mounted) await _load();
        },
        backgroundColor: AppColors.primaryPurple,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Asset', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildHeader() {
    return ClipPath(
      clipper: WaveClipper(),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Assets', style: GoogleFonts.outfit(fontSize: 25, color: Colors.white, fontWeight: FontWeight.w700)),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Categories',
                      onPressed: _openCategories,
                      icon: const Icon(Icons.folder_outlined, color: Colors.white),
                    ),
                    PopupMenuButton<_AssetSort>(
                      tooltip: 'Sort assets',
                      icon: const Icon(Icons.sort_rounded, color: Colors.white),
                      onSelected: (value) => setState(() => _sort = value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: _AssetSort.newest, child: Text('Newest first')),
                        PopupMenuItem(value: _AssetSort.name, child: Text('Name A-Z')),
                        PopupMenuItem(value: _AssetSort.location, child: Text('Location A-Z')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text('Search and organize everything you own.', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFFB8AED6))),
            const SizedBox(height: 15),
            Container(
              decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withAlpha(30))),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value.trim()),
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search assets...',
                  hintStyle: GoogleFonts.outfit(color: const Color(0xFFB8AED6)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFB8AED6)),
                  border: InputBorder.none,
                  suffixIcon: _searchQuery.isEmpty ? null : IconButton(onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }, icon: const Icon(Icons.clear, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPills() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          Expanded(child: _filterPill('All', _AssetFilter.all)),
          const SizedBox(width: 8),
          Expanded(child: _filterPill('Categorized', _AssetFilter.categorized)),
          const SizedBox(width: 8),
          Expanded(child: _filterPill('Uncategorized', _AssetFilter.uncategorized)),
        ],
      ),
    );
  }

  Widget _filterPill(String label, _AssetFilter filter) {
    final selected = _filter == filter;
    return GestureDetector(
      onTap: () => setState(() => _filter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryPurple : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? AppColors.primaryPurple : const Color(0xFFE7E2EF)),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textPrimary)),
      ),
    );
  }

  Widget _buildAssetList(List<LocalAsset> assets) {
    return RefreshIndicator(
      color: AppColors.primaryPurple,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        itemCount: assets.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _buildAssetCard(assets[index]),
      ),
    );
  }

  Widget _buildAssetCard(LocalAsset asset) {
    return GestureDetector(
      onTap: () => _openDetails(asset),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEFEBF6)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _thumbnail(asset),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 5),
                  Text(_categoryName(asset.categoryId), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                  if (asset.location?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text('📍 ${asset.location}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
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
        width: 108,
        height: 76,
        color: AppColors.primaryPurple.withAlpha(15),
        child: path != null && path.isNotEmpty
            ? Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, _, _) => _emoji(asset))
            : _emoji(asset),
      ),
    );
  }

  Widget _emoji(LocalAsset asset) => Center(child: Text(asset.emoji ?? '📦', style: const TextStyle(fontSize: 34)));

  Widget _buildEmptyState() {
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
          const SizedBox(height: 110),
          const Icon(Icons.inventory_2_outlined, size: 58, color: AppColors.primaryPurple),
          const SizedBox(height: 15),
          Center(child: Text(label, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
          const SizedBox(height: 6),
          Center(child: Text('Add an asset to see it here.', style: GoogleFonts.outfit(color: AppColors.textSecondary))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _database.close();
    super.dispose();
  }
}
