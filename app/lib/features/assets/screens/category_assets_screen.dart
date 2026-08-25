import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../models/local_asset.dart';
import '../models/local_category.dart';
import 'asset_detail_screen.dart';

class CategoryAssetsScreen extends StatefulWidget {
  final LocalCategory category;

  const CategoryAssetsScreen({super.key, required this.category});

  @override
  State<CategoryAssetsScreen> createState() => _CategoryAssetsScreenState();
}

class _CategoryAssetsScreenState extends State<CategoryAssetsScreen> {
  List<LocalAsset> _assets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await serviceLocator.assetRepository.getAssets('local_user');
    if (!mounted) return;
    setState(() {
      _assets = all.where((asset) => asset.categoryId == widget.category.id).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${widget.category.emoji ?? '📂'} ${widget.category.name}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _assets.isEmpty
              ? Center(child: Text('No assets in this category.', style: GoogleFonts.outfit(color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _assets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final asset = _assets[index];
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
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 132,
                                height: 88,
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
                            Expanded(child: Text(asset.name, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700))),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
