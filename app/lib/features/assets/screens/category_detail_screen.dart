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
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryDetailScreen(category: category)));
  }

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late Future<List<LocalAsset>> _assetsFuture;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  void _loadAssets() {
    setState(() {
      _assetsFuture = serviceLocator.assetRepository.getAssets(widget.category.ownerId);
    });
  }

  Future<void> _editCategory() async {
    final controller = TextEditingController(text: widget.category.name);
    var emoji = widget.category.emoji ?? '📁';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Category', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Category name')),
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: emoji,
              isExpanded: true,
              items: const ['📁', '🛠️', '📚', '👕', '🎨', '🍳', '👟', '💍', '🎮', '🚗']
                  .map((value) => DropdownMenuItem(value: value, child: Text(value, style: const TextStyle(fontSize: 22))))
                  .toList(),
              onChanged: (value) {
                if (value != null) setDialogState(() => emoji = value);
              },
            ),
          ]),
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
        title: Text('Delete "${widget.category.name}"?', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Text(assetCount == 0
            ? 'This category will be permanently removed.'
            : '$assetCount asset${assetCount == 1 ? '' : 's'} will become uncategorized. No assets will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
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
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          '${category.emoji ?? '📁'} ${category.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(tooltip: 'Edit category', icon: const Icon(Icons.edit_outlined), onPressed: _editCategory),
          IconButton(
            tooltip: 'Delete category',
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () async {
              final assets = await _assetsFuture;
              if (mounted) _deleteCategory(assets.where((a) => a.categoryId == category.id).length);
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
          if (snapshot.hasError) return const Center(child: Text('Unable to load assets.'));
          final assets = (snapshot.data ?? []).where((a) => a.categoryId == category.id).toList();
          if (assets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 54, color: AppColors.primaryPurple),
                    const SizedBox(height: 14),
                    Text('No assets in this category yet.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Text('Add an asset using the button below.',
                        style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primaryPurple,
            onRefresh: () async => _loadAssets(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
              itemCount: assets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final asset = assets[index];
                return GestureDetector(
                  onTap: () async {
                    await AssetDetailsScreen.navigateTo(context, asset);
                    if (mounted) _loadAssets();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFEFEBF6)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(5),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 76,
                            height: 62,
                            color: AppColors.primaryPurple.withAlpha(15),
                            child: asset.imagePath?.isNotEmpty == true
                                ? Image.file(
                                    File(asset.imagePath!),
                                    fit: BoxFit.cover,
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (asset.location?.isNotEmpty == true) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        asset.location!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
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
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await AddAssetScreen.navigateTo(context, categoryId: category.id);
          if (mounted) _loadAssets();
        },
        backgroundColor: AppColors.primaryPurple,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Asset', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _fallback(LocalAsset asset) => Center(
        child: Text(asset.emoji ?? '📦', style: const TextStyle(fontSize: 28)),
      );
}
