import 'dart:async';
import 'dart:io';
import '../repositories/asset_repository.dart';
import '../models/local_asset.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/wave_clipper.dart';
import '../../../core/widgets/custom_text_field.dart';

import '../models/category_model.dart';
import '../../auth/services/firestore_service.dart';
import '../../home/widgets/add_quick_asset_sheet.dart';
import 'category_detail_screen.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/local_file_storage.dart';

enum _AssetSort { newest, name, location }

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  late final Stream<List<CategoryModel>> _categoriesStream;

  final AssetRepository _assetRepository = AssetRepository(
  database: AppDatabase(),
  fileStorage: LocalFileStorage(),
);

List<LocalAsset> _assets = [];
bool _isLoadingAssets = true;

  String? _selectedCategoryId; // Null for 'All'
  String _searchQuery = '';
  _AssetSort _sort = _AssetSort.newest;

  Timer? _searchDebounce;

 @override
void initState() {
  super.initState();

  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'local_user';

  _categoriesStream = _firestoreService.streamUserCategories(uid);

  _loadLocalAssets();
}

Future<void> _loadLocalAssets() async {
  try {
    final assets = await _assetRepository.getAssets('local_user');

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

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // Debounced so a full filter/sort/rebuild of the grid only happens once
  // typing pauses for 250ms, instead of on every keystroke.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _searchQuery = value);
    });
  }

  // Create Category Inline Dialog
  void _showCreateCategoryDialog() {
    final nameCtrl = TextEditingController();
    String catEmoji = '📂';
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Create New Category',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomTextField(
                    controller: nameCtrl,
                    hintText: 'e.g. Tools, Books, Office',
                    labelText: 'Category Name',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Category Emoji:',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      DropdownButton<String>(
                        value: catEmoji,
                        items:
                            [
                                  '📂',
                                  '🛠️',
                                  '📚',
                                  '👔',
                                  '🎨',
                                  '🍳',
                                  '👟',
                                  '💍',
                                  '🎮',
                                  '🚗',
                                ]
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => catEmoji = val);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isNotEmpty) {
                      try {
                        final newCat = CategoryModel(
                          id: '',
                          ownerId: user.uid,
                          name: name,
                          emoji: catEmoji,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        final catId = await _firestoreService.addCategory(newCat);
                        if (!context.mounted) return;
                        setState(() {
                          _selectedCategoryId = catId;
                        });
                        Navigator.pop(context);
                      } catch (e) {
                        debugPrint('Error creating category: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to create category. Please try again.'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Create',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppColors.scaffoldBg,
    body: StreamBuilder<List<CategoryModel>>(
      stream: _categoriesStream,
      builder: (context, catSnapshot) {
        final categories = catSnapshot.data ?? [];

        if (_isLoadingAssets) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final assets = _assets;

        final filteredAssets = assets.where((asset) {
          final matchesCategory =
              _selectedCategoryId == null ||
              asset.categoryId == _selectedCategoryId;

          final query = _searchQuery.toLowerCase();

          final matchesSearch =
              asset.name.toLowerCase().contains(query) ||
              (asset.location?.toLowerCase().contains(query) ?? false) ||
              (asset.description?.toLowerCase().contains(query) ?? false);

          return matchesCategory && matchesSearch;
        }).toList();

        filteredAssets.sort((a, b) {
          switch (_sort) {
            case _AssetSort.name:
              return a.name
                  .toLowerCase()
                  .compareTo(b.name.toLowerCase());

            case _AssetSort.location:
              return (a.location ?? '')
                  .toLowerCase()
                  .compareTo((b.location ?? '').toLowerCase());

            case _AssetSort.newest:
              return b.createdAt.compareTo(a.createdAt);
          }
        });

        return Column(
          children: [
            _buildHeader(),

            _buildCategorySelector(
              categories,
              assets,
            ),

            Expanded(
              child: filteredAssets.isEmpty
                  ? _buildEmptyState()
                  : _buildAssetGrid(
                      filteredAssets,
                      categories,
                    ),
            ),
          ],
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        await AddQuickAssetSheet.show(context);
        await _loadLocalAssets();
      },
      backgroundColor: AppColors.primaryPurple,
      icon: const Icon(
        Icons.add_rounded,
        color: Colors.white,
      ),
      label: Text(
        'Add Asset',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
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
                Text(
                  'My Collection',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                PopupMenuButton<_AssetSort>(
                  tooltip: 'Sort assets',
                  icon: const Icon(Icons.sort_rounded, color: Colors.white),
                  onSelected: (sort) => setState(() => _sort = sort),
                  itemBuilder: (context) => [
                    _buildSortItem(_AssetSort.newest, 'Newest first'),
                    _buildSortItem(_AssetSort.name, 'Name A-Z'),
                    _buildSortItem(_AssetSort.location, 'Location A-Z'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Search, filter and organize your belongings.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFFB8AED6),
              ),
            ),
            const SizedBox(height: 16),

            // Search Text Field
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withAlpha(30)),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search assets, locations or notes...',
                  hintStyle: GoogleFonts.outfit(
                    color: const Color(0xFFB8AED6),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFFB8AED6),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            _searchDebounce?.cancel();
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<_AssetSort> _buildSortItem(_AssetSort sort, String label) {
    return PopupMenuItem(
      value: sort,
      child: Row(
        children: [
          Icon(
            _sort == sort
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 18,
            color: _sort == sort
                ? AppColors.primaryPurple
                : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.outfit()),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(
    List<CategoryModel> categories,
    List<LocalAsset> assets,
  ) {
    // Count items per category
    final Map<String?, int> counts = {};
    for (var asset in assets) {
      counts[asset.categoryId] = (counts[asset.categoryId] ?? 0) + 1;
    }

    return Container(
      height: 124,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount:
            categories.length + 2, // +1 for 'All', +1 for 'Create New Folder'
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" card
            final count = assets.length;
            final isSelected = _selectedCategoryId == null;
            return _buildFolderCard(
              title: 'All Assets',
              emoji: '📂',
              count: count,
              isSelected: isSelected,
              onTap: () {
                setState(() => _selectedCategoryId = null);
              },
            );
          }

          if (index == categories.length + 1) {
            // Add category inline card
            return GestureDetector(
              onTap: _showCreateCategoryDialog,
              child: Container(
                width: 110,
                margin: const EdgeInsets.only(right: 4, bottom: 8, top: 4),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFDDD8E8),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withAlpha(15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppColors.primaryPurple,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Add Folder',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final cat = categories[index - 1];
          final count = counts[cat.id] ?? 0;
          final isSelected = _selectedCategoryId == cat.id;

          return _buildFolderCard(
            title: cat.name,
            emoji: cat.emoji ?? '📂',
            count: count,
            isSelected: isSelected,
            onTap: () {
              CategoryDetailScreen.navigateTo(context, cat);
            },
          );
        },
      ),
    );
  }

  // Long-press a category folder to delete it. Any assets still pointing
  // at this category are unlinked (set to Uncategorized) rather than left
  // dangling — see FirestoreService.deleteCategory.
  // ignore: unused_element
  void _confirmDeleteCategory(CategoryModel cat, int count) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete "${cat.name}"?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          count > 0
              ? 'This category has $count item${count == 1 ? '' : 's'}. They will move to Uncategorized, not be deleted.'
              : 'This will permanently remove the category folder.',
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (_selectedCategoryId == cat.id) {
                setState(() => _selectedCategoryId = null);
              }
              await _firestoreService.deleteCategory(cat.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderCard({
    required String title,
    required String emoji,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          // Background Page (offset shadow page)
          Positioned(
            right: 4,
            top: 8,
            left: 12,
            bottom: 4,
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryPurple.withAlpha(50)
                    : const Color(0xFFE4DFEE),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
            ),
          ),
          // Folder Body
          Container(
            width: 110,
            margin: const EdgeInsets.only(right: 12, bottom: 8, top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryPurple : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryPurple
                    : const Color(0xFFE4DFEE),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isSelected ? 30 : 8),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Emoji Circle
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withAlpha(40)
                        : AppColors.primaryPurple.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 8),
                // Name and Count
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count ${count == 1 ? 'item' : 'items'}',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white70
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchQuery.isNotEmpty || _selectedCategoryId != null;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFF1EEFB),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching
                    ? Icons.search_off_rounded
                    : Icons.inventory_2_outlined,
                color: AppColors.primaryPurple,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isSearching
                  ? 'No matching assets found'
                  : 'Your collection is empty',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSearching
                  ? 'Try adjusting your search query or choosing a different category.'
                  : 'Tap the "+" button below to add your first asset.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
void _showLocalAssetPreview(
  LocalAsset asset,
  String categoryName,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(28),
      ),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              asset.emoji ?? '📦',
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              asset.name,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              categoryName.isNotEmpty
                  ? categoryName
                  : 'Uncategorized',
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
              ),
            ),
            if (asset.location != null &&
                asset.location!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '📍 ${asset.location}',
                style: GoogleFonts.outfit(),
              ),
            ],
            if (asset.description != null &&
                asset.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                asset.description!,
                style: GoogleFonts.outfit(),
              ),
            ],
          ],
        ),
      );
    },
  );
}
Widget _buildLocalAssetAvatar(LocalAsset asset) {
  if (asset.imagePath != null &&
      asset.imagePath!.isNotEmpty) {
    final file = File(asset.imagePath!);

    if (file.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          file,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
        ),
      );
    }
  }

  return Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: AppColors.primaryPurple.withAlpha(20),
      borderRadius: BorderRadius.circular(10),
    ),
    alignment: Alignment.center,
    child: Text(
      asset.emoji ?? '📦',
      style: const TextStyle(fontSize: 20),
    ),
  );
}
 Widget _buildAssetGrid(
  List<LocalAsset> assets,
  List<CategoryModel> categories,
) {
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
        final cat = categories.firstWhere(
          (c) => c.id == asset.categoryId,
          orElse: () => CategoryModel(
            id: '',
            ownerId: '',
            name: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        return GestureDetector(
          onTap: () {
  _showLocalAssetPreview(asset, cat.name);
},
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEFEBF6), width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(5),
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
                   _buildLocalAssetAvatar(asset),
                    // Linked indicators (custom fields and QR).
                    Row(
                      children: [
                        if (asset.customFields.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(right: 4.0),
                            child: Icon(
                              Icons.list_alt_rounded,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                        if (asset.qrEnabled)
                          IconButton(
                            tooltip: 'Show QR code',
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.qr_code_2_rounded,
                              size: 17,
                              color: AppColors.primaryPurple,
                            ),
                           onPressed: () {
  _showLocalAssetPreview(asset, cat.name);
},
                          ),
                      ],
                    ),
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
                  cat.name.isNotEmpty ? cat.name : 'Uncategorized',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (asset.location != null && asset.location!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 10,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          asset.location!,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
