import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../assets/widgets/full_screen_image_viewer.dart';
import '../models/shared_asset_model.dart';
import '../models/shared_document_model.dart';
import '../services/family_file_service.dart';

/// Read-only view for family-shared data. It deliberately only renders fields
/// that the owner included through the sharing permissions.
class SharedAssetDetailsScreen extends StatefulWidget {
  final SharedAssetModel asset;

  const SharedAssetDetailsScreen({super.key, required this.asset});

  static Future<void> navigateTo(BuildContext context, SharedAssetModel asset) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SharedAssetDetailsScreen(asset: asset),
      ),
    );
  }

  @override
  State<SharedAssetDetailsScreen> createState() =>
      _SharedAssetDetailsScreenState();
}

class _SharedAssetDetailsScreenState extends State<SharedAssetDetailsScreen> {
  String? _resolvedPathOrUrl;
  bool _isNetwork = false;
  bool _isLoadingImage = true;

  // Document open state: doc id → loading
  final Map<String, bool> _docLoading = {};

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  Future<void> _resolveImage() async {
    final asset = widget.asset;

    // If details permission is not enabled, do not display the photo
    if (!asset.permissions.viewDetails) {
      if (mounted) setState(() => _isLoadingImage = false);
      return;
    }

    // 1. Check for instant local file on the owner's device (0ms)
    if (asset.imagePath != null && asset.imagePath!.isNotEmpty) {
      final file = File(asset.imagePath!);
      if (await file.exists()) {
        if (!mounted) return;
        setState(() {
          _resolvedPathOrUrl = asset.imagePath;
          _isNetwork = false;
          _isLoadingImage = false;
        });
        return;
      }
    }

    // 2. Check for direct HTTP URL (0ms)
    final directUrl = asset.imageUrl ??
        (asset.imageStoragePath?.startsWith('http') == true
            ? asset.imageStoragePath
            : null) ??
        (asset.imagePath?.startsWith('http') == true ? asset.imagePath : null);

    if (directUrl != null && directUrl.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _resolvedPathOrUrl = directUrl;
        _isNetwork = true;
        _isLoadingImage = false;
      });
      return;
    }

    // 3. Resolve from Supabase Storage via signed download URL (cached)
    final storagePath = asset.imageStoragePath;
    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        final url = await FamilyFileService().getDownloadUrl(
          familyId: asset.familyId,
          path: storagePath,
        );
        if (!mounted) return;
        setState(() {
          _resolvedPathOrUrl = url;
          _isNetwork = true;
          _isLoadingImage = false;
        });
        return;
      } catch (e) {
        debugPrint('Failed to load shared asset image: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoadingImage = false;
    });
  }

  void _openFullScreen() {
    if (_resolvedPathOrUrl == null) return;
    FullScreenImageViewer.show(
      context,
      imagePath: _resolvedPathOrUrl!,
      title: widget.asset.name,
    );
  }

  Future<void> _openDocument(SharedDocumentModel doc) async {
    if (_docLoading[doc.id] == true) return;
    setState(() => _docLoading[doc.id] = true);

    try {
      // 1. Local file on device
      if (doc.filePath != null && doc.filePath!.isNotEmpty) {
        final file = File(doc.filePath!);
        if (await file.exists()) {
          await OpenFilex.open(file.path);
          return;
        }
      }

      // 2. Direct HTTP URL
      final directUrl = doc.downloadUrl ??
          (doc.storagePath?.startsWith('http') == true
              ? doc.storagePath
              : null);

      if (directUrl != null && directUrl.isNotEmpty) {
        await _openUrl(directUrl, doc);
        return;
      }

      // 3. Resolve from Supabase Storage
      if (doc.storagePath != null && doc.storagePath!.isNotEmpty) {
        final url = await FamilyFileService().getDownloadUrl(
          familyId: widget.asset.familyId,
          path: doc.storagePath!,
        );
        await _openUrl(url, doc);
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not locate this document.')),
        );
      }
    } catch (e) {
      debugPrint('Error opening document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open document: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _docLoading[doc.id] = false);
    }
  }

  /// Opens a network URL in an external application or browser.
  Future<void> _openUrl(String url, SharedDocumentModel doc) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open this document.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final permissions = asset.permissions;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.heroDarkBg,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Shared Asset',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          _buildImageSection(),
          const SizedBox(height: 18),
          Text(
            asset.name,
            style: GoogleFonts.outfit(
              fontSize: 26,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Shared by ${asset.ownerName}',
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          _infoCard([
            if (asset.categoryName?.isNotEmpty == true)
              _InfoRow(
                'Category',
                asset.categoryName!,
                Icons.category_outlined,
              ),
            if (permissions.viewLocation && asset.location?.isNotEmpty == true)
              _InfoRow('Location', asset.location!, Icons.location_on_outlined),
            if (permissions.viewDetails &&
                asset.description?.isNotEmpty == true)
              _InfoRow('Description', asset.description!, Icons.notes_rounded),
          ]),
          if (permissions.viewDocuments) ...[
            const SizedBox(height: 18),
            _buildDocumentsSection(),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Documents section
  // ---------------------------------------------------------------------------

  Widget _buildDocumentsSection() {
    final docs = widget.asset.documents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 18,
                color: AppColors.primaryPurple,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Documents',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${docs.length}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryPurple,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (docs.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  'No documents shared with this asset.',
                  style: GoogleFonts.outfit(color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: _cardDecoration(),
            child: Column(
              children: [
                for (var i = 0; i < docs.length; i++) ...[
                  _DocumentTile(
                    doc: docs[i],
                    isLoading: _docLoading[docs[i].id] == true,
                    onTap: () => _openDocument(docs[i]),
                  ),
                  if (i < docs.length - 1)
                    const Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.lightLavenderBorder,
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Image section
  // ---------------------------------------------------------------------------

  Widget _buildImageSection() {
    if (_isLoadingImage) {
      return _frame(
        const Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    if (_resolvedPathOrUrl != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _openFullScreen,
          child: _frame(
            Stack(
              fit: StackFit.expand,
              children: [
                _isNetwork
                    ? Image.network(
                        _resolvedPathOrUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _emojiFallback(),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryPurple,
                            ),
                          );
                        },
                      )
                    : Image.file(
                        File(_resolvedPathOrUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _emojiFallback(),
                      ),
                // Tap to expand indicator overlay
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(160),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tap for full screen',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _frame(_emojiFallback());
  }

  Widget _frame(Widget child) => Container(
    height: 240,
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.lightLavender,
      borderRadius: BorderRadius.circular(22),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Widget _emojiFallback() => Center(
    child: Text(
      widget.asset.emoji ?? '📦',
      style: const TextStyle(fontSize: 72),
    ),
  );

  Widget _infoCard(List<_InfoRow> rows) {
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Text(
          'The owner has not shared additional details for this asset.',
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
      );
    }
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index < rows.length - 1)
              const Divider(height: 1, color: AppColors.lightLavenderBorder),
          ],
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.lightLavenderBorder),
  );
}

// ---------------------------------------------------------------------------
// Document tile widget
// ---------------------------------------------------------------------------

class _DocumentTile extends StatelessWidget {
  final SharedDocumentModel doc;
  final bool isLoading;
  final VoidCallback onTap;

  const _DocumentTile({
    required this.doc,
    required this.isLoading,
    required this.onTap,
  });

  IconData _iconForType(String? type) {
    if (type == null) return Icons.insert_drive_file_outlined;
    final t = type.toLowerCase();
    if (t.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (t.contains('image') || t.contains('jpg') || t.contains('png')) {
      return Icons.image_outlined;
    }
    if (t.contains('word') || t.contains('doc')) return Icons.description_outlined;
    if (t.contains('sheet') || t.contains('xls') || t.contains('csv')) {
      return Icons.table_chart_outlined;
    }
    if (t.contains('video')) return Icons.video_file_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Color _colorForType(String? type) {
    if (type == null) return Colors.blueGrey;
    final t = type.toLowerCase();
    if (t.contains('pdf')) return Colors.red.shade600;
    if (t.contains('image') || t.contains('jpg') || t.contains('png')) {
      return Colors.green.shade600;
    }
    if (t.contains('word') || t.contains('doc')) return Colors.blue.shade600;
    if (t.contains('sheet') || t.contains('xls') || t.contains('csv')) {
      return Colors.teal.shade600;
    }
    if (t.contains('video')) return Colors.orange.shade600;
    return Colors.blueGrey;
  }

  String _sizeLabel(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(doc.fileType);
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_iconForType(doc.fileType), color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.name,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (doc.fileSize != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _sizeLabel(doc.fileSize),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryPurple,
                ),
              )
            else
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primaryPurple),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
