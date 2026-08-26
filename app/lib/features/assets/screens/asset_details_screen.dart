import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_palette.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/local_asset.dart';
import '../models/local_asset_document.dart';
import '../models/local_category.dart';
import 'edit_asset_screen.dart';

class AssetDetailsScreen extends StatefulWidget {
  final LocalAsset asset;
  const AssetDetailsScreen({super.key, required this.asset});

  static Future<void> navigateTo(BuildContext context, LocalAsset asset) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AssetDetailsScreen(asset: asset)),
    );
  }

  @override
  State<AssetDetailsScreen> createState() => _AssetDetailsScreenState();
}

class _AssetDetailsScreenState extends State<AssetDetailsScreen> {
  late LocalAsset _asset;
  late Future<List<LocalAssetDocument>> _documentsFuture;
  late Future<List<LocalCategory>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _asset = widget.asset;
    _documentsFuture = _loadDocuments();
    _categoriesFuture = serviceLocator.categoryRepository.getCategories('local_user');
  }

  Future<List<LocalAssetDocument>> _loadDocuments() =>
      serviceLocator.assetDocumentRepository.getDocuments(_asset.id);

  String _categoryName(List<LocalCategory> categories) {
    if (_asset.categoryId == null) return 'Uncategorized';
    for (final category in categories) {
      if (category.id == _asset.categoryId) return category.name;
    }
    return 'Uncategorized';
  }

  Future<void> _edit() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => EditAssetScreen(asset: _asset)),
    );
    if (!mounted) return;
    final updated = await serviceLocator.assetRepository.getAsset(_asset.id);
    if (!mounted) return;
    if (updated == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _asset = updated;
      _documentsFuture = _loadDocuments();
    });
  }

  Future<void> _refresh() async {
    final updated = await serviceLocator.assetRepository.getAsset(_asset.id);
    if (!mounted) return;
    if (updated == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _asset = updated;
      _documentsFuture = _loadDocuments();
      _categoriesFuture = serviceLocator.categoryRepository.getCategories('local_user');
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.isDark ? AppColors.heroDarkBg : AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Asset Details'),
        actions: [
          IconButton(
            tooltip: 'Edit asset',
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryPurple,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            _buildPhoto(),
            const SizedBox(height: 18),
            Text(
              _asset.name,
              style: GoogleFonts.outfit(
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: palette.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<LocalCategory>>(
              future: _categoriesFuture,
              builder: (context, snapshot) => _buildInfoCard(snapshot.data ?? const <LocalCategory>[]),
            ),
            const SizedBox(height: 18),
            _buildDocumentsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto() {
    final path = _asset.imagePath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 180, maxHeight: 360),
        color: AppColors.primaryPurple.withValues(alpha: 0.06),
        child: path != null && path.isNotEmpty
            ? Image.file(File(path), fit: BoxFit.contain, errorBuilder: (_, _, _) => _emojiPlaceholder())
            : _emojiPlaceholder(),
      ),
    );
  }

  Widget _emojiPlaceholder() => Container(
        color: AppColors.primaryPurple.withValues(alpha: 0.08),
        alignment: Alignment.center,
        child: Text(_asset.emoji ?? '📦', style: const TextStyle(fontSize: 64)),
      );

  Widget _buildInfoCard(List<LocalCategory> categories) {
    final palette = AppPalette.of(context);
    final category = _categoryName(categories);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          _infoRow(palette, 'Category', category),
          _divider(palette),
          _infoRow(palette, 'Location',
              _asset.location?.isNotEmpty == true ? _asset.location! : 'Not specified'),
          _divider(palette),
          _infoRow(palette, 'Description',
              _asset.description?.isNotEmpty == true ? _asset.description! : 'No description'),
          _divider(palette),
          _infoRow(palette, 'QR Code', _asset.qrEnabled ? 'Enabled' : 'Disabled'),
          if (_asset.customFields.isNotEmpty) ...[
            _divider(palette),
            ..._asset.customFields.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(entry.key,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(entry.value,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.outfit(color: palette.onSurfaceMuted)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(AppPalette palette, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(label,
                  style:
                      GoogleFonts.outfit(fontWeight: FontWeight.w600, color: palette.onSurfaceMuted)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(value,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: palette.onSurface)),
            ),
          ],
        ),
      );

  Widget _divider(AppPalette palette) =>
      Divider(height: 1, indent: 18, endIndent: 18, color: palette.divider);

  Widget _buildDocumentsCard() {
    final palette = AppPalette.of(context);
    return FutureBuilder<List<LocalAssetDocument>>(
      future: _documentsFuture,
      builder: (context, snapshot) {
        final documents = snapshot.data ?? const <LocalAssetDocument>[];
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Documents',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator()))
              else if (documents.isEmpty)
                Text('No documents attached.',
                    style: GoogleFonts.outfit(color: palette.onSurfaceMuted))
              else
                ...documents.map((d) => _documentTile(d, palette)),
            ],
          ),
        );
      },
    );
  }

  Widget _documentTile(LocalAssetDocument document, AppPalette palette) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: palette.isDark ? AppColors.heroDarkBgDarker : AppColors.scaffoldBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, color: AppColors.primaryPurple),
            const SizedBox(width: 10),
            Expanded(
              child: Text(document.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ),
            if (document.fileType != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(document.fileType!.toUpperCase(),
                    style: GoogleFonts.outfit(fontSize: 10, color: palette.textMuted)),
              ),
          ],
        ),
      );
}
