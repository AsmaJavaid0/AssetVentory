import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/asset_avatar.dart';
import '../../auth/services/firestore_service.dart';
import '../../home/widgets/asset_detail_modal.dart';
import '../models/asset_model.dart';
import '../models/category_model.dart';
import 'add_asset_screen.dart';

class CategoryDetailScreen extends StatelessWidget {
  final CategoryModel category;

  const CategoryDetailScreen({super.key, required this.category});

  static Future<void> navigateTo(BuildContext context, CategoryModel category) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryDetailScreen(category: category),
      ),
    );
  }

  FirestoreService get _firestoreService => FirestoreService();

  Future<void> _editCategory(BuildContext context) async {
    final nameController = TextEditingController(text: category.name);
    var emoji = category.emoji ?? '📁';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Edit Category',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Category name'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: emoji,
                isExpanded: true,
                items:
                    const [
                          '📁',
                          '🛠️',
                          '📚',
                          '👕',
                          '🎨',
                          '🍳',
                          '👟',
                          '💍',
                          '🎮',
                          '🚗',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              value,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) =>
                    value == null ? null : setDialogState(() => emoji = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                try {
                  await _firestoreService.updateCategory(
                    CategoryModel(
                      id: category.id,
                      ownerId: category.ownerId,
                      name: name,
                      emoji: emoji,
                      createdAt: category.createdAt,
                      updatedAt: DateTime.now(),
                    ),
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  debugPrint('Error updating category: $e');
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to update category. Please try again.'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) Navigator.pop(context);
  }

  Future<void> _deleteCategory(BuildContext context, int assetCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Delete "${category.name}"?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          assetCount == 0
              ? 'This category will be permanently removed.'
              : '$assetCount asset${assetCount == 1 ? '' : 's'} will become uncategorized. No assets will be deleted.',
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
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
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Return to the category list straight away. A Firestore batch can take
    // a noticeable moment to complete (especially with offline persistence),
    // so waiting here made the delete action appear unresponsive.
    Navigator.of(context).pop();
    try {
      await _firestoreService.deleteCategory(category.id);
    } catch (e) {
      debugPrint('Error deleting category: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<List<AssetModel>>(
      stream: _firestoreService.streamUserAssets(uid),
      builder: (context, snapshot) {
        final assets = (snapshot.data ?? [])
            .where((asset) => asset.categoryId == category.id)
            .toList();
        return Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: Text(
              '${category.emoji ?? '📁'} ${category.name}',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit category',
                onPressed: () => _editCategory(context),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                tooltip: 'Delete category',
                onPressed: () => _deleteCategory(context, assets.length),
              ),
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : assets.isEmpty
              ? Center(
                  child: Text(
                    'No assets in this category yet.',
                    style: GoogleFonts.outfit(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  itemCount: assets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final asset = assets[index];
                    return Card(
                      child: ListTile(
                        leading: AssetAvatar(
                          imageUrl: asset.imageUrl,
                          emoji: asset.emoji,
                          size: 40,
                          borderRadius: 10,
                          fontSize: 22,
                        ),
                        title: Text(
                          asset.name,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: asset.location?.isNotEmpty == true
                            ? Text(asset.location!, style: GoogleFonts.outfit())
                            : null,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => AssetDetailModal.show(
                          context,
                          asset,
                          categoryName: category.name,
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                AddAssetScreen.navigateTo(context, categoryId: category.id),
            backgroundColor: AppColors.primaryPurple,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text(
              'Add Asset',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}
