import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../models/local_asset.dart';
import '../models/local_category.dart';
import 'add_asset_screen.dart';
import 'asset_detail_screen.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  static const _ownerId = 'local_user';

  List<LocalAsset> _assets = [];
  List<LocalCategory> _categories = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final assets = await serviceLocator.assetRepository.getAssets(_ownerId);
      final categories = await serviceLocator.categoryRepository.getCategories(_ownerId);
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _categories = categories;
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Failed to load assets: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addAsset() async {
    await AddAssetScreen.navigateTo(context);
    if (!mounted) return;
    await _load();
  }

  String _categoryName(String? id) {
    if (id == null) return 'Uncategorized';
    for (final category in _categories) {
      if (category.id == id) return category.name;
    }
    return 'Uncategorized';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _assets.where((asset) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return asset.name.toLowerCase().contains(q) ||
          _categoryName(asset.categoryId).toLowerCase().contains(q) ||
          (asset.location?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Assets',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Search assets...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? _emptyState()
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, index) => _assetCard(filtered[index]),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAsset,
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Asset'),
      ),
    );
  }

  Widget _assetCard(LocalAsset asset) {
    final path = asset.imagePath;
    final hasImage = path != null && path.isNotEmpty && File(path).existsSync();

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        await AssetDetailScreen.navigateTo(context, asset);
        if (!mounted) return;
        await _load();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEFEBF6)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 132,
              height: 88,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: hasImage
                    ? Image.file(File(path!), fit: BoxFit.cover)
                    : Container(
                        color: AppColors.primaryPurple.withAlpha(18),
                        alignment: Alignment.center,
                        child: Text(asset.emoji ?? '📦', style: const TextStyle(fontSize: 34)),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${asset.emoji ?? '📦'}  ${_categoryName(asset.categoryId)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (asset.location?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      '📍 ${asset.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.primaryPurple.withAlpha(150)),
        const SizedBox(height: 16),
        Text('No assets found', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Add an asset to start your collection.', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: AppColors.textSecondary)),
      ],
    );
  }
}
