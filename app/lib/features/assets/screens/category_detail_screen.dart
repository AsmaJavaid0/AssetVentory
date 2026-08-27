import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../models/local_asset.dart';
import '../models/local_category.dart';
import 'asset_details_screen.dart';
import 'add_asset_screen.dart';

class CategoryDetailScreen extends StatefulWidget {
  final LocalCategory category;
  const CategoryDetailScreen({super.key, required this.category});

  static Future<void> navigateTo(BuildContext context, LocalCategory category) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CategoryDetailScreen(category: category)),
    );
  }

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  static const _ownerId = 'local_user';
  late Future<List<LocalAsset>> _assetsFuture;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  void _loadAssets() {
    _assetsFuture = serviceLocator.assetRepository.getAssetsByCategory(
      ownerId: _ownerId,
      categoryId: widget.category.id,
    );
  }

  Future<void> _refreshAssets() async {
    setState(_loadAssets);
    await _assetsFuture;
  }

  Future<void> _editCategory() async {
    final controller = TextEditingController(text: widget.category.name);
    var emoji = widget.category.emoji ?? '📁';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Category', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Category name'),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: emoji,
                isExpanded: true,
                items: const ['📁', '🛠️', '📚', '👕', '🎨', '🍳', '👟', '💍', '🎮', '🚗']
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value, style: const TextStyle(fontSize: 22)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => emoji = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                await serviceLocator.categoryRepository.updateCategory(
                  LocalCategory(
                    id: widget.category.id,
                    ownerId: widget.category.ownerId,
                    name: name,
                    emoji: emoji,
                    createdAt: widget.category.createdAt,
                    updatedAt: DateTime.now(),
                  ),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _deleteCategory(int assetCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Delete "${widget.category.name}"?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          assetCount == 0
              ? 'This category will be permanently removed.'
              : '$assetCount asset${assetCount == 1 ? '' : 's'} will become uncategorized. No assets will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await serviceLocator.categoryRepository.deleteCategory(widget.category.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Text(category.emoji ?? '📁', style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Edit category',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editCategory,
          ),
          IconButton(
            tooltip: 'Delete category',
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () async {
              final assets = await _assetsFuture;
              if (mounted) _deleteCategory(assets.length);
            },
          ),
        ],
      ),
      body: FutureBuilder<List<LocalAsset>>(
        future: _assetsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load assets in this category.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          final assets = snapshot.data ?? const <LocalAsset>[];
          if (assets.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primaryPurple,
              onRefresh: _refreshAssets,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple.withAlpha(15),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(category.emoji ?? '📁', style: const TextStyle(fontSize: 38)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No assets here yet',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add an asset and assign it to ${category.name}.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primaryPurple,
            onRefresh: _refreshAssets,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: assets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _buildAssetCard(context, assets[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'category_detail_fab',
        onPressed: () async {
          await AddAssetScreen.navigateTo(context, categoryId: category.id);
          if (mounted) _refreshAssets();
        },
        backgroundColor: AppColors.primaryPurple,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Add Asset',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildAssetCard(BuildContext context, LocalAsset asset) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          await AssetDetailsScreen.navigateTo(context, asset);
          if (mounted) _loadAssets();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 76,
                  height: 68,
                  color: AppColors.primaryPurple.withAlpha(15),
                  alignment: Alignment.center,
                  child: asset.imagePath?.isNotEmpty == true
                      ? Image.file(
                          File(asset.imagePath!),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => _fallback(asset),
                        )
                      : _fallback(asset),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (asset.location?.isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              asset.location!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
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
      ),
    );
  }

  Widget _fallback(LocalAsset asset) =>
      Center(child: Text(asset.emoji ?? '📦', style: const TextStyle(fontSize: 28)));
}
