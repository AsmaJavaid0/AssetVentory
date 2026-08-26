import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../models/local_asset.dart';
import '../models/local_category.dart';

class EditAssetScreen extends StatefulWidget {
  final LocalAsset asset;
  const EditAssetScreen({super.key, required this.asset});

  static Future<void> navigateTo(BuildContext context, LocalAsset asset) {
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EditAssetScreen(asset: asset)));
  }

  @override
  State<EditAssetScreen> createState() => _EditAssetScreenState();
}

class _EditAssetScreenState extends State<EditAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assetRepository = serviceLocator.assetRepository;
  final _categoryRepository = serviceLocator.categoryRepository;
  final _imagePicker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  late String _emoji;
  String? _categoryId;
  late bool _qrEnabled;
  late Map<String, String> _customFields;
  List<LocalCategory> _categories = [];
  File? _newImage;
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    _nameController = TextEditingController(text: asset.name);
    _locationController = TextEditingController(text: asset.location ?? '');
    _descriptionController = TextEditingController(text: asset.description ?? '');
    _emoji = asset.emoji ?? '📦';
    _categoryId = asset.categoryId;
    _qrEnabled = asset.qrEnabled;
    _customFields = Map<String, String>.from(asset.customFields);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryRepository.getCategories('local_user');
      if (!mounted) return;
      final validIds = categories.map((category) => category.id).toSet();
      setState(() {
        _categories = categories;
        // An asset can outlive a deleted category. Never give DropdownButton
        // a value that isn't represented by exactly one menu item.
        if (_categoryId != null && !validIds.contains(_categoryId)) {
          _categoryId = null;
        }
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading categories: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _categories = [];
        _categoryId = null;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickNewImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(source: source, imageQuality: 90, maxWidth: 2048, maxHeight: 2048);
      if (picked == null || !mounted) return;
      setState(() => _newImage = File(picked.path));
    } catch (e, stackTrace) {
      debugPrint('Error selecting image: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not select the image.')));
    }
  }

  Future<void> _changeImage() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Change Asset Image', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ListTile(leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryPurple), title: const Text('Take Photo'), onTap: () { Navigator.pop(sheetContext); _pickNewImage(ImageSource.camera); }),
            ListTile(leading: const Icon(Icons.photo_library_rounded, color: AppColors.primaryPurple), title: const Text('Choose from Gallery'), onTap: () { Navigator.pop(sheetContext); _pickNewImage(ImageSource.gallery); }),
          ]),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving || _deleting) return;
    setState(() => _saving = true);
    try {
      var updated = widget.asset.copyWith(
        name: _nameController.text.trim(), categoryId: _categoryId, emoji: _emoji,
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        qrEnabled: _qrEnabled, customFields: _customFields, updatedAt: DateTime.now(),
      );
      if (_newImage != null) {
        updated = await _assetRepository.updateAssetImage(asset: updated, imageFile: _newImage!);
      } else {
        await _assetRepository.updateAsset(updated);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, stackTrace) {
      debugPrint('Error updating asset: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update asset.')));
    }
  }

  Future<void> _deleteAsset() async {
    if (_deleting || _saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Asset?'),
        content: Text('"${widget.asset.name}" will be permanently removed from this device. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await _assetRepository.deleteAsset(widget.asset.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, stackTrace) {
      debugPrint('Error deleting asset: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete asset.')));
    }
  }

  void _chooseEmoji() {
    const emojis = ['📦', '💻', '📱', '🚗', '🏠', '🔧', '📚', '👕', '🎮', '🎨', '🛠️', '💍'];
    showModalBottomSheet(context: context, builder: (sheetContext) => SafeArea(child: GridView.count(crossAxisCount: 4, shrinkWrap: true, padding: const EdgeInsets.all(24), children: emojis.map((emoji) => InkWell(onTap: () { setState(() => _emoji = emoji); Navigator.pop(sheetContext); }, child: Center(child: Text(emoji, style: const TextStyle(fontSize: 32))))).toList())));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(title: Text('Edit Asset', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary)), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildImageEditor(), const SizedBox(height: 22),
              CustomTextField(controller: _nameController, labelText: 'Asset Name *', hintText: 'e.g. My Laptop', prefixIcon: Icons.inventory_2_outlined, validator: (value) => value == null || value.trim().isEmpty ? 'Name is required' : null),
              const SizedBox(height: 18),
              Text('Category', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textSecondary)), const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE4DFEE))),
                child: DropdownButtonHideUnderline(child: DropdownButton<String?>(
                  value: _categoryId,
                  isExpanded: true,
                  hint: const Text('Select category'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Uncategorized')),
                    ..._categories.map((category) => DropdownMenuItem<String?>(value: category.id, child: Text('${category.emoji ?? '📂'}  ${category.name}', maxLines: 1, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                )),
              ),
              const SizedBox(height: 18),
              CustomTextField(controller: _locationController, labelText: 'Location', hintText: 'e.g. Bedroom, Garage', prefixIcon: Icons.location_on_outlined),
              const SizedBox(height: 18),
              CustomTextField(controller: _descriptionController, labelText: 'Description / Notes', hintText: 'Additional information', prefixIcon: Icons.notes_rounded),
              const SizedBox(height: 20),
              SwitchListTile(contentPadding: EdgeInsets.zero, value: _qrEnabled, onChanged: (value) => setState(() => _qrEnabled = value), activeThumbColor: AppColors.primaryPurple, title: Text('Generate QR Code', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)), subtitle: Text('Enable QR identification for this asset.', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary))),
              const SizedBox(height: 22),
              SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: (_saving || _deleting) ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Save Changes', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)))),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(onPressed: (_saving || _deleting) ? null : _deleteAsset, icon: _deleting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.delete_outline_rounded), label: Text(_deleting ? 'Deleting...' : 'Delete Asset', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)), style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: BorderSide(color: AppColors.error.withAlpha(100)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildImageEditor() {
    final currentPath = widget.asset.imagePath;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Asset Image', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)), const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 180, maxHeight: 300),
          color: AppColors.primaryPurple.withAlpha(10),
          child: _newImage != null ? Image.file(_newImage!, fit: BoxFit.contain) : currentPath != null && currentPath.isNotEmpty ? Image.file(File(currentPath), fit: BoxFit.contain, errorBuilder: (_, _, _) => _imageFallback()) : _imageFallback(),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _saving || _deleting ? null : _changeImage, icon: const Icon(Icons.edit_outlined), label: Text(_newImage != null || (currentPath?.isNotEmpty ?? false) ? 'Change Image' : 'Add Image', maxLines: 1, overflow: TextOverflow.ellipsis), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryPurple, side: BorderSide(color: AppColors.primaryPurple.withAlpha(90)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 13)))),
    ]);
  }

  Widget _imageFallback() => InkWell(
        onTap: _chooseEmoji,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_emoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 6),
              Text(
                'Tap to change emoji',
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
}
