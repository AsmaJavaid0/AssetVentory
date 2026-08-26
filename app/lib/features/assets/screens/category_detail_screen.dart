import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_palette.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/local_asset.dart';
import '../models/local_category.dart';
import 'asset_details_screen.dart';
import 'add_asset_screen.dart';

class CategoryDetailScreen extends StatefulWidget {
  final LocalCategory category;
  const CategoryDetailScreen({super.key, required this.category});

  static Future<void> navigateTo(BuildContext context, LocalCategory category) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CategoryDetailScreen(category: category)),
      );

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
                decoration: InputDecoration(
                  labelText: 'Category name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppPalette.of(context).inputBorder),
                  ),
                ),
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
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
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
        title: Text('Delete "${widget.category.name}"?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Text(
          assetCount == 0
              ? 'This category will be permanently removed.'
              : '$assetCount asset${assetCount == 1 ? '' : 's'} will become uncategorized. No assets will be deleted.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
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
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.isDark ? AppColors.heroDarkBg : AppColors.scaffoldBg,
      body: FutureBuilder<List<LocalAsset>>(
        future: _assetsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final assets = snapshot.data ?? const <LocalAsset>[];
          return Column(
            children: [
              AppHeader.solid(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context, true),
                ),
                title: category.name,
                subtitle: '${assets.length} item${assets.length == 1 ? '' : 's'}',
                actions: [
                  HeaderIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit category',
                    onTap: _editCategory,
                  ),
                  HeaderIconButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete category',
                    onTap: () => _deleteCategory(assets.length),
                  ),
                ],
              ),
              Expanded(
                child: assets.isEmpty
                    ? _buildEmpty(palette, category)
                    : RefreshIndicator(
                        color: AppColors.primaryPurple,
                        onRefresh: _refreshAssets,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: assets.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _buildAssetCard(palette, assets[index]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await AddAssetScreen.navigateTo(context, categoryId: category.id);
          if (mounted) _refreshAssets();
        },
        backgroundColor: AppColors.primaryPurple,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Asset',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildEmpty(AppPalette palette, LocalCategory category) {
    return RefreshIndicator(
      color: AppColors.primaryPurple,
      onRefresh: _refreshAssets,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No assets here yet',
              message: 'Add an asset and assign it to ${category.name}.',
              actionLabel: 'Add Asset',
              onAction: () async {
                await AddAssetScreen.navigateTo(context, categoryId: category.id);
                if (mounted) _refreshAssets();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetCard(AppPalette palette, LocalAsset asset) {
    return Material(
      color: palette.surface,
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
                        color: palette.onSurface,
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
                              style: GoogleFonts.outfit(fontSize: 12, color: palette.onSurfaceMuted),
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
      Center(child: Text(asset.emoji ?? '📦', style: const TextStyle(fontSize: 30)));
}
