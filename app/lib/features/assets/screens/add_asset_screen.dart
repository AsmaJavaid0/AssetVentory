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
  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
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

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    final database = AppDatabase();
    final storage = LocalFileStorage();
    _assetRepository = AssetRepository(database: database, fileStorage: storage);
    _categoryRepository = CategoryRepository(database: database);
    _documentRepository = AssetDocumentRepository(database: database, fileStorage: storage);
    _loadLocalCategories();
  }

  Future<void> _loadLocalCategories() async {
    try {
      final categories = await _categoryRepository.getCategories('local_user');
      if (!mounted) return;
      final ids = categories.map((c) => c.id).toSet();
      setState(() { _categories = categories; if (_selectedCategoryId != null && !ids.contains(_selectedCategoryId)) _selectedCategoryId = null; });
    } catch (e, st) { debugPrint('Error loading categories: $e'); debugPrintStack(stackTrace: st); if (mounted) setState(() => _categories = []); }
  }

  @override
  void dispose() { _nameController.dispose(); _locationController.dispose(); _descriptionController.dispose(); super.dispose(); }

  Future<void> _pickPrimaryImage(ImageSource source) async {
    try { final picked = await _imagePicker.pickImage(source: source, imageQuality: 90, maxWidth: 2048, maxHeight: 2048); if (picked != null && mounted) setState(() => _primaryImage = File(picked.path)); }
    catch (_) { _showSnackBar('Failed to pick asset photo.', isError: true); }
  }

  Future<void> _showPrimaryImageSourcePicker() async {
    await showModalBottomSheet<void>(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 12), Text('Asset Photo', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
      ListTile(leading: const Icon(Icons.camera_alt_rounded), title: const Text('Take Photo'), onTap: () { Navigator.pop(sheetContext); _pickPrimaryImage(ImageSource.camera); }),
      ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('Choose from Gallery'), onTap: () { Navigator.pop(sheetContext); _pickPrimaryImage(ImageSource.gallery); }),
      const SizedBox(height: 8),
    ])));
  }

  Future<void> _pickDocuments() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: false);
      if (result == null || !mounted) return;
      final files = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
      setState(() {
        for (final file in files) { if (!_documents.any((existing) => existing.path == file.path)) _documents.add(file); }
      });
    } catch (e) { _showSnackBar('Unable to select files.', isError: true); }
  }

  void _showSnackBar(String message, {bool isError = false}) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)), backgroundColor: isError ? AppColors.error : AppColors.success, behavior: SnackBarBehavior.floating)); }

  void _showEmojiPicker() {
    showModalBottomSheet(context: context, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (pickerContext) => SafeArea(child: SizedBox(height: 390, child: EmojiPicker(onEmojiSelected: (_, emoji) { setState(() => _selectedEmoji = emoji.emoji); Navigator.pop(pickerContext); }))));
  }

  void _showCreateCategoryDialog() {
    final nameCtrl = TextEditingController();
    String catEmoji = '📂';
    showDialog(context: context, builder: (dialogCtx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Create New Category', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        CustomTextField(controller: nameCtrl, hintText: 'e.g. Tools, Books, Office', labelText: 'Category Name'),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final selected = await showModalBottomSheet<String>(context: ctx, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (pickerCtx) => SafeArea(child: SizedBox(height: 380, child: EmojiPicker(onEmojiSelected: (_, value) => Navigator.pop(pickerCtx, value.emoji)))));
            if (selected != null) setDialogState(() => catEmoji = selected);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primaryPurple.withAlpha(10), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primaryPurple.withAlpha(45))), child: Row(children: [Text(catEmoji, style: const TextStyle(fontSize: 30)), const SizedBox(width: 12), const Expanded(child: Text('Choose any emoji')), const Icon(Icons.chevron_right_rounded)])),
        ),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')), ElevatedButton(onPressed: () async { final name = nameCtrl.text.trim(); if (name.isEmpty) return; try { final id = await _categoryRepository.createCategoryIfNotExists(ownerId: 'local_user', name: name, emoji: catEmoji); await _loadLocalCategories(); if (mounted) setState(() => _selectedCategoryId = id); if (dialogCtx.mounted) Navigator.pop(dialogCtx); } catch (_) { if (mounted) _showSnackBar('Failed to create category.', isError: true); } }, child: const Text('Create'))],
    )));
  }

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final fieldsMap = <String, String>{};
      for (final field in _customFields) { final n = field['name']; final v = field['value']; if (n != null && v != null) fieldsMap[n] = v; }
      final asset = await _assetRepository.createAssetWithImage(ownerId: 'local_user', name: _nameController.text.trim(), emoji: _selectedEmoji, categoryId: _selectedCategoryId, imageFile: _primaryImage, location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(), description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(), qrEnabled: _qrEnabled, customFields: fieldsMap);
      for (final file in _documents) { await _documentRepository.addDocument(assetId: asset.id, sourceFile: file); }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('Error saving local asset: $e'); debugPrintStack(stackTrace: st);
      if (mounted) { setState(() => _isLoading = false); _showSnackBar('Failed to save asset or documents. Please try again.', isError: true); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 380;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)), title: Text('Add Asset', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20))),
      body: SingleChildScrollView(padding: EdgeInsets.fromLTRB(compact ? 14 : 20, 8, compact ? 14 : 20, 28), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Asset Photo & Emoji', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)), const SizedBox(height: 8),
        if (_primaryImage != null) _selectedImageCard() else _imageChoiceRow(compact),
        const SizedBox(height: 20),
        CustomTextField(controller: _nameController, hintText: 'e.g. My Laptop, Toyota Camry', labelText: 'Asset Name *', prefixIcon: Icons.drive_file_rename_outline_rounded, validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null),
        const SizedBox(height: 18),
        Row(children: [Expanded(child: Text('Category', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))), TextButton.icon(onPressed: _showCreateCategoryDialog, icon: const Icon(Icons.add_circle_outline_rounded, size: 16), label: const Text('Create New'), style: TextButton.styleFrom(padding: EdgeInsets.zero))]),
        const SizedBox(height: 6), _categoryDropdown(),
        const SizedBox(height: 18),
        _documentsSection(),
        const SizedBox(height: 18),
        CustomTextField(controller: _locationController, hintText: 'e.g. Master Bedroom, Garage', labelText: 'Location (Optional)', prefixIcon: Icons.location_on_outlined),
        const SizedBox(height: 18),
        CustomTextField(controller: _descriptionController, hintText: 'Warranty details, purchase info...', labelText: 'Description / Notes (Optional)', prefixIcon: Icons.notes_rounded),
        const SizedBox(height: 24), _customFieldsPlaceholder(),
        const SizedBox(height: 24),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: _qrEnabled, onChanged: (v) => setState(() => _qrEnabled = v), activeThumbColor: AppColors.primaryPurple, title: Text('Generate QR Code', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)), subtitle: Text('Enable QR identification for this asset.', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary))),
        const SizedBox(height: 22),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _isLoading ? null : _saveAsset, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Asset'))),
      ]))),
    );
  }

  Widget _documentsSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Text('Documents & Files', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15))), TextButton.icon(onPressed: _pickDocuments, icon: const Icon(Icons.attach_file_rounded, size: 17), label: const Text('Add Files'))]),
    Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2EF))), child: _documents.isEmpty ? Row(children: [const Icon(Icons.description_outlined, color: AppColors.textMuted), const SizedBox(width: 10), Expanded(child: Text('Attach receipts, warranties, manuals, PDFs or other files.', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted))),]) : Column(children: _documents.map((file) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [const Icon(Icons.insert_drive_file_outlined, size: 20, color: AppColors.primaryPurple), const SizedBox(width: 8), Expanded(child: Text(file.path.split(Platform.pathSeparator).last, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600))), IconButton(onPressed: () => setState(() => _documents.remove(file)), icon: const Icon(Icons.close_rounded, size: 18))]))).toList()))
  ]);

  Widget _categoryDropdown() {
    final ids = _categories.map((c) => c.id).toSet();
    final safeValue = _selectedCategoryId != null && ids.contains(_selectedCategoryId) ? _selectedCategoryId : null;
    if (_selectedCategoryId != safeValue) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _selectedCategoryId = safeValue); });
    return Container(padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE4DFEE), width: 1.2)), child: DropdownButtonHideUnderline(child: DropdownButton<String?>(value: safeValue, isExpanded: true, hint: Text('Select category (optional)', style: GoogleFonts.outfit(color: AppColors.textMuted)), items: [const DropdownMenuItem<String?>(value: null, child: Text('None')), ..._categories.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text('${c.emoji ?? '📂'}  ${c.name}', maxLines: 1, overflow: TextOverflow.ellipsis)))], onChanged: (v) => setState(() => _selectedCategoryId = v))));
  }

  Widget _imageChoiceRow(bool compact) => Row(children: [Expanded(child: InkWell(onTap: _showEmojiPicker, child: Container(height: 58, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE4DFEE))), child: Row(children: [Text(_selectedEmoji, style: const TextStyle(fontSize: 26)), const SizedBox(width: 8), Expanded(child: Text('Choose Emoji', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontWeight: FontWeight.w600))), const Icon(Icons.emoji_emotions_outlined, size: 20)])))), const SizedBox(width: 10), Expanded(child: InkWell(onTap: _showPrimaryImageSourcePicker, child: Container(height: 58, padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: AppColors.primaryPurple.withAlpha(12), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primaryPurple.withAlpha(60))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_a_photo_outlined, size: 18), const SizedBox(width: 5), Flexible(child: Text('Add Photo', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: compact ? 12 : 13)))]))))]);
  Widget _selectedImageCard() => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primaryPurple.withAlpha(80))), child: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 64, height: 64, child: Image.file(_primaryImage!, fit: BoxFit.contain))), const SizedBox(width: 12), Expanded(child: Text('Asset photo selected', maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontWeight: FontWeight.w700))), IconButton(onPressed: _showPrimaryImageSourcePicker, icon: const Icon(Icons.edit_outlined)), IconButton(onPressed: () => setState(() => _primaryImage = null), icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error))]));
  Widget _customFieldsPlaceholder() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text('Custom Fields (Optional)', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15))), TextButton.icon(onPressed: _showAddCustomFieldDialog, icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add Field'), style: TextButton.styleFrom(padding: EdgeInsets.zero))]), if (_customFields.isEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1EEFB))), child: Text('No custom fields added yet. Add details like RAM, Color, or Model.', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13)))]);
  void _showAddCustomFieldDialog() { final name = TextEditingController(); final value = TextEditingController(); showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Add Custom Field'), content: Column(mainAxisSize: MainAxisSize.min, children: [CustomTextField(controller: name, hintText: 'e.g. RAM', labelText: 'Field Name'), const SizedBox(height: 12), CustomTextField(controller: value, hintText: 'e.g. 16 GB', labelText: 'Field Value')]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), ElevatedButton(onPressed: () { if (name.text.trim().isNotEmpty && value.text.trim().isNotEmpty) { setState(() => _customFields.add({'name': name.text.trim(), 'value': value.text.trim()})); Navigator.pop(ctx); } }, child: const Text('Add'))])); }
}
