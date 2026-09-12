import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../models/local_asset.dart';
import '../models/local_asset_document.dart';
import '../models/local_category.dart';
import '../widgets/full_screen_image_viewer.dart';

class EditAssetScreen extends StatefulWidget {
  final LocalAsset asset;

  const EditAssetScreen({super.key, required this.asset});

  static Future<void> navigateTo(BuildContext context, LocalAsset asset) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => EditAssetScreen(asset: asset)),
      );

  @override
  State<EditAssetScreen> createState() => _EditAssetScreenState();
}

class _EditAssetScreenState extends State<EditAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assetRepository = serviceLocator.assetRepository;
  final _categoryRepository = serviceLocator.categoryRepository;
  final _documentRepository = serviceLocator.assetDocumentRepository;
  final _imagePicker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  late String _emoji;
  String? _categoryId;
  late bool _qrEnabled;
  late Map<String, String> _customFields;
  List<LocalCategory> _categories = [];
  late Future<List<LocalAssetDocument>> _documentsFuture;

  File? _newImage;
  final List<File> _newDocuments = [];
  final Set<String> _deletedDocumentIds = {};
  final Map<String, File> _replacements = {};

  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;

  static const _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
  };

  static const _allowedFileExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'csv',
    'rtf',
    'zip',
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
  ];

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    _nameController = TextEditingController(text: asset.name);
    _locationController = TextEditingController(text: asset.location ?? '');
    _descriptionController =
        TextEditingController(text: asset.description ?? '');
    _emoji = asset.emoji ?? '📦';
    _categoryId = asset.categoryId;
    _qrEnabled = asset.qrEnabled;
    _customFields = Map<String, String>.from(asset.customFields);
    _documentsFuture = _loadDocuments();
    _loadCategories();
  }

  Future<List<LocalAssetDocument>> _loadDocuments() async {
    try {
      return await _documentRepository.getDocuments(widget.asset.id);
    } catch (e) {
      debugPrint('Document load error: $e');
      return const <LocalAssetDocument>[];
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryRepository.getCategories('local_user');
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Category load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked != null && mounted) {
      setState(() => _newImage = File(picked.path));
    }
  }

  Future<void> _showMediaPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              'Add Media',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Photos from Gallery'),
              subtitle: const Text('Pick one or more images'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickGalleryMedia();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Documents & Files'),
              subtitle: const Text('PDFs, documents, spreadsheets, and more'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFileMedia();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickGalleryMedia() async {
    try {
      final picked = await _imagePicker.pickMultiImage(
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (!mounted || picked.isEmpty) return;

      setState(() {
        for (final xFile in picked) {
          final file = File(xFile.path);
          if (!_newDocuments.any((item) => item.path == file.path)) {
            _newDocuments.add(file);
          }
        }
      });
    } catch (e) {
      debugPrint('Pick images error: $e');
    }
  }

  Future<void> _pickFileMedia() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedFileExtensions,
      );
      if (picked.isEmpty) return;

      final path = picked.first.path;
      if (path == null) return;
      final file = File(path);

      setState(() {
        if (!_newDocuments.any((item) => item.path == file.path)) {
          _newDocuments.add(file);
        }
      });
    } catch (e) {
      debugPrint('Pick file error: $e');
    }
  }

  Future<void> _replaceDocument(LocalAssetDocument document) async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedFileExtensions,
      );
      if (picked.isEmpty) return;

      final path = picked.first.path;
      if (path == null) return;

      setState(() => _replacements[document.id] = File(path));
    } catch (e) {
      debugPrint('Replace document error: $e');
    }
  }

  Future<void> _removeDocument(LocalAssetDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Remove File?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Remove "${document.name}" from this asset?',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _deletedDocumentIds.add(document.id);
      _replacements.remove(document.id);
    });
  }

  Future<void> _openDocument(LocalAssetDocument document) async {
    final path = _replacements[document.id]?.path ?? document.filePath;
    final file = File(path);

    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This file is no longer available.')),
      );
      return;
    }

    if (_isImagePath(path)) {
      if (!mounted) return;
      FullScreenImageViewer.show(
        context,
        imagePath: path,
        title: document.name,
      );
      return;
    }

    final result = await OpenFilex.open(path);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${document.name}.')),
      );
    }
  }

  bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return _imageExtensions.any((extension) => lower.endsWith('.$extension'));
  }

  bool _isImage(LocalAssetDocument document) {
    final replacement = _replacements[document.id];
    if (replacement != null) return _isImagePath(replacement.path);
    if (document.fileType != null) {
      return _imageExtensions.contains(document.fileType!.toLowerCase());
    }
    return _isImagePath(document.name);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final updated = widget.asset.copyWith(
        name: _nameController.text.trim(),
        emoji: _emoji,
        categoryId: _categoryId,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        imagePath: _newImage?.path ?? widget.asset.imagePath,
        qrEnabled: _qrEnabled,
        customFields: _customFields,
        updatedAt: DateTime.now(),
      );

      await _assetRepository.updateAsset(updated);

      final existingDocuments = await _documentsFuture;

      for (final entry in _replacements.entries) {
        if (_deletedDocumentIds.contains(entry.key)) continue;
        final document = existingDocuments.firstWhere(
          (item) => item.id == entry.key,
        );
        await _documentRepository.replaceDocument(document, entry.value);
      }

      for (final document in existingDocuments) {
        if (_deletedDocumentIds.contains(document.id)) {
          await _documentRepository.deleteDocument(document);
        }
      }

      for (final file in _newDocuments) {
        await _documentRepository.addDocument(
          assetId: widget.asset.id,
          sourceFile: file,
          displayName: file.path.split(Platform.pathSeparator).last,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Asset updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Update asset error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update asset. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Delete Asset',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.asset.name}"? This action cannot be undone.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _deleting = true);
    try {
      await _assetRepository.deleteAsset(widget.asset.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Asset deleted.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Delete asset error: $e');
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete asset.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showEmojiPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (pickerContext) => SizedBox(
        height: 340,
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) {
            setState(() => _emoji = emoji.emoji);
            Navigator.pop(pickerContext);
          },
        ),
      ),
    );
  }

  Future<void> _editCustomField(String oldKey, String oldValue) async {
    final keyController = TextEditingController(text: oldKey);
    final valueController = TextEditingController(text: oldValue);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Edit Custom Field',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: keyController,
              hintText: 'Field name',
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: valueController,
              hintText: 'Value',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final key = keyController.text.trim();
              final value = valueController.text.trim();
              if (key.isEmpty || value.isEmpty) return;
              setState(() {
                _customFields.remove(oldKey);
                _customFields[key] = value;
              });
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    keyController.dispose();
    valueController.dispose();
  }

  Future<void> _showAddCustomFieldDialog() async {
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Add Custom Field',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(controller: keyController, hintText: 'Field name'),
            const SizedBox(height: 12),
            CustomTextField(controller: valueController, hintText: 'Value'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final key = keyController.text.trim();
              final value = valueController.text.trim();
              if (key.isEmpty || value.isEmpty) return;
              setState(() => _customFields[key] = value);
              Navigator.pop(dialogContext);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    keyController.dispose();
    valueController.dispose();
  }

  Widget _buildImagePicker() {
    final imagePath = _newImage?.path ?? widget.asset.imagePath;
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.lightLavender,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryPurple,
                  width: 2,
                ),
              ),
              child: _newImage != null
                  ? ClipOval(
                      child: Image.file(
                        _newImage!,
                        fit: BoxFit.cover,
                        width: 110,
                        height: 110,
                      ),
                    )
                  : imagePath != null && imagePath.isNotEmpty
                      ? ClipOval(
                          child: Image.file(
                            File(imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _emojiFallback(),
                          ),
                        )
                      : _emojiFallback(),
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconActionButton(
                    icon: Icons.emoji_emotions_outlined,
                    onTap: _showEmojiPicker,
                    tooltip: 'Change emoji',
                  ),
                  const SizedBox(height: 8),
                  _IconActionButton(
                    icon: Icons.camera_alt_rounded,
                    onTap: _pickImage,
                    isPrimary: true,
                    tooltip: 'Change photo',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emojiFallback() => Center(
        child: Text(_emoji, style: const TextStyle(fontSize: 48)),
      );

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Category',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.inputBorder, width: 1.2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _categoryId,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              dropdownColor: AppColors.surfaceWhite,
              hint: Text(
                'Select category',
                style: GoogleFonts.outfit(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Uncategorized'),
                ),
                ..._categories.map(
                  (category) => DropdownMenuItem<String?>(
                    value: category.id,
                    child: Text(category.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
              borderRadius: BorderRadius.circular(16),
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Custom Fields',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _showAddCustomFieldDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Field'),
            ),
          ],
        ),
        if (_customFields.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.lightLavender.withAlpha(100),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.lightLavenderBorder),
            ),
            child: const Text(
              'Add custom fields to store extra details such as serial numbers, purchase dates, or warranty information.',
            ),
          )
        else
          ..._customFields.entries.map(
            (entry) => Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.lightLavenderBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _editCustomField(entry.key, entry.value),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              entry.value,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit field',
                    onPressed: () => _editCustomField(entry.key, entry.value),
                    icon: const Icon(Icons.edit_outlined, size: 19),
                  ),
                  IconButton(
                    tooltip: 'Delete field',
                    onPressed: () => setState(
                      () => _customFields.remove(entry.key),
                    ),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDocuments() {
    return FutureBuilder<List<LocalAssetDocument>>(
      future: _documentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(22),
            decoration: _cardDecoration(),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }

        final documents = snapshot.data ?? const <LocalAssetDocument>[];
        final visibleDocuments = documents
            .where((document) => !_deletedDocumentIds.contains(document.id))
            .toList();
        final total = visibleDocuments.length + _newDocuments.length;

        return Container(
          decoration: _cardDecoration(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$total file${total == 1 ? '' : 's'}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showMediaPicker,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Media'),
                    ),
                  ],
                ),
              ),
              if (total == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
                  child: Text(
                    'No files attached yet. Tap Add Media to add photos or documents.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              for (var index = 0; index < visibleDocuments.length; index++) ...[
                _buildDocumentTile(visibleDocuments[index]),
                if (index != visibleDocuments.length - 1 ||
                    _newDocuments.isNotEmpty)
                  const Divider(height: 1, indent: 72, endIndent: 16),
              ],
              for (var index = 0; index < _newDocuments.length; index++) ...[
                _buildNewDocumentTile(_newDocuments[index]),
                if (index != _newDocuments.length - 1)
                  const Divider(height: 1, indent: 72, endIndent: 16),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentTile(LocalAssetDocument document) {
    final replacement = _replacements[document.id];
    final displayPath = replacement?.path ?? document.filePath;
    final image = _isImage(document);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _documentPreview(document, replacement),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _openDocument(document),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      replacement == null
                          ? document.name
                          : '${_fileName(displayPath)} • replacement',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      image ? 'Image • Tap to view' : 'Document • Tap to open',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Edit file',
            onSelected: (value) {
              if (value == 'replace') _replaceDocument(document);
              if (value == 'remove') _removeDocument(document);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'replace',
                child: Text('Replace'),
              ),
              PopupMenuItem(
                value: 'remove',
                child: Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewDocumentTile(File file) {
    final image = _isImagePath(file.path);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          if (image && file.existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                file,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            )
          else
            _fileIcon(_extension(file.path)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fileName(file.path),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  image ? 'New image' : 'New document',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.primaryPurple,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.error,
              size: 20,
            ),
            onPressed: () => setState(() => _newDocuments.remove(file)),
          ),
        ],
      ),
    );
  }

  Widget _documentPreview(LocalAssetDocument document, [File? replacement]) {
    final path = replacement?.path ?? document.filePath;
    if (_isImagePath(path) && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(path),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fileIcon(document.fileType),
        ),
      );
    }
    return _fileIcon(document.fileType);
  }

  Widget _fileIcon(String? type) {
    final extension = type?.toLowerCase() ?? '';
    final icon = extension == 'pdf'
        ? Icons.picture_as_pdf_outlined
        : extension == 'doc' || extension == 'docx'
            ? Icons.description_outlined
            : extension == 'xls' || extension == 'xlsx'
                ? Icons.table_chart_outlined
                : Icons.insert_drive_file_outlined;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.lightLavender,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: AppColors.primaryPurple,
        size: 25,
      ),
    );
  }

  String _fileName(String path) => path.split(Platform.pathSeparator).last;

  String? _extension(String path) {
    final name = _fileName(path);
    final index = name.lastIndexOf('.');
    return index == -1 ? null : name.substring(index + 1).toLowerCase();
  }

  Widget _buildQrToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightLavenderBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              color: AppColors.primaryPurple,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable QR Code',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Generate a QR tag for quick scanning.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _qrEnabled,
            activeThumbColor: AppColors.primaryPurple,
            activeTrackColor: AppColors.primaryPurple.withAlpha(80),
            onChanged: (value) => setState(() => _qrEnabled = value),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightLavenderBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  Widget _buildSaveBar() => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            border: const Border(
              top: BorderSide(
                color: AppColors.lightLavenderBorder,
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 22),
              label: Text(
                _saving ? 'Saving…' : 'Save Changes',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Edit Asset',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          IconButton(
            tooltip: 'Delete asset',
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: _deleting ? null : _delete,
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryPurple,
                strokeWidth: 3,
              ),
            )
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  _saving ? 32 : 120,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImagePicker(),
                      const SizedBox(height: 28),
                      const _SectionHeader(title: 'Basic Info'),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _nameController,
                        hintText: 'Asset name',
                        labelText: 'Name',
                        prefixIcon: Icons.inventory_2_outlined,
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Please enter a name'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildCategoryDropdown(),
                      const SizedBox(height: 24),
                      const _SectionHeader(title: 'Details'),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _locationController,
                        hintText: 'e.g. Living Room, Garage, Office',
                        labelText: 'Location',
                        prefixIcon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _descriptionController,
                        hintText: 'Add a description…',
                        labelText: 'Description',
                        prefixIcon: Icons.notes_outlined,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      const _SectionHeader(title: 'Custom Fields'),
                      const SizedBox(height: 16),
                      _buildCustomFields(),
                      const SizedBox(height: 24),
                      const _SectionHeader(title: 'Documents & Media'),
                      const SizedBox(height: 8),
                      Text(
                        'Add, replace, remove, or open files attached to this asset.',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDocuments(),
                      const SizedBox(height: 24),
                      const _SectionHeader(title: 'Advanced'),
                      const SizedBox(height: 16),
                      _buildQrToggle(),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: _loading ? null : _buildSaveBar(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.primaryPurple,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final String? tooltip;

  const _IconActionButton({
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: isPrimary ? AppColors.primaryPurple : AppColors.surfaceWhite,
        shape: const CircleBorder(),
        elevation: isPrimary ? 4 : 2,
        shadowColor: isPrimary
            ? AppColors.primaryPurple.withAlpha(80)
            : Colors.black.withAlpha(30),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              color: isPrimary ? Colors.white : AppColors.textSecondary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
