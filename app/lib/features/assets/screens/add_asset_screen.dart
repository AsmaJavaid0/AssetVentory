import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/local_file_storage.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../models/local_category.dart';
import '../repositories/category_repository.dart';
import '../repositories/asset_repository.dart';
import '../repositories/asset_document_repository.dart';

class AddAssetScreen extends StatefulWidget {
  final String? initialCategoryId;
  const AddAssetScreen({super.key, this.initialCategoryId});
  static Future<void> navigateTo(BuildContext context, {String? categoryId}) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddAssetScreen(initialCategoryId: categoryId)));
  @override State<AddAssetScreen> createState() => _AddAssetScreenState();
}
class _AddAssetScreenState extends State<AddAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final AssetRepository _assetRepository;
  late final CategoryRepository _categoryRepository;
  late final AssetDocumentRepository _documentRepository;
  final _imagePicker = ImagePicker();
  List<LocalCategory> _categories = [];
  String _selectedEmoji = '📦';
  String? _selectedCategoryId;
  File? _primaryImage;
  final List<File> _documents = [];
  bool _qrEnabled = false;
  bool _isLoading = false;
  final List<Map<String, String>> _customFields = [];

  @override void initState() { super.initState(); _selectedCategoryId = widget.initialCategoryId; final database = AppDatabase(); final storage = LocalFileStorage(); _assetRepository = AssetRepository(database: database, fileStorage: storage); _categoryRepository = CategoryRepository(database: database); _documentRepository = AssetDocumentRepository(database: database, fileStorage: storage); _loadLocalCategories(); }
  Future<void> _loadLocalCategories() async { try { final categories = await _categoryRepository.getCategories('local_user'); if (!mounted) return; final ids = categories.map((c) => c.id).toSet(); setState(() { _categories = categories; if (_selectedCategoryId != null && !ids.contains(_selectedCategoryId)) _selectedCategoryId = null; }); } catch (e, st) { debugPrint('Error loading categories: $e'); debugPrintStack(stackTrace: st); if (mounted) setState(() => _categories = []); } }
  @override void dispose() { _nameController.dispose(); _locationController.dispose(); _descriptionController.dispose(); super.dispose(); }
  Future<void> _pickPrimaryImage(ImageSource source) async { try { final picked = await _imagePicker.pickImage(source: source, imageQuality: 90, maxWidth: 2048, maxHeight: 2048); if (picked != null && mounted) setState(() => _primaryImage = File(picked.path)); } catch (_) { _showSnackBar('Failed to pick asset photo.', isError: true); } }
  Future<void> _showPrimaryImageSourcePicker() async { await showModalBottomSheet<void>(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [const SizedBox(height: 12), Text('Asset Photo', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)), ListTile(leading: const Icon(Icons.camera_alt_rounded), title: const Text('Take Photo'), onTap: () { Navigator.pop(sheetContext); _pickPrimaryImage(ImageSource.camera); }), ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('Choose from Gallery'), onTap: () { Navigator.pop(sheetContext); _pickPrimaryImage(ImageSource.gallery); }), const SizedBox(height: 8)])); }

  Future<void> _pickDocuments() async {
    try {
      // file_picker 12 uses static methods and returns List<PlatformFile> directly.
      final files = await FilePicker.pickFiles();
      if (!mounted || files.isEmpty) return;
      final picked = files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
      setState(() { for (final file in picked) { if (!_documents.any((existing) => existing.path == file.path)) _documents.add(file); } });
    } catch (e) { _showSnackBar('Unable to select files.', isError: true); }
  }

  void _showSnackBar(String message, {bool isError = false}) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)), backgroundColor: isError ? AppColors.error : AppColors.success, behavior: SnackBarBehavior.floating)); }
  void _showEmojiPicker() { showModalBottomSheet(context: context, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (pickerContext) => SafeArea(child: SizedBox(height: 390, child: EmojiPicker(onEmojiSelected: (_, emoji) { setState(() => _selectedEmoji = emoji.emoji); Navigator.pop(pickerContext); })))); }
  void _showCreateCategoryDialog() { final nameCtrl = TextEditingController(); String catEmoji = '📂'; showDialog(context: context, builder: (dialogCtx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Text('Create New Category', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)), content: Column(mainAxisSize: MainAxisSize.min, children: [CustomTextField(controller: nameCtrl, hintText: 'e.g. Tools, Books, Office', labelText: 'Category Name'), const SizedBox(height: 12), InkWell(onTap: () async { final selected = await showModalBottomSheet<String>(context: ctx, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (pickerCtx) => SafeArea(child: SizedBox(height: 380, child: EmojiPicker(onEmojiSelected: (_, value) => Navigator.pop(pickerCtx, value.emoji))))); if (selected != null) setDialogState(() => catEmoji = selected); }, borderRadius: BorderRadius.circular(14), child: Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primaryPurple.withAlpha(10), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primaryPurple.withAlpha(45))), child: Row(children: [Text(catEmoji, style: const TextStyle(fontSize: 30)), const SizedBox(width: 12), const Expanded(child: Text('Choose any emoji')), const Icon(Icons.chevron_right_rounded)]))) ]), actions: [TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')), ElevatedButton(onPressed: () async { final name = nameCtrl.text.trim(); if (name.isEmpty) return; try { final id = await _categoryRepository.createCategoryIfNotExists(ownerId: 'local_user', name: name, emoji: catEmoji); await _loadLocalCategories(); if (mounted) setState(() => _selectedCategoryId = id); if (dialogCtx.mounted) Navigator.pop(dialogCtx); } catch (_) { if (mounted) _showSnackBar('Failed to create category.', isError: true); } }, child: const Text('Create'))])); }

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final asset = LocalAsset(id: const Uuid().v4(), ownerId: 'local_user', name: _nameController.text.trim(), categoryId: _selectedCategoryId, emoji: _selectedEmoji, location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(), description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(), imagePath: _primaryImage?.path, createdAt: DateTime.now(), updatedAt: DateTime.now(), qrEnabled: _qrEnabled);
      await _assetRepository.createAsset(asset);
      for (final file in _documents) { await _documentRepository.addDocument(assetId: asset.id, sourcePath: file.path, fileName: file.uri.pathSegments.isEmpty ? 'Document' : file.uri.pathSegments.last); }
      if (mounted) { _showSnackBar('Asset created successfully.'); Navigator.pop(context, true); }
    } catch (e) { if (mounted) _showSnackBar('Failed to save asset.', isError: true); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(backgroundColor: AppColors.scaffoldBg, appBar: AppBar(title: Text('Create Asset', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)), backgroundColor: Colors.white, elevation: 0), body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 40), children: [
    InkWell(onTap: _showPrimaryImageSourcePicker, child: Container(height: 170, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.inputBorder)), child: _primaryImage == null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.add_a_photo_outlined, size: 38, color: AppColors.primaryPurple), const SizedBox(height: 8), Text('Add Asset Photo', style: GoogleFonts.outfit(fontWeight: FontWeight.w600))])) : ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(_primaryImage!, fit: BoxFit.cover))),
    const SizedBox(height: 18),
    CustomTextField(controller: _nameController, labelText: 'Asset Name *', hintText: 'e.g. Honda Bike', validator: (v) => v == null || v.trim().isEmpty ? 'Enter an asset name' : null),
    const SizedBox(height: 14),
    InkWell(onTap: _showEmojiPicker, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.inputBorder)), child: Row(children: [Text(_selectedEmoji, style: const TextStyle(fontSize: 28)), const SizedBox(width: 12), const Expanded(child: Text('Choose emoji')), const Icon(Icons.chevron_right_rounded)]))),
    const SizedBox(height: 14),
    DropdownButtonFormField<String>(value: _selectedCategoryId, decoration: const InputDecoration(labelText: 'Category'), items: [..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.emoji ?? '📂'} ${c.name}'))), const DropdownMenuItem(value: '__create__', child: Text('+ Create New Category'))], onChanged: (v) { if (v == '__create__') { _showCreateCategoryDialog(); } else setState(() => _selectedCategoryId = v); }),
    const SizedBox(height: 14),
    CustomTextField(controller: _locationController, labelText: 'Location', hintText: 'Where is this asset?'),
    const SizedBox(height: 14),
    CustomTextField(controller: _descriptionController, labelText: 'Description', hintText: 'Add details...', maxLines: 3),
    const SizedBox(height: 18),
    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.inputBorder)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Documents & Files', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text('Attach receipts, warranties, manuals or other files.', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)), const SizedBox(height: 12), OutlinedButton.icon(onPressed: _pickDocuments, icon: const Icon(Icons.attach_file_rounded), label: const Text('Add Files')), if (_documents.isNotEmpty) ...[const SizedBox(height: 8), ..._documents.map((file) => ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: const Icon(Icons.insert_drive_file_outlined), title: Text(file.uri.pathSegments.last, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _documents.remove(file))))]])),
    const SizedBox(height: 18),
    SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Enable QR Code'), value: _qrEnabled, activeColor: AppColors.primaryPurple, onChanged: (v) => setState(() => _qrEnabled = v)),
    const SizedBox(height: 24),
    SizedBox(height: 54, child: ElevatedButton(onPressed: _isLoading ? null : _saveAsset, child: Text(_isLoading ? 'Saving...' : 'Save Asset'))),
  ])));
}
