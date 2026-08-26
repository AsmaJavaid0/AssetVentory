import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_palette.dart';
import '../../../core/di/service_locator.dart';
import '../../assets/models/local_asset.dart';
import '../../assets/models/local_asset_document.dart';
import '../../assets/screens/edit_asset_screen.dart';

class AssetDetailModal extends StatefulWidget {
  final LocalAsset asset;
  final String? categoryName;

  const AssetDetailModal({
    super.key,
    required this.asset,
    this.categoryName,
  });

  static Future<void> show(
    BuildContext context,
    LocalAsset asset, {
    String? categoryName,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.heroCardBg : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => AssetDetailModal(
        asset: asset,
        categoryName: categoryName,
      ),
    );
  }

  @override
  State<AssetDetailModal> createState() => _AssetDetailModalState();
}

class _AssetDetailModalState extends State<AssetDetailModal> {
  final _assetRepository = serviceLocator.assetRepository;
  final _documentRepository = serviceLocator.assetDocumentRepository;

  bool _showQr = false;
  late Future<List<LocalAssetDocument>> _documentsFuture;

  @override
  void initState() {
    super.initState();
    _documentsFuture = _documentRepository.getDocuments(widget.asset.id);
  }

  void _reloadDocuments() {
    setState(() {
      _documentsFuture = _documentRepository.getDocuments(widget.asset.id);
    });
  }

  Future<void> _deleteAsset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Delete Asset?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.asset.name}"? This cannot be undone.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await serviceLocator.assetDocumentRepository
        .deleteDocumentsForAsset(widget.asset.id);
    await _assetRepository.deleteAsset(widget.asset.id);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final asset = widget.asset;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.handle,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: asset.imagePath != null &&
                              File(asset.imagePath!).existsSync()
                          ? Image.file(
                              File(asset.imagePath!),
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: palette.surfaceContainer,
                              alignment: Alignment.center,
                              child: Text(
                                asset.emoji ?? '📦',
                                style: const TextStyle(fontSize: 48),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.name,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: palette.onSurface,
                        ),
                      ),
                      if (widget.categoryName?.isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${asset.emoji ?? '📦'} ${widget.categoryName}',
                          style: GoogleFonts.outfit(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (asset.location?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: palette.onSurfaceMuted,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                asset.location!,
                                style: GoogleFonts.outfit(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (asset.description?.isNotEmpty == true) ...[
              _sectionTitle('Description'),
              const SizedBox(height: 6),
              Text(
                asset.description!,
                style: GoogleFonts.outfit(
                  color: palette.onSurfaceMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (asset.customFields.isNotEmpty) ...[
              _sectionTitle('Custom Fields'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: asset.customFields.entries.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${entry.key}: ${entry.value}',
                      style: GoogleFonts.outfit(fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
            ],
            _sectionTitle('Attached Documents'),
            const SizedBox(height: 8),
            FutureBuilder<List<LocalAssetDocument>>(
              future: _documentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final documents = snapshot.data ?? const [];
                if (documents.isEmpty) {
                  return Text(
                    'No attached documents.',
                    style: GoogleFonts.outfit(
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                }

                return Column(
                  children: documents.map((document) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: palette.inputBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.insert_drive_file_outlined,
                            color: AppColors.primaryPurple,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              document.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete document',
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: AppColors.error,
                            onPressed: () async {
                              await _documentRepository.deleteDocument(document);
                              if (mounted) _reloadDocuments();
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 18),
            if (asset.qrEnabled) ...[
              InkWell(
                onTap: () => setState(() => _showQr = !_showQr),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded),
                    const SizedBox(width: 8),
                    Text(
                      'QR Code',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Icon(
                      _showQr
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                    ),
                  ],
                ),
              ),
              if (_showQr)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      data: asset.id,
                      size: 170,
                      version: QrVersions.auto,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await EditAssetScreen.navigateTo(context, asset);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Asset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deleteAsset,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: palette.onSurface,
      ),
    );
  }
}
