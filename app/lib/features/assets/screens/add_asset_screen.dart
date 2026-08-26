import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_palette.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/local_file_storage.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../models/local_category.dart';
import '../repositories/category_repository.dart';
import '../repositories/asset_repository.dart';

class AddAssetScreen extends StatefulWidget {
  final String? initialCategoryId;
  const AddAssetScreen({super.key, this.initialCategoryId});

  static Future<void> navigateTo(BuildContext context, {String? categoryId}) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AddAssetScreen(initialCategoryId: categoryId)),
      );

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
  final _imagePicker = ImagePicker();
  List<LocalCategory> _categories = [];
  String _selectedEmoji = '📦';
  String? _selectedCategoryId;
  File? _primaryImage;
  bool _qrEnabled = false;
  bool _isLoading = false;
  final List<Map<String, String>> _customFields = [];

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    final database = AppDatabase();
    _assetRepository = AssetRepository(database: database, fileStorage: LocalFileStorage());
    _categoryRepository = CategoryRepository(database: database);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _categoryRepository.getCategories('local_user');
      if (!mounted) return;
      setState(() => _categories = cats);
    } catch (e) {
      debugPrint('Category load error: $e');
    }
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null && mounted) setState(() => _primaryImage = File(picked.path));
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppPalette.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SizedBox(
        height: 340,
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            setState(() => _selectedEmoji = emoji.emoji);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _addCustomField() {
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add Custom Field', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(controller: keyController, hintText: 'Field name (e.g. Serial No.)'),
            const SizedBox(height: 12),
            CustomTextField(controller: valueController, hintText: 'Value'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final key = keyController.text.trim();
              final value = valueController.text.trim();
              if (key.isEmpty || value.isEmpty) return;
              setState(() => _customFields.add({'key': key, 'value': value}));
              Navigator.pop(dialogContext);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _assetRepository.addAsset(
        ownerId: 'local_user',
        name: _nameController.text.trim(),
        emoji: _selectedEmoji,
        categoryId: _selectedCategoryId,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        imagePath: _primaryImage?.path,
        qrEnabled: _qrEnabled,
        customFields: {
          for (final field in _customFields) field['key']!: field['value']!
        },
      );
      if (!mounted) return;
      AppSnackBar.show(context, 'Asset added successfully!', isSuccess: true);
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Add asset error: $e');
      if (!mounted) return;
      AppSnackBar.show(context, 'Failed to add asset. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.isDark ? AppColors.heroDarkBg : AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Add Asset'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, _isLoading ? 32 : 120),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImagePicker(),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _nameController,
                  hintText: 'Asset name',
                  labelText: 'Name',
                  prefixIcon: Icons.inventory_2_outlined,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 16),
                _buildCategoryDropdown(),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _locationController,
                  hintText: 'e.g. Living Room',
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
                ),
                const SizedBox(height: 18),
                _buildCustomFields(),
                const SizedBox(height: 10),
                _buildQrToggle(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildSaveBar(palette),
    );
  }

  Widget _buildImagePicker() {
    final palette = AppPalette.of(context);
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
                color: palette.isDark ? AppColors.heroCardBg : AppColors.lightLavender,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryPurple, width: 2),
              ),
              child: _primaryImage != null
                  ? ClipOval(
                      child: Image.file(_primaryImage!, fit: BoxFit.cover, width: 110, height: 110),
                    )
                  : Center(
                      child: Text(_selectedEmoji, style: const TextStyle(fontSize: 48)),
                    ),
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: const BoxDecoration(
                  color: AppColors.primaryPurple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Category',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.inputBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedCategoryId,
              isExpanded: true,
              hint: Text('Select category',
                  style: GoogleFonts.outfit(color: palette.iconMuted)),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Uncategorized'),
                ),
                ..._categories.map(
                  (c) => DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(c.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _selectedCategoryId = value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomFields() {
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Custom Fields',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            TextButton.icon(
              onPressed: _addCustomField,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        ..._customFields.asMap().entries.map((entry) {
          final index = entry.key;
          final field = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(field['key']!,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                      Text(field['value']!,
                          style: GoogleFonts.outfit(color: palette.onSurfaceMuted, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => setState(() => _customFields.removeAt(index)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildQrToggle() {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_2_rounded, color: AppColors.primaryPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enable QR Code',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                Text('Generate a QR tag for quick scanning.',
                    style: GoogleFonts.outfit(fontSize: 12, color: palette.onSurfaceMuted)),
              ],
            ),
          ),
          Switch(
            value: _qrEnabled,
            activeColor: AppColors.primaryPurple,
            onChanged: (value) => setState(() => _qrEnabled = value),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar(AppPalette palette) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(top: BorderSide(color: palette.border)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _save,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_isLoading ? 'Saving…' : 'Add Asset'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      );

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
