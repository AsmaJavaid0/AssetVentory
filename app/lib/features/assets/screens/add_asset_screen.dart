import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  static Future<void> navigateTo(BuildContext context,
      {String? categoryId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddAssetScreen(initialCategoryId: categoryId),
      ),
    );
  }

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen>
    with SingleTickerProviderStateMixin {
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

  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    final database = AppDatabase();
    _assetRepository =
        AssetRepository(database: database, fileStorage: LocalFileStorage());
    _categoryRepository = CategoryRepository(database: database);
    _loadCategories();

    // Initialize animations for smooth transitions
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
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
    final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked != null && mounted) {
      setState(() => _primaryImage = File(picked.path));
    }
  }

  void _addCustomField() {
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).brightness == Brightness.dark
            ? AppColors.heroCardBg
            : Colors.white,
        title: Text('Add Custom Field',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: keyController,
                hintText: 'Field name (e.g. Serial No.)',
                labelText: 'Field name',
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: valueController,
                hintText: 'Value',
                labelText: 'Value',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final key = keyController.text.trim();
              final value = valueController.text.trim();
              if (key.isEmpty || value.isEmpty) return;
              setState(() => _customFields.add({'key': key, 'value': value}));
              Navigator.pop(dialogContext);
            },
            child: Text('Add',
                style: GoogleFonts.outfit(
                    color: AppColors.primaryPurple, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final File? imageFile = _primaryImage;
      await _assetRepository.createAssetWithImage(
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
        imageFile: imageFile,
        qrEnabled: _qrEnabled,
        customFields: {
          for (final field in _customFields) field['key']!: field['value']!
        },
      );
      if (!mounted) return;
      AppSnackBar.show(context, 'Asset added successfully!', isSuccess: true);
      if (mounted) {
        Navigator.of(context).pop();
      }
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(_slideController),
        child: Scaffold(
          backgroundColor:
              palette.isDark ? AppColors.heroDarkBg : AppColors.scaffoldBg,
          appBar: AppBar(
            title: Text('Add Asset',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.25)),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20,
                  _isLoading ? 32 : MediaQuery.of(context).viewInsets.bottom + 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImagePicker(context, palette),
                    const SizedBox(height: 24),
                    CustomTextField(
                      controller: _nameController,
                      hintText: 'Asset name',
                      labelText: 'Name',
                      prefixIcon: Icons.inventory_2_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Please enter a name'
                              : null,
                    ),
                    const SizedBox(height: 20),
                    _buildCategoryDropdown(context, palette),
                    const SizedBox(height: 20),
                    CustomTextField(
                      controller: _locationController,
                      hintText: 'e.g. Living Room',
                      labelText: 'Location',
                      prefixIcon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 20),
                    CustomTextField(
                      controller: _descriptionController,
                      hintText: 'Add a description…',
                      labelText: 'Description',
                      prefixIcon: Icons.notes_outlined,
                      keyboardType: TextInputType.multiline,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    _buildCustomFields(context, palette),
                    const SizedBox(height: 16),
                    _buildQrToggle(context, palette),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: _buildSaveBar(context, palette),
        ),
      ),
    );
  }

  Widget _buildImagePicker(BuildContext context, AppPalette palette) {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: palette.isDark
                    ? AppColors.heroCardBg
                    : AppColors.lightLavender,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primaryPurple, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: _primaryImage != null
                  ? ClipOval(
                      child: Image.file(_primaryImage!,
                          fit: BoxFit.cover, width: 120, height: 120),
                    )
                  : Center(
                      child: Text(_selectedEmoji,
                          style: const TextStyle(fontSize: 52)),
                    ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withAlpha(60),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(
      BuildContext context, AppPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Category',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    child: Text(c.name,
                        style: GoogleFonts.outfit(fontSize: 14)),
                  ),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _selectedCategoryId = value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomFields(BuildContext context, AppPalette palette) {
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
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppColors.primaryPurple)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._customFields.asMap().entries.map((entry) {
          final index = entry.key;
          final field = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(field['key']!,
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(field['value']!,
                          style: GoogleFonts.outfit(
                              color: palette.onSurfaceMuted, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.error, size: 20),
                  onPressed: () =>
                      setState(() => _customFields.removeAt(index)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildQrToggle(BuildContext context, AppPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.qr_code_2_rounded,
                color: AppColors.primaryPurple, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enable QR Code',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text('Generate a QR tag for quick scanning.',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: palette.onSurfaceMuted)),
              ],
            ),
          ),
          Switch(
            value: _qrEnabled,
            activeColor: AppColors.primaryPurple,
            trackColor: const MaterialStatePropertyAll(
                Colors.grey),
            onChanged: (value) =>
                setState(() => _qrEnabled = value),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar(BuildContext context, AppPalette palette) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(
                top: BorderSide(color: palette.border)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(_isLoading ? 'Saving…' : 'Add Asset',
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2)),
            ),
          ),
        ),
      );
}