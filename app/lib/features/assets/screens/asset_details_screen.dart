import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../models/local_asset.dart';
import '../models/local_asset_document.dart';
import '../models/local_category.dart';
import '../widgets/full_screen_image_viewer.dart';
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
      _categoriesFuture = serviceLocator.categoryRepository.getCategories('local_user');
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
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          'Asset Details',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
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
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<LocalCategory>>(
              future: _categoriesFuture,
              builder: (context, snapshot) =>
                  _buildInfoCard(snapshot.data ?? const <LocalCategory>[]),
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
    return GestureDetector(
      onTap: path != null && path.isNotEmpty
          ? () => FullScreenImageViewer.show(context, imagePath: path, title: _asset.name)
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 180, maxHeight: 360),
          color: AppColors.primaryPurple.withValues(alpha: 0.06),
          child: path != null && path.isNotEmpty
              ? Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => _emojiPlaceholder(),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                )
              : _emojiPlaceholder(),
        ),
      ),
    );
  }

  Widget _emojiPlaceholder() => Container(
        color: AppColors.primaryPurple.withValues(alpha: 0.08),
        alignment: Alignment.center,
        child: Text(
          _asset.emoji ?? '📦',
          style: const TextStyle(fontSize: 64),
        ),
      );

  Widget _buildInfoCard(List<LocalCategory> categories) {
    final category = _categoryName(categories);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFEBF6)),
      ),
      child: Column(
        children: [
          _infoRow('Category', category),
          _divider(),
          _infoRow(
            'Location',
            _asset.location?.isNotEmpty == true
                ? _asset.location!
                : 'Not specified',
          ),
          _divider(),
          _infoRow(
            'Description',
            _asset.description?.isNotEmpty == true
                ? _asset.description!
                : 'No description',
          ),
          _divider(),
          _infoRow('QR Code', _asset.qrEnabled ? 'Enabled' : 'Disabled'),
          if (_asset.customFields.isNotEmpty) ...[
            _divider(),
            ..._asset.customFields.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.outfit(color: AppColors.textSecondary),
                      ),
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

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _divider() => const Divider(height: 1, indent: 18, endIndent: 18);

  Widget _buildDocumentsCard() {
    return FutureBuilder<List<LocalAssetDocument>>(
      future: _documentsFuture,
      builder: (context, snapshot) {
        final documents = snapshot.data ?? const <LocalAssetDocument>[];
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEFEBF6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Documents',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (documents.isEmpty)
                Text(
                  'No documents attached.',
                  style: GoogleFonts.outfit(color: AppColors.textSecondary),
                )
              else
                ...documents.map(_documentTile),
            ],
          ),
        );
      },
    );
  }

  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

  bool _isImage(LocalAssetDocument doc) {
    final ext = doc.fileType?.toLowerCase() ?? '';
    return _imageExtensions.contains(ext);
  }

  IconData _iconForFileType(String? fileType) {
    switch (fileType?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
      case 'rtf':
      case 'txt':
        return Icons.article_outlined;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_outlined;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_outlined;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
        return Icons.image_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  void _openDocument(LocalAssetDocument document) async {
    if (document.filePath.isEmpty) return;

    // If it's an image, open full-screen viewer
    if (_isImage(document) && File(document.filePath).existsSync()) {
      FullScreenImageViewer.show(context, imagePath: document.filePath, title: document.name);
      return;
    }

    // Otherwise open with system handler
    final result = await OpenFilex.open(document.filePath);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: ${result.message}')),
      );
    }
  }

  Widget _documentTile(LocalAssetDocument document) {
    final isImg = _isImage(document);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDocument(document),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.scaffoldBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Thumbnail for images, icon for documents
              if (isImg && File(document.filePath).existsSync())
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(document.filePath),
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Icon(
                      _iconForFileType(document.fileType),
                      color: AppColors.primaryPurple,
                    ),
                  ),
                )
              else
                Icon(_iconForFileType(document.fileType), color: AppColors.primaryPurple),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  document.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
              ),
              if (document.fileType != null)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    document.fileType!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
