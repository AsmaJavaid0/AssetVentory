import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../models/local_category.dart';
import 'category_detail_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  static Future<void> navigateTo(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CategoriesScreen()));

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  static const _ownerId = 'local_user';
  List<LocalCategory> _categories = [];
  Map<String, int> _counts = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final categories = await serviceLocator.categoryRepository.getCategories(_ownerId);
      final assets = await serviceLocator.assetRepository.getAssets(_ownerId);
      final counts = <String, int>{};
      for (final asset in assets) { if (asset.categoryId != null) counts[asset.categoryId!] = (counts[asset.categoryId!] ?? 0) + 1; }
      if (!mounted) return;
      setState(() { _categories = categories; _counts = counts; _loading = false; });
    } catch (e, st) {
      debugPrint('Categories load error: $e'); debugPrintStack(stackTrace: st);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createCategory() async {
    final controller = TextEditingController();
    var selectedEmoji = '📂';
    final popularEmojis = [
      '📂', '💻', '📱', '🚗', '🏠', '🛠️', '📚', '👕', '🎨',
      '🍳', '👟', '💍', '🎮', '🎧', '🚲', '🍕', '⚽', '🏷️',
      '📦', '📷', '💡', '🎸', '⌚', '💼'
    ];

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Create New Category',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(sheetContext, false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                style: GoogleFonts.outfit(fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. Electronics, Tools, Books',
                  prefixIcon: Container(
                    padding: const EdgeInsets.all(10),
                    child: Text(selectedEmoji, style: const TextStyle(fontSize: 22)),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Emoji Icon',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: popularEmojis.map((emoji) {
                  final isSelected = emoji == selectedEmoji;
                  return InkWell(
                    onTap: () => setSheetState(() => selectedEmoji = emoji),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryPurple.withAlpha(35) : const Color(0xFFF6F4FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryPurple : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    try {
                      await serviceLocator.categoryRepository.createCategoryIfNotExists(
                        ownerId: _ownerId,
                        name: name,
                        emoji: selectedEmoji,
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                    } catch (e) {
                      debugPrint('Error creating category: $e');
                    }
                  },
                  child: Text(
                    'Create Category',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
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
        actions: [IconButton(onPressed: _createCategory, icon: const Icon(Icons.add_rounded), tooltip: 'Create category')],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _categories.isEmpty
                  ? ListView(children: [const SizedBox(height: 180), Center(child: Text('No categories yet.'))])
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final category = _categories[index];
                        final count = _counts[category.id] ?? 0;
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async { await CategoryDetailScreen.navigateTo(context, category); if (mounted) await _load(); },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(children: [
                                Container(width: 54, height: 54, alignment: Alignment.center, decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(15)), child: Text(category.emoji ?? '📂', style: const TextStyle(fontSize: 28))),
                                const SizedBox(width: 14),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text('$count ${count == 1 ? 'asset' : 'assets'}', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary))])),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
