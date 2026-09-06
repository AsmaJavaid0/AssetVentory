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

/// Read-only view for family-shared data.
/// Image documents are presented as a quick-access gallery instead of a
/// filename-only list. Non-image files remain available as normal documents.
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

  final Map<String, bool> _docLoading = {};
  final Map<String, String> _resolvedImageDocs = {};
  bool _isLoadingImageDocs = false;

  List<SharedDocumentModel> get _imageDocs => widget.asset.documents
      .where((doc) => _isImageType(doc.fileType, doc.name))
      .toList(growable: false);

  List<SharedDocumentModel> get _otherDocs => widget.asset.documents
      .where((doc) => !_isImageType(doc.fileType, doc.name))
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _resolveImage();
    _resolveImageDocuments();
  }

  bool _isImageType(String? type, String name) {
    final value = '${type ?? ''} $name'.toLowerCase();
    return value.contains('image') ||
        value.contains('jpg') ||
        value.contains('jpeg') ||
        value.contains('png') ||
        value.contains('webp') ||
        value.contains('gif') ||
        value.contains('heic');
  }

  Future<String?> _resolveDocumentPath(SharedDocumentModel doc) async {
    if (doc.filePath != null && doc.filePath!.isNotEmpty) {
      final file = File(doc.filePath!);
      if (await file.exists()) return doc.filePath;
    }

    final directUrl = doc.downloadUrl ??
        (doc.storagePath?.startsWith('http') == true
            ? doc.storagePath
            : null);
    if (directUrl != null && directUrl.isNotEmpty) return directUrl;

    if (doc.storagePath != null && doc.storagePath!.isNotEmpty) {
      try {
        return await FamilyFileService().getDownloadUrl(
          familyId: widget.asset.familyId,
          path: doc.storagePath!,
        );
      } catch (e) {
        debugPrint('Failed to resolve shared image ${doc.name}: $e');
      }
    }
    return null;
  }

  Future<void> _resolveImageDocuments() async {
    final docs = _imageDocs;
    if (docs.isEmpty) return;

    if (mounted) setState(() => _isLoadingImageDocs = true);

    // Resolve all image URLs concurrently so a gallery does not wait for
    // each image one-by-one.
    final resolved = await Future.wait(
      docs.map((doc) async => MapEntry(doc.id, await _resolveDocumentPath(doc))),
    );

    if (!mounted) return;
    setState(() {
      for (final entry in resolved) {
        final path = entry.value;
        if (path != null && path.isNotEmpty) {
          _resolvedImageDocs[entry.key] = path;
        }
      }
      _isLoadingImageDocs = false;
    });
  }

  Future<void> _resolveImage() async {
    final asset = widget.asset;
    if (!asset.permissions.viewDetails) {
      if (mounted) setState(() => _isLoadingImage = false);
      return;
    }

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

    if (mounted) setState(() => _isLoadingImage = false);
  }

  void _openFullScreen() {
    if (_resolvedPathOrUrl == null) return;
    FullScreenImageViewer.show(
      context,
      imagePath: _resolvedPathOrUrl!,
      title: widget.asset.name,
    );
  }

  void _openImageGallery(SharedDocumentModel selected) {
    final paths = _imageDocs
        .map((doc) => _resolvedImageDocs[doc.id])
        .whereType<String>()
        .toList(growable: false);
    if (paths.isEmpty) return;

    final selectedPath = _resolvedImageDocs[selected.id];
    final initialIndex = selectedPath == null ? 0 : paths.indexOf(selectedPath);
    FullScreenImageViewer.showGallery(
      context,
      imagePaths: paths,
      title: widget.asset.name,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
    );
  }

  Future<void> _openDocument(SharedDocumentModel doc) async {
    if (_docLoading[doc.id] == true) return;
    setState(() => _docLoading[doc.id] = true);

    try {
      if (doc.filePath != null && doc.filePath!.isNotEmpty) {
        final file = File(doc.filePath!);
        if (await file.exists()) {
          await OpenFilex.open(file.path);
          return;
        }
      }

      final directUrl = doc.downloadUrl ??
          (doc.storagePath?.startsWith('http') == true
              ? doc.storagePath
              : null);
      if (directUrl != null && directUrl.isNotEmpty) {
        await _openUrl(directUrl);
        return;
      }

      if (doc.storagePath != null && doc.storagePath!.isNotEmpty) {
        final url = await FamilyFileService().getDownloadUrl(
          familyId: widget.asset.familyId,
          path: doc.storagePath!,
        );
        await _openUrl(url);
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open this document.')),
      );
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
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
          Text('Shared by ${asset.ownerName}',
              style: GoogleFonts.outfit(color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          _infoCard([
            if (asset.categoryName?.isNotEmpty == true)
              _InfoRow('Category', asset.categoryName!, Icons.category_outlined),
            if (permissions.viewLocation && asset.location?.isNotEmpty == true)
              _InfoRow('Location', asset.location!, Icons.location_on_outlined),
            if (permissions.viewDetails && asset.description?.isNotEmpty == true)
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

  Widget _buildDocumentsSection() {
    final docs = widget.asset.documents;
    final images = _imageDocs;
    final otherDocs = _otherDocs;

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
              child: const Icon(Icons.folder_open_rounded,
                  size: 18, color: AppColors.primaryPurple),
            ),
            const SizedBox(width: 10),
            Text('Documents',
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            _countBadge(docs.length),
          ],
        ),
        const SizedBox(height: 12),
        if (docs.isEmpty)
          _emptyDocuments()
        else ...[
          if (images.isNotEmpty) _buildImageGallery(images),
          if (otherDocs.isNotEmpty) ...[
            if (images.isNotEmpty) const SizedBox(height: 16),
            _buildOtherDocuments(otherDocs),
          ],
        ],
      ],
    );
  }

  Widget _countBadge(int count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primaryPurple.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$count',
            style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryPurple)),
      );

  Widget _buildImageGallery(List<SharedDocumentModel> images) {
    final available = images
        .where((doc) => _resolvedImageDocs.containsKey(doc.id))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Photos',
                style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            Text('${images.length}',
                style: GoogleFonts.outfit(
                    fontSize: 13, color: AppColors.textSecondary)),
            const Spacer(),
            if (available.length > 1)
              Text('Tap any photo to swipe',
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 10),
        if (_isLoadingImageDocs && available.isEmpty)
          Container(
            height: 150,
            decoration: _cardDecoration(),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            ),
          )
        else if (available.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Text('Photos could not be loaded right now.',
                style: GoogleFonts.outfit(color: AppColors.textSecondary)),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: available.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.08,
            ),
            itemBuilder: (context, index) {
              final doc = available[index];
              return _ImageDocumentTile(
                doc: doc,
                path: _resolvedImageDocs[doc.id]!,
                onTap: () => _openImageGallery(doc),
              );
            },
          ),
      ],
    );
  }

  Widget _buildOtherDocuments(List<SharedDocumentModel> docs) => Container(
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
                    color: AppColors.lightLavenderBorder),
            ],
          ],
        ),
      );

  Widget _emptyDocuments() => Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text('No documents shared with this asset.',
                style: GoogleFonts.outfit(color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _buildImageSection() {
    if (_isLoadingImage) {
      return _frame(const Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple)));
    }

    if (_resolvedPathOrUrl != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _openFullScreen,
          child: _frame(Stack(
            fit: StackFit.expand,
            children: [
              _isNetwork
                  ? Image.network(_resolvedPathOrUrl!,
                      fit: BoxFit.cover,
                      cacheWidth: 900,
                      errorBuilder: (context, error, stackTrace) =>
                          _emojiFallback(),
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.primaryPurple)))
                  : Image.file(File(_resolvedPathOrUrl!),
                      fit: BoxFit.cover,
                      cacheWidth: 900,
                      errorBuilder: (context, error, stackTrace) =>
                          _emojiFallback()),
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.fullscreen_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text('Tap for full screen',
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ],
          )),
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
        child: Text(widget.asset.emoji ?? '📦',
            style: const TextStyle(fontSize: 72)),
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
      child: Column(children: [
        for (var index = 0; index < rows.length; index++) ...[
          rows[index],
          if (index < rows.length - 1)
            const Divider(height: 1, color: AppColors.lightLavenderBorder),
        ],
      ]),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightLavenderBorder),
      );
}

class _ImageDocumentTile extends StatelessWidget {
  final SharedDocumentModel doc;
  final String path;
  final VoidCallback onTap;

  const _ImageDocumentTile({
    required this.doc,
    required this.path,
    required this.onTap,
  });

  ImageProvider _provider() {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    return FileImage(File(path));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: _provider(),
              fit: BoxFit.cover,
              cacheWidth: 600,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.lightLavender,
                child: const Icon(Icons.broken_image_outlined,
                    color: AppColors.textSecondary, size: 32),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 18, 10, 9),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                child: Text(
                  doc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(130),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.collections_rounded,
                    color: Colors.white, size: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        child: Row(children: [
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
                Text(doc.name,
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (doc.fileSize != null) ...[
                  const SizedBox(height: 2),
                  Text(_sizeLabel(doc.fileSize),
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryPurple),
                )
              : const Icon(Icons.open_in_new_rounded,
                  size: 18, color: AppColors.textSecondary),
        ]),
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
                  Text(label,
                      style: GoogleFonts.outfit(
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 3),
                  Text(value,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );
}
