import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/local_file_storage.dart';
import '../../../core/utils/wave_clipper.dart';
import '../../../core/widgets/custom_text_field.dart';

import '../models/local_asset.dart';
import '../models/local_category.dart';
import '../repositories/asset_repository.dart';
import '../repositories/category_repository.dart';
import 'asset_details_screen.dart';

import '../../home/widgets/add_quick_asset_sheet.dart';

enum _AssetSort { newest, name, location }

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final AppDatabase _database;
  late final AssetRepository _assetRepository;
  late final CategoryRepository _categoryRepository;

  List<LocalAsset> _assets = [];
  List<LocalCategory> _categories = [];
  bool _isLoadingAssets = true;
  bool _isLoadingCategories = true;
  String? _selectedCategoryId;
  String _searchQuery = '';
  _AssetSort _sort = _AssetSort.newest;
  Timer? _searchDebounce;

  static const String _localUserId = 'local_user';

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _assetRepository = AssetRepository(
      database: _database,
      fileStorage: LocalFileStorage(),
    );
    _categoryRepository = CategoryRepository(database: _database);
    _loadLocalAssets();
    _loadLocalCategories();
  }

  Future<void> _loadLocalAssets() async {
    try {
      final assets = await _assetRepository.getAssets(_localUserId);
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _isLoadingAssets = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading local assets: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _assets = [];
        _isLoadingAssets = false;
      });
    }
  }

  Future<void> _loadLocalCategories() async {
    try {
      final categories = await _categoryRepository.getCategories(_localUserId);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading local categories: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _categories = [];
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _reloadData() async {
    await Future.wait([_loadLocalAssets(), _loadLocalCategories()]);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
    });
  }

  Future<void> _openAssetDetails(LocalAsset asset) async {
    await AssetDetailsScreen.navigateTo(context, asset);
    if (!mounted) return;
    await _reloadData();
  }

  void _showCreateCategoryDialog() {
    final nameController = TextEditingController();
    String selectedEmoji = '📂';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Create New Category', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: nameController,
                hintText: 'e.g. Tools, Books, Office',
                labelText: 'Category Name',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Category Emoji:', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 14),
                  DropdownButton<String>(
                    value: selectedEmoji,
                    items: const ['📂', '🛠️', '📚', '👔', '🎨', '🍳', '👟', '💍', '🎮', '🚗']
                        .map((emoji) => DropdownMenuItem(value: emoji, child: Text(emoji, style: const TextStyle(fontSize: 22))))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedEmoji = value);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                try {
                  final categoryId = await _categoryRepository.createCategoryIfNotExists(
                    ownerId: _localUserId,
                    name: name,
                    emoji: selectedEmoji,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  await _loadLocalCategories();
                  if (!mounted) return;
                  setState(() => _selectedCategoryId = categoryId);
                } catch (e) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Failed to create category. Please try again.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCategory(LocalCategory category, int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: Text(count > 0
            ? 'This category has $count item${count == 1 ? '' : 's'}. They will become Uncategorized.'
            : 'This will permanently remove the category.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _categoryRepository.deleteCategory(category.id);
      if (!mounted) return;
      if (_selectedCategoryId == category.id) {
        setState(() => _selectedCategoryId = null);
      }
      await _reloadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete category.')));
    }
  }

  List<LocalAsset> _getFilteredAssets() {
    final query = _searchQuery.toLowerCase();
    final result = _assets.where((asset) {
      final matchesCategory = _selectedCategoryId == null || asset.categoryId == _selectedCategoryId;
      final matchesSearch = asset.name.toLowerCase().contains(query) ||
          (asset.location?.toLowerCase().contains(query) ?? false) ||
          (asset.description?.toLowerCase().contains(query) ?? false);
      return matchesCategory && matchesSearch;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAssets || _isLoadingCategories) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filteredAssets = _getFilteredAssets();
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(),
          _buildCategorySelector(_categories, _assets),
          Expanded(
            child: filteredAssets.isEmpty ? _buildEmptyState() : _buildAssetGrid(filteredAssets, _categories),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await AddQuickAssetSheet.show(context);
          if (!mounted) return;
          await _reloadData();
        },
        backgroundColor: AppColors.primaryPurple,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Asset', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Widget _buildAssetGrid(List<LocalAsset> assets, List<LocalCategory> categories) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.15,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        final asset = assets[index];
        final category = categories.firstWhere(
          (category) => category.id == asset.categoryId,
          orElse: () => LocalCategory(id: '', ownerId: _localUserId, name: '', createdAt: DateTime.now(), updatedAt: DateTime.now()),
        );

        return GestureDetector(
          onTap: () => _openAssetDetails(asset),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEFEBF6), width: 1.1),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildLocalAssetAvatar(asset),
                    if (asset.qrEnabled)
                      IconButton(
                        tooltip: 'Show QR code',
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.qr_code_2_rounded, size: 17, color: AppColors.primaryPurple),
                        onPressed: () => _showLocalAssetPreview(asset, category.name),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  category.name.isEmpty ? 'Uncategorized' : category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocalAssetAvatar(LocalAsset asset) {
    final imagePath = asset.imagePath;
    if (imagePath != null && imagePath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(imagePath),
          width: 70,
          height: 58,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _emojiAvatar(asset),
        ),
      );
    }
    return _emojiAvatar(asset);
  }

  Widget _emojiAvatar(LocalAsset asset) {
    return Container(
      width: 70,
      height: 58,
      decoration: BoxDecoration(color: AppColors.primaryPurple.withAlpha(15), borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.center,
      child: Text(asset.emoji ?? '📦', style: const TextStyle(fontSize: 30)),
    );
  }

  Widget _buildCategorySelector(List<LocalCategory> categories, List<LocalAsset> assets) {
    final counts = <String, int>{};
    for (final asset in assets) {
      final id = asset.categoryId;
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }

    return SizedBox(
      height: 132,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildFolderCard(
              title: 'All Assets',
              emoji: '📦',
              count: assets.length,
              isSelected: _selectedCategoryId == null,
              onTap: () => setState(() => _selectedCategoryId = null),
            );
          }
          final category = categories[index - 1];
          return _buildFolderCard(
            title: category.name,
            emoji: category.emoji ?? '📂',
            count: counts[category.id] ?? 0,
            isSelected: _selectedCategoryId == category.id,
            onTap: () => setState(() => _selectedCategoryId = category.id),
            onLongPress: () => _confirmDeleteCategory(category, counts[category.id] ?? 0),
          );
        },
      ),
    );
  }

  Widget _buildFolderCard({required String title, required String emoji, required int count, required bool isSelected, required VoidCallback onTap, VoidCallback? onLongPress}) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12, bottom: 8, top: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPurple : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primaryPurple : const Color(0xFFE4DFEE), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textPrimary)),
                Text('$count ${count == 1 ? 'item' : 'items'}', style: GoogleFonts.outfit(fontSize: 11, color: isSelected ? Colors.white70 : AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return ClipPath(
      clipper: WaveClipper(),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Collection', style: GoogleFonts.outfit(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700)),
                PopupMenuButton<_AssetSort>(
                  tooltip: 'Sort assets',
                  icon: const Icon(Icons.sort_rounded, color: Colors.white),
                  onSelected: (sort) => setState(() => _sort = sort),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: _AssetSort.newest, child: Text('Newest first')),
                    const PopupMenuItem(value: _AssetSort.name, child: Text('Name A-Z')),
                    const PopupMenuItem(value: _AssetSort.location, child: Text('Location A-Z')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Search, filter and organize your belongings.', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFFB8AED6))),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withAlpha(30))),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search assets, locations or notes...',
                  hintStyle: GoogleFonts.outfit(color: const Color(0xFFB8AED6), fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFB8AED6)),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: Colors.white), onPressed: () { _searchController.clear(); _onSearchChanged(''); }) : null,
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text('No assets found.', style: GoogleFonts.outfit(color: AppColors.textSecondary)),
    );
  }

  void _showLocalAssetPreview(LocalAsset asset, String categoryName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(asset.name),
        content: Text(categoryName.isEmpty ? 'Uncategorized' : categoryName),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _database.close();
    super.dispose();
  }
}
