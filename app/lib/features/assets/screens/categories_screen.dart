import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../models/local_category.dart';
import 'category_assets_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  static const _ownerId = 'local_user';
  List<LocalCategory> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final categories = await serviceLocator.categoryRepository.getCategories(_ownerId);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load categories: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final controller = TextEditingController();
    String emoji = '📂';

    final result = await showDialog<(String, String)?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('New Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Category name'),
              ),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: emoji,
                isExpanded: true,
                items: const ['📂', '🚗', '💻', '📱', '🏠', '🛠️', '📚', '👕', '🎮', '💍']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 24))))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => emoji = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) Navigator.pop(dialogContext, (name, emoji));
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (result == null) return;

    await serviceLocator.categoryRepository.createCategoryIfNotExists(
      ownerId: _ownerId,
      name: result.$1,
      emoji: result.$2,
    );

    if (!mounted) return;
    await _load();
  }

  Future<void> _delete(LocalCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${category.name}?'),
        content: const Text('Assets using this category will become Uncategorized.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await serviceLocator.categoryRepository.deleteCategory(category.id);
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Categories', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? _empty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) => _categoryCard(_categories[index]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.create_new_folder_rounded),
        label: const Text('New Category'),
      ),
    );
  }

  Widget _categoryCard(LocalCategory category) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryAssetsScreen(category: category)));
      },
      onLongPress: () => _delete(category),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEFEBF6)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: AppColors.primaryPurple.withAlpha(18), borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: Text(category.emoji ?? '📂', style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(category.name, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📂', style: TextStyle(fontSize: 58)),
          const SizedBox(height: 16),
          Text('No categories yet', style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Create categories to organize your assets.', style: GoogleFonts.outfit(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
