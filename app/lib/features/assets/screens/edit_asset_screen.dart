import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

  static Future<void> navigateTo(BuildContext context, LocalAsset asset) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EditAssetScreen(asset: asset)),
      );

  @override
  State<EditAssetScreen> createState() => _EditAssetScreenState();
}

class _EditAssetScreenState extends State<EditAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assets = serviceLocator.assetRepository;
  final _categoriesRepo = serviceLocator.categoryRepository;
  final _docs = serviceLocator.assetDocumentRepository;
  final _picker = ImagePicker();
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late String _emoji;
  String? _categoryId;
  late bool _qrEnabled;
  late Map<String, String> _customFields;
  List<LocalCategory> _categories = [];
  late Future<List<LocalAssetDocument>> _documents;
  File? _newImage;
  final _newFiles = <File>[];
  final _removedIds = <String>{};
  final _replacements = <String, File>{};
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;

  static const _extensions = [
    'pdf','doc','docx','xls','xlsx','ppt','pptx','txt','csv','rtf','zip',
    'png','jpg','jpeg','gif','webp','bmp','heic',
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.asset.name);
    _location = TextEditingController(text: widget.asset.location ?? '');
    _description = TextEditingController(text: widget.asset.description ?? '');
    _emoji = widget.asset.emoji ?? '📦';
    _categoryId = widget.asset.categoryId;
    _qrEnabled = widget.asset.qrEnabled;
    _customFields = Map<String, String>.from(widget.asset.customFields);
    _documents = _docs.getDocuments(widget.asset.id);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoriesRepo.getCategories('local_user');
      if (mounted) setState(() { _categories = categories; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null && mounted) setState(() => _newImage = File(picked.path));
    } catch (_) {}
  }

  Future<List<PlatformFile>> _files() => FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _extensions,
      );

  Future<void> _addFiles() async {
    try {
      final picked = await _files();
      if (!mounted || picked.isEmpty) return;
      setState(() {
        for (final item in picked) {
          final path = item.path;
          if (path != null && !_newFiles.any((file) => file.path == path)) {
            _newFiles.add(File(path));
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _addImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 90, maxWidth: 2048, maxHeight: 2048);
      if (!mounted) return;
      setState(() {
        for (final item in picked) {
          final file = File(item.path);
          if (!_newFiles.any((existing) => existing.path == file.path)) _newFiles.add(file);
        }
      });
    } catch (_) {}
  }

  Future<void> _replace(LocalAssetDocument document) async {
    try {
      final picked = await _files();
      if (!mounted || picked.isEmpty) return;
      final path = picked.first.path;
      if (path != null) setState(() => _replacements[document.id] = File(path));
    } catch (_) {}
  }

  Future<void> _mediaMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Add Media'), subtitle: Text('Choose photos or documents')),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Gallery'),
            onTap: () { Navigator.pop(sheet); _addImages(); },
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: const Text('Documents & Files'),
            onTap: () { Navigator.pop(sheet); _addFiles(); },
          ),
        ]),
      ),
    );
  }

  bool _isImage(String path) {
    final p = path.toLowerCase();
    return ['.jpg','.jpeg','.png','.gif','.webp','.bmp','.heic'].any(p.endsWith);
  }

  String _fileName(String path) => path.split(Platform.pathSeparator).last;

  Future<void> _open(LocalAssetDocument document) async {
    final path = _replacements[document.id]?.path ?? document.filePath;
    final file = File(path);
    if (!await file.exists()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This file is no longer available.')));
      return;
    }
    if (_isImage(path)) {
      if (mounted) FullScreenImageViewer.show(context, imagePath: path, title: document.name);
    } else {
      await OpenFilex.open(path);
    }
  }

  Future<void> _remove(LocalAssetDocument document) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove File?'),
        content: Text('Remove "${document.name}" from this asset?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Remove')),
        ],
      ),
    );
    if (yes == true && mounted) setState(() { _removedIds.add(document.id); _replacements.remove(document.id); });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _assets.updateAsset(widget.asset.copyWith(
        name: _name.text.trim(),
        emoji: _emoji,
        categoryId: _categoryId,
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        imagePath: _newImage?.path ?? widget.asset.imagePath,
        qrEnabled: _qrEnabled,
        customFields: _customFields,
        updatedAt: DateTime.now(),
      ));

      final existing = await _documents;
      for (final entry in _replacements.entries) {
        if (!_removedIds.contains(entry.key)) {
          final document = existing.firstWhere((item) => item.id == entry.key);
          await _docs.replaceDocument(document, entry.value);
        }
      }
      for (final document in existing) {
        if (_removedIds.contains(document.id)) await _docs.deleteDocument(document);
      }
      for (final file in _newFiles) {
        await _docs.addDocument(assetId: widget.asset.id, sourceFile: file, displayName: _fileName(file.path));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Update asset error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update asset.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete Asset'),
        content: Text('Delete "${widget.asset.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true) return;
    setState(() => _deleting = true);
    try {
      await _assets.deleteAsset(widget.asset.id);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _emojiPicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SizedBox(
        height: 340,
        child: EmojiPicker(onEmojiSelected: (_, emoji) { setState(() => _emoji = emoji.emoji); Navigator.pop(sheet); }),
      ),
    );
  }

  Future<void> _customField({String? oldKey, String? oldValue}) async {
    final key = TextEditingController(text: oldKey ?? '');
    final value = TextEditingController(text: oldValue ?? '');
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(oldKey == null ? 'Add Custom Field' : 'Edit Custom Field'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          CustomTextField(controller: key, hintText: 'Field name'),
          const SizedBox(height: 12),
          CustomTextField(controller: value, hintText: 'Value'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          TextButton(onPressed: () {
            if (key.text.trim().isEmpty || value.text.trim().isEmpty) return;
            setState(() {
              if (oldKey != null) _customFields.remove(oldKey);
              _customFields[key.text.trim()] = value.text.trim();
            });
            Navigator.pop(dialog);
          }, child: const Text('Save')),
        ],
      ),
    );
    key.dispose();
    value.dispose();
  }

  Widget _documentsSection() => FutureBuilder<List<LocalAssetDocument>>(
        future: _documents,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final documents = (snapshot.data ?? const <LocalAssetDocument>[]).where((d) => !_removedIds.contains(d.id)).toList();
          final total = documents.length + _newFiles.length;
          return Card(
            child: Column(children: [
              ListTile(title: Text('$total file${total == 1 ? '' : 's'}'), trailing: TextButton.icon(onPressed: _mediaMenu, icon: const Icon(Icons.add), label: const Text('Add Media'))),
              for (final document in documents) ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(_replacements[document.id] == null ? document.name : '${_fileName(_replacements[document.id]!.path)} • replacement', maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(_isImage(_replacements[document.id]?.path ?? document.filePath) ? 'Image • Tap to view' : 'Document • Tap to open'),
                onTap: () => _open(document),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) { if (value == 'replace') _replace(document); if (value == 'remove') _remove(document); },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'replace', child: Text('Replace')), PopupMenuItem(value: 'remove', child: Text('Remove'))],
                ),
              ),
              for (final file in _newFiles) ListTile(
                leading: const Icon(Icons.new_releases_outlined),
                title: Text(_fileName(file.path), maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: const Text('New file'),
                trailing: IconButton(icon: const Icon(Icons.close, color: AppColors.error), onPressed: () => setState(() => _newFiles.remove(file))),
              ),
              if (total == 0) const Padding(padding: EdgeInsets.all(20), child: Text('No files attached yet.')),
            ]),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Edit Asset'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false)),
        actions: [IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: _deleting ? null : _delete)],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 120), children: [
          Center(child: Stack(children: [
            CircleAvatar(
              radius: 56,
              backgroundColor: AppColors.lightLavender,
              backgroundImage: _newImage != null ? FileImage(_newImage!) : (widget.asset.imagePath != null ? FileImage(File(widget.asset.imagePath!)) : null),
              child: _newImage == null && widget.asset.imagePath == null ? Text(_emoji, style: const TextStyle(fontSize: 42)) : null,
            ),
            Positioned(bottom: 0, right: 0, child: FloatingActionButton.small(onPressed: _pickImage, child: const Icon(Icons.camera_alt))),
          ])),
          const SizedBox(height: 24),
          CustomTextField(controller: _name, labelText: 'Name', hintText: 'Asset name', validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a name' : null),
          const SizedBox(height: 14),
          ListTile(contentPadding: EdgeInsets.zero, title: Text('Emoji: $_emoji'), trailing: TextButton(onPressed: _emojiPicker, child: const Text('Change'))),
          DropdownButtonFormField<String?>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [const DropdownMenuItem<String?>(value: null, child: Text('Uncategorized')), ..._categories.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name)))],
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          const SizedBox(height: 14),
          CustomTextField(controller: _location, labelText: 'Location', hintText: 'Where is this asset?'),
          const SizedBox(height: 14),
          CustomTextField(controller: _description, labelText: 'Description', hintText: 'Add details...', maxLines: 3),
          const SizedBox(height: 20),
          Row(children: [Expanded(child: Text('Custom Fields', style: Theme.of(context).textTheme.titleMedium)), TextButton.icon(onPressed: () => _customField(), icon: const Icon(Icons.add), label: const Text('Add Field'))]),
          for (final entry in _customFields.entries) ListTile(contentPadding: EdgeInsets.zero, title: Text(entry.key), subtitle: Text(entry.value), onTap: () => _customField(oldKey: entry.key, oldValue: entry.value), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: () => setState(() => _customFields.remove(entry.key)))),
          const SizedBox(height: 20),
          Text('Documents & Media', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text('Add, replace, remove, or open files attached to this asset.'),
          const SizedBox(height: 12),
          _documentsSection(),
          const SizedBox(height: 20),
          SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Enable QR Code'), value: _qrEnabled, onChanged: (value) => setState(() => _qrEnabled = value)),
        ]),
      ),
      bottomNavigationBar: _loading ? null : SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: SizedBox(height: 54, child: ElevatedButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check), label: Text(_saving ? 'Saving…' : 'Save Changes'))))),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }
}
