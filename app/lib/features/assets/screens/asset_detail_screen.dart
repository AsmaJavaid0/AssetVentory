import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../models/local_asset.dart';
import '../models/local_asset_document.dart';
import 'edit_asset_screen.dart';

class AssetDetailScreen extends StatefulWidget {
  final LocalAsset asset;

  const AssetDetailScreen({super.key, required this.asset});

  static Future<void> navigateTo(BuildContext context, LocalAsset asset) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AssetDetailScreen(asset: asset)),
    );
  }

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  late LocalAsset _asset;
  List<LocalAssetDocument> _documents = [];
  bool _loadingDocuments = true;

  @override
  void initState() {
    super.initState();
    _asset = widget.asset;
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    try {
      final documents = await serviceLocator.assetDocumentRepository.getDocuments(_asset.id);
      if (!mounted) return;
      setState(() {
        _documents = documents;
        _loadingDocuments = false;
      });
    } catch (e) {
      debugPrint('Failed to load documents: $e');
      if (!mounted) return;
      setState(() => _loadingDocuments = false);
    }
  }

  Future<void> _edit() async {
    await EditAssetScreen.navigateTo(context, _asset);
    if (!mounted) return;

    final updated = await serviceLocator.assetRepository.getAsset(_asset.id);
    if (updated != null) {
      setState(() => _asset = updated);
    }
    await _loadDocuments();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${_asset.name}?'),
        content: const Text('This will permanently remove the asset and its attached files from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await serviceLocator.assetDocumentRepository.deleteDocumentsForAsset(_asset.id);
    await serviceLocator.assetRepository.deleteAsset(_asset.id);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = _asset.imagePath;
    final hasImage = imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Asset Details', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
          IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline, color: AppColors.error)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 520;
              final photo = _photo(hasImage, imagePath);
              final details = _details();

              if (horizontal) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: photo),
                    const SizedBox(width: 18),
                    Expanded(flex: 5, child: details),
                  ],
                );
              }

              return Column(children: [photo, const SizedBox(height: 18), details]);
            },
          ),
          const SizedBox(height: 24),
          _documentsSection(),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _edit,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit Asset'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primaryPurple),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photo(bool hasImage, String? imagePath) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: hasImage
            ? Image.file(File(imagePath!), fit: BoxFit.cover)
            : Container(
                color: AppColors.primaryPurple.withAlpha(18),
                alignment: Alignment.center,
                child: Text(_asset.emoji ?? '📦', style: const TextStyle(fontSize: 64)),
              ),
      ),
    );
  }

  Widget _details() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEFEBF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_asset.name, style: GoogleFonts.outfit(fontSize: 25, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _info('Category', _asset.categoryId == null ? 'Uncategorized' : 'Assigned category'),
          if (_asset.location?.isNotEmpty == true) _info('Location', _asset.location!),
          if (_asset.description?.isNotEmpty == true) _info('Description', _asset.description!),
          if (_asset.customFields.isNotEmpty)
            ..._asset.customFields.entries.map((entry) => _info(entry.key, entry.value)),
          if (_asset.qrEnabled) _info('QR Code', 'Enabled'),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _documentsSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEFEBF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Attached Documents', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
              Text('${_documents.length}', style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingDocuments)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_documents.isEmpty)
            Text('No documents attached.', style: GoogleFonts.outfit(color: AppColors.textSecondary))
          else
            ..._documents.map(_documentTile),
        ],
      ),
    );
  }

  Widget _documentTile(LocalAssetDocument document) {
    final file = File(document.filePath);
    final exists = file.existsSync();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: AppColors.primaryPurple.withAlpha(18), borderRadius: BorderRadius.circular(12)),
        child: Icon(document.fileType == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded, color: AppColors.primaryPurple),
      ),
      title: Text(document.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(exists ? _size(document.fileSize) : 'File unavailable'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          await serviceLocator.assetDocumentRepository.deleteDocument(document);
          if (!mounted) return;
          await _loadDocuments();
        },
      ),
    );
  }

  String _size(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
