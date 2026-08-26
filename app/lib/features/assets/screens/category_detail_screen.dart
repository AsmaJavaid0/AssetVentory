import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../models/local_asset.dart';
import '../models/local_category.dart';
import '../../home/widgets/asset_detail_modal.dart';
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
    _assetsFuture = serviceLocator.assetRepository.getAssets(widget.category.ownerId);
  }

  Future<void> _editCategory() async {
    final controller = TextEditingController(text: widget.category.name);
    var emoji = widget.category.emoji ?? '📁';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Category'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Category name')),
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: emoji, isExpanded: true,
              items: const ['📁','🛠️','📚','👕','🎨','🍳','👟','💍','🎮','🚗'].map((value) => DropdownMenuItem(value: value, child: Text(value, style: TextStyle(fontSize: 22)))).toList(),
              onChanged: (value) { if (value != null) setDialogState(() => emoji = value); },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await serviceLocator.categoryRepository.updateCategory(LocalCategory(id: widget.category.id, ownerId: widget.category.ownerId, name: name, emoji: emoji, createdAt: widget.category.createdAt, updatedAt: DateTime.now()));
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            }, child: const Text('Save')),
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
        title: Text('Delete "${widget.category.name}"?'),
        content: Text(assetCount == 0 ? 'This category will be permanently removed.' : '$assetCount asset${assetCount == 1 ? '' : 's'} will become uncategorized. No assets will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
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
        backgroundColor: Colors.white, surfaceTintColor: Colors.white, elevation: 0,
        title: Text('${category.emoji ?? '📁'} ${category.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        actions: [
          IconButton(tooltip: 'Edit category', icon: const Icon(Icons.edit_outlined), onPressed: _editCategory),
          IconButton(tooltip: 'Delete category', icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error), onPressed: () async { final assets = await _assetsFuture; if (mounted) _deleteCategory(assets.where((a) => a.categoryId == category.id).length); }),
        ],
      ),
      body: FutureBuilder<List<LocalAsset>>(
        future: _assetsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('Unable to load assets.'));
          final assets = (snapshot.data ?? []).where((a) => a.categoryId == category.id).toList();
          if (assets.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('No assets in this category yet.', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: AppColors.textSecondary))));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: assets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final asset = assets[index];
              return Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 82, height: 62, child: asset.imagePath?.isNotEmpty == true ? Image.file(File(asset.imagePath!), fit: BoxFit.contain, errorBuilder: (_, _, _) => _fallback(asset)) : _fallback(asset))),
                  title: Text(asset.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  subtitle: asset.location?.isNotEmpty == true ? Text(asset.location!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => AssetDetailModal.show(context, asset, categoryName: category.name),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddAssetScreen.navigateTo(context, categoryId: category.id),
        backgroundColor: AppColors.primaryPurple,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Asset', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _fallback(LocalAsset asset) => Container(color: AppColors.primaryPurple.withValues(alpha: 0.08), alignment: Alignment.center, child: Text(asset.emoji ?? '📦', style: const TextStyle(fontSize: 25)));
}
