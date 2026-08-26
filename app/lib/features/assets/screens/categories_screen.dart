import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../models/local_category.dart';
import 'category_detail_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  static Future<void> navigateTo(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CategoriesScreen()),
    );
  }

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  static const _ownerId = 'local_user';
  List<LocalCategory> _categories = [];
  Map<String, int> _counts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final categories = await serviceLocator.categoryRepository.getCategories(_ownerId);
      final assets = await serviceLocator.assetRepository.getAssets(_ownerId);
      final counts = <String, int>{};
      for (final asset in assets) {
        final id = asset.categoryId;
        if (id != null) counts[id] = (counts[id] ?? 0) + 1;
      }
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _counts = counts;
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Categories load error: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _createCategory() async {
    final controller = TextEditingController();
    var emoji = '📂';
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Create Category', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Category name'),
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: emoji,
                isExpanded: true,
                items: const ['📂', '🛠️', '📚', '👕', '🎨', '🍳', '👟', '💍', '🎮', '🚗']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value, style: const TextStyle(fontSize: 22))))
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
                await serviceLocator.categoryRepository.createCategoryIfNotExists(
                  ownerId: _ownerId,
                  name: name,
                  emoji: emoji,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (created == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text('Categories', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        actions: [
          IconButton(onPressed: _createCategory, icon: const Icon(Icons.add_rounded), tooltip: 'Create category'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _categories.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 180),
                        Center(child: Text('No categories yet.', style: GoogleFonts.outfit(color: AppColors.textSecondary))),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final count = _counts[category.id] ?? 0;
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
                              await CategoryDetailScreen.navigateTo(context, category);
                              if (mounted) await _load();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryPurple.withAlpha(18),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(category.emoji ?? '📂', style: const TextStyle(fontSize: 28)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 3),
                                        Text('$count ${count == 1 ? 'asset' : 'assets'}', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
