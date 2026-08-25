import 'dart:io';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../models/local_category.dart';
import 'asset_detail_screen.dart';

class AddAssetScreen extends StatefulWidget {
  final String? initialCategoryId;
  const AddAssetScreen({super.key, this.initialCategoryId});
  static Future<void> navigateTo(BuildContext context, {String? categoryId}) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddAssetScreen(initialCategoryId: categoryId)));
  @override State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  static const _ownerId = 'local_user';
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  List<LocalCategory> _categories = [];
  File? _image;
  final List<File> _documents = [];
  String _emoji = '📦';
  String? _categoryId;
  bool _qrEnabled = false;
  bool _saving = false;

  @override void initState() { super.initState(); _categoryId = widget.initialCategoryId; _loadCategories(); }
  Future<void> _loadCategories() async { final categories = await serviceLocator.categoryRepository.getCategories(_ownerId); if (!mounted) return; setState(() => _categories = categories); }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(context: context, builder: (sheetContext) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.camera_alt_rounded), title: const Text('Take Photo'), onTap: () => Navigator.pop(sheetContext, ImageSource.camera)),
      ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('Choose from Gallery'), onTap: () => Navigator.pop(sheetContext, ImageSource.gallery)),
    ])));
    if (source == null) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null || !mounted) return;
    setState(() => _image = File(picked.path));
  }

  Future<void> _pickDocuments() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || !mounted) return;
    setState(() => _documents.addAll(result.paths.whereType<String>().map(File)));
  }

  Future<void> _createCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Create Category'),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Category name')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () { final value = controller.text.trim(); if (value.isNotEmpty) Navigator.pop(dialogContext, value); }, child: const Text('Create'))],
    ));
    controller.dispose();
    if (name == null) return;
    final id = await serviceLocator.categoryRepository.createCategoryIfNotExists(ownerId: _ownerId, name: name, emoji: '📂');
    if (!mounted) return;
    await _loadCategories();
    setState(() => _categoryId = id);
  }

  Future<void> _chooseEmoji() async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (sheetContext) => SizedBox(height: 360, child: EmojiPicker(onEmojiSelected: (_, emoji) { setState(() => _emoji = emoji.emoji); Navigator.pop(sheetContext); })));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final asset = await serviceLocator.assetRepository.createAssetWithImage(ownerId: _ownerId, name: _name.text.trim(), categoryId: _categoryId, emoji: _emoji, imageFile: _image, location: _location.text.trim().isEmpty ? null : _location.text.trim(), description: _description.text.trim().isEmpty ? null : _description.text.trim(), qrEnabled: _qrEnabled);
      for (final file in _documents) { await serviceLocator.assetDocumentRepository.addDocument(assetId: asset.id, sourceFile: file); }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AssetDetailScreen(asset: asset)));
    } catch (e, stackTrace) {
      debugPrint('Failed to save asset: $e'); debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save asset. Please try again.')));
    }
  }

  @override void dispose() { _name.dispose(); _location.dispose(); _description.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffoldBg,
    appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: Text('Add Asset', style: GoogleFonts.outfit(fontWeight: FontWeight.w700))),
    body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(20), children: [
      GestureDetector(onTap: _pickPhoto, child: ClipRRect(borderRadius: BorderRadius.circular(22), child: AspectRatio(aspectRatio: 16 / 9, child: _image == null ? Container(color: AppColors.primaryPurple.withAlpha(18), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_a_photo_rounded, size: 40, color: AppColors.primaryPurple), const SizedBox(height: 8), Text('Add asset photo', style: GoogleFonts.outfit(fontWeight: FontWeight.w600))])) : Image.file(_image!, fit: BoxFit.cover)))),
      const SizedBox(height: 18),
      Row(children: [Expanded(child: Text('Asset emoji', style: GoogleFonts.outfit(fontWeight: FontWeight.w600))), InkWell(onTap: _chooseEmoji, child: Text(_emoji, style: const TextStyle(fontSize: 34)))]),
      const SizedBox(height: 16),
      TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Asset Name *', border: OutlineInputBorder()), validator: (value) => value == null || value.trim().isEmpty ? 'Asset name is required' : null),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(value: _categoryId, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()), items: [const DropdownMenuItem<String>(value: null, child: Text('Uncategorized')), ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.emoji ?? '📂'} ${c.name}')))], onChanged: (value) => setState(() => _categoryId = value)),
      Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _createCategory, icon: const Icon(Icons.add), label: const Text('Create category'))),
      TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder())),
      const SizedBox(height: 14),
      TextFormField(controller: _description, maxLines: 4, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
      const SizedBox(height: 16),
      SwitchListTile(value: _qrEnabled, onChanged: (value) => setState(() => _qrEnabled = value), title: const Text('Enable QR code'), contentPadding: EdgeInsets.zero),
      OutlinedButton.icon(onPressed: _pickDocuments, icon: const Icon(Icons.attach_file_rounded), label: Text(_documents.isEmpty ? 'Attach Documents' : 'Attach More Documents (${_documents.length})')),
      if (_documents.isNotEmpty) ..._documents.asMap().entries.map((entry) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.insert_drive_file_outlined), title: Text(entry.value.path.split(Platform.pathSeparator).last, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _documents.removeAt(entry.key)))),
      const SizedBox(height: 20),
      SizedBox(height: 52, child: FilledButton(onPressed: _saving ? null : _save, style: FilledButton.styleFrom(backgroundColor: AppColors.primaryPurple), child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Asset'))),
    ])),
  );
}
