import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_palette.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../models/local_asset.dart';
import '../models/local_category.dart';

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
      final cats = await _categoryRepository.getCategories('local_user');
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Category load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null && mounted) setState(() => _newImage = File(picked.path));
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
            setState(() => _emoji = emoji.emoji);
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
              setState(() => _customFields[key] = value);
              Navigator.pop(dialogContext);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _popWithRefresh() => Navigator.of(context).pop(true);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _assetRepository.updateAsset(
        id: widget.asset.id,
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
      );
      if (!mounted) return;
      AppSnackBar.show(context, 'Asset updated successfully!', isSuccess: true);
      _popWithRefresh();
    } catch (e) {
      debugPrint('Update asset error: $e');
      if (!mounted) return;
      AppSnackBar.show(context, 'Failed to update asset. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete Asset', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete "${widget.asset.name}"? This action cannot be undone.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _deleting = true);
    try {
      await _assetRepository.deleteAsset(widget.asset.id);
      if (!mounted) return;
      AppSnackBar.show(context, 'Asset deleted.', isSuccess: true);
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Delete asset error: $e');
      if (!mounted) return;
      setState(() => _deleting = false);
      AppSnackBar.show(context, 'Failed to delete asset.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.isDark ? AppColors.heroDarkBg : AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Edit Asset', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
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
                padding: EdgeInsets.fromLTRB(20, 16, 20, _saving ? 32 : 120),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImagePicker(),
                      const SizedBox(height: 28),
                      _SectionHeader(title: 'Basic Info', palette: palette),
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
                      _SectionHeader(title: 'Details', palette: palette),
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
                      _SectionHeader(title: 'Custom Fields', palette: palette),
                      const SizedBox(height: 16),
                      _buildCustomFields(),
                      const SizedBox(height: 24),
                      _SectionHeader(title: 'Advanced', palette: palette),
                      const SizedBox(height: 16),
                      _buildQrToggle(),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: _loading ? null : _buildSaveBar(palette),
    );
  }

  Widget _buildImagePicker() {
    final palette = AppPalette.of(context);
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
                color: palette.isDark ? AppColors.heroCardBg : AppColors.lightLavender,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryPurple, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withAlpha(30),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _newImage != null
                  ? ClipOval(
                      child: Image.file(_newImage!, fit: BoxFit.cover, width: 110, height: 110))
                  : (imagePath != null && imagePath.isNotEmpty)
                      ? ClipOval(
                          child: Image.file(File(imagePath), fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _emojiFallback()))
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
                    palette: palette,
                    tooltip: 'Change emoji',
                  ),
                  const SizedBox(height: 8),
                  _IconActionButton(
                    icon: Icons.camera_alt_rounded,
                    onTap: _pickImage,
                    palette: palette,
                    isPrimary: true,
                    tooltip: 'Add photo',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emojiFallback() => Center(child: Text(_emoji, style: const TextStyle(fontSize: 48)));

  Widget _buildCategoryDropdown() {
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Category',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: palette.onSurfaceMuted)),
        ),
        Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.inputBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(palette.isDark ? 20 : 8),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _categoryId,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: palette.iconMuted, size: 24),
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              dropdownColor: palette.surface,
              hint: Text('Select category',
                  style: GoogleFonts.outfit(color: palette.iconMuted, fontSize: 15)),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Uncategorized', style: TextStyle(fontWeight: FontWeight.w500)),
                ),
                ..._categories.map((c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name, style: GoogleFonts.outfit(fontSize: 15)),
                    )),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
              borderRadius: BorderRadius.circular(16),
              style: GoogleFonts.outfit(fontSize: 15, color: palette.onSurface),
            ),
          ),
        ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(palette.isDark ? 20 : 8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primaryPurple, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enable QR Code',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: palette.onSurface)),
                const SizedBox(height: 2),
                Text('Generate a QR tag for quick scanning.',
                    style: GoogleFonts.outfit(fontSize: 12, color: palette.onSurfaceMuted)),
              ],
            ),
          ),
          Switch(
            value: _qrEnabled,
            activeColor: AppColors.primaryPurple,
            activeTrackColor: AppColors.primaryPurple.withAlpha(80),
            inactiveThumbColor: palette.iconMuted,
            inactiveTrackColor: palette.controlBorder,
            onChanged: (value) => setState(() => _qrEnabled = value),
          ),
        ],
      ),
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
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: palette.onSurfaceMuted)),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextButton.icon(
                onPressed: _addCustomField,
                icon: Icon(Icons.add_rounded, size: 16, color: AppColors.primaryPurple),
                label: Text('Add Field', style: GoogleFonts.outfit(color: AppColors.primaryPurple, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
        if (_customFields.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surfaceVariant.withAlpha(50),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border, style: BorderStyle.solid, strokeAlign: BorderSide.strokeAlignInside),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: palette.iconMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add custom fields to store extra details like serial numbers, purchase dates, warranty info, etc.',
                    style: GoogleFonts.outfit(fontSize: 13, color: palette.textMuted),
                  ),
                ),
              ],
            ),
          )
        else
          ..._customFields.entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(palette.isDark ? 15 : 5),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: palette.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.label_outline_rounded, color: palette.iconMuted, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: palette.onSurface),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.value,
                          style: GoogleFonts.outfit(fontSize: 12, color: palette.onSurfaceMuted, fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _customFields.remove(entry.key)),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.delete_outline_rounded, color: AppColors.error.withAlpha(200), size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSaveBar(AppPalette palette) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(top: BorderSide(color: palette.divider, width: 1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(palette.isDark ? 40 : 15),
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
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded, size: 22),
              label: Text(
                _saving ? 'Saving…' : 'Save Changes',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: AppColors.primaryPurple.withAlpha(80),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final AppPalette palette;

  const _SectionHeader({required this.title, required this.palette});

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
            color: palette.onSurface,
          ),
        ),
      ],
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final AppPalette palette;
  final bool isPrimary;
  final String? tooltip;

  const _IconActionButton({
    required this.icon,
    required this.onTap,
    required this.palette,
    this.isPrimary = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isPrimary ? AppColors.primaryPurple : palette.surface,
        shape: const CircleBorder(),
        elevation: isPrimary ? 4 : 2,
        shadowColor: isPrimary ? AppColors.primaryPurple.withAlpha(80) : Colors.black.withAlpha(30),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              color: isPrimary ? Colors.white : palette.onSurfaceMuted,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
