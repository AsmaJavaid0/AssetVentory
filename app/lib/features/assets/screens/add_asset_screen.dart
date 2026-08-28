import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/local_file_storage.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../models/local_asset.dart';
import '../models/local_category.dart';
import '../repositories/asset_document_repository.dart';
import '../repositories/asset_repository.dart';
import '../repositories/category_repository.dart';
import '../widgets/create_category_sheet.dart';

class AddAssetScreen extends StatefulWidget {
  final String? initialCategoryId;

  const AddAssetScreen({super.key, this.initialCategoryId});

  static Future<void> navigateTo(
    BuildContext context, {
    String? categoryId,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddAssetScreen(initialCategoryId: categoryId),
      ),
    );
  }

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<File> _documents = [];

  late final AssetRepository _assetRepository;
  late final CategoryRepository _categoryRepository;
  late final AssetDocumentRepository _documentRepository;

  List<LocalCategory> _categories = [];
  String _selectedEmoji = '📦';
  String? _selectedCategoryId;
  File? _primaryImage;
  bool _qrEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;

    final database = AppDatabase();
    final storage = LocalFileStorage();
    _assetRepository = AssetRepository(
      database: database,
      fileStorage: storage,
    );
    _categoryRepository = CategoryRepository(database: database);
    _documentRepository = AssetDocumentRepository(
      database: database,
      fileStorage: storage,
    );
    _loadLocalCategories();
  }

  Future<void> _loadLocalCategories() async {
    try {
      final categories = await _categoryRepository.getCategories('local_user');
      if (!mounted) return;

      final ids = categories.map((category) => category.id).toSet();
      setState(() {
        _categories = categories;
        if (_selectedCategoryId != null &&
            !ids.contains(_selectedCategoryId)) {
          _selectedCategoryId = null;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _categories = []);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPrimaryImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (picked != null && mounted) {
        setState(() => _primaryImage = File(picked.path));
      }
    } catch (_) {
      _showSnackBar('Failed to pick asset photo.', isError: true);
    }
  }

  Future<void> _showPrimaryImageSourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                'Asset Photo',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickPrimaryImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickPrimaryImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDocuments() async {
    try {
      final result = await FilePicker.pickFiles(allowMultiple: true);

      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }

      final picked = result.files
          .where((file) => file.path != null)
          .map((file) => File(file.path!))
          .toList();

      setState(() {
        for (final file in picked) {
          if (!_documents.any((existing) => existing.path == file.path)) {
            _documents.add(file);
          }
        }
      });
    } catch (_) {
      _showSnackBar('Unable to select files.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (pickerContext) {
        return SafeArea(
          child: SizedBox(
            height: 390,
            child: EmojiPicker(
              onEmojiSelected: (_, emoji) {
                setState(() => _selectedEmoji = emoji.emoji);
                Navigator.pop(pickerContext);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateCategoryDialog() async {
    String? createdId;

    final created = await CreateCategorySheet.show(
      context,
      onCreateCategory: (name, emoji) async {
        createdId = await _categoryRepository.createCategoryIfNotExists(
          ownerId: 'local_user',
          name: name,
          emoji: emoji,
        );
      },
    );

    if (created == true && createdId != null && createdId!.isNotEmpty) {
      await _loadLocalCategories();
      if (mounted) {
        setState(() => _selectedCategoryId = createdId);
      }
    }
  }

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final asset = LocalAsset(
        id: const Uuid().v4(),
        ownerId: 'local_user',
        name: _nameController.text.trim(),
        categoryId: _selectedCategoryId,
        emoji: _selectedEmoji,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        imagePath: _primaryImage?.path,
        createdAt: now,
        updatedAt: now,
        qrEnabled: _qrEnabled,
      );

      await _assetRepository.createAsset(asset);

      for (final file in _documents) {
        await _documentRepository.addDocument(
          assetId: asset.id,
          sourceFile: file,
          displayName: file.uri.pathSegments.isEmpty
              ? 'Document'
              : file.uri.pathSegments.last,
        );
      }

      if (mounted) {
        _showSnackBar('Asset created successfully.');
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('Failed to save asset.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Create Asset',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            InkWell(
              onTap: _showPrimaryImageSourcePicker,
              child: Container(
                height: 170,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: _primaryImage == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_a_photo_outlined,
                              size: 38,
                              color: AppColors.primaryPurple,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add Asset Photo',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(
                          _primaryImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 18),
            CustomTextField(
              controller: _nameController,
              labelText: 'Asset Name *',
              hintText: 'e.g. Honda Bike',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter an asset name';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _showEmojiPicker,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedEmoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Choose emoji')),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                ..._categories.map(
                  (category) => DropdownMenuItem<String>(
                    value: category.id,
                    child: Text(
                      '${category.emoji ?? '📂'} ${category.name}',
                    ),
                  ),
                ),
                const DropdownMenuItem<String>(
                  value: '__create__',
                  child: Text('+ Create New Category'),
                ),
              ],
              onChanged: (value) {
                if (value == '__create__') {
                  _showCreateCategoryDialog();
                } else {
                  setState(() => _selectedCategoryId = value);
                }
              },
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _locationController,
              labelText: 'Location',
              hintText: 'Where is this asset?',
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _descriptionController,
              labelText: 'Description',
              hintText: 'Add details...',
              maxLines: 3,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Documents & Files',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Attach receipts, warranties, manuals or other files.',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickDocuments,
                    icon: const Icon(Icons.attach_file_rounded),
                    label: const Text('Add Files'),
                  ),
                  if (_documents.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ..._documents.map(
                      (file) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(
                          Icons.insert_drive_file_outlined,
                        ),
                        title: Text(
                          file.uri.pathSegments.last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            setState(() => _documents.remove(file));
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable QR Code'),
              value: _qrEnabled,
              activeTrackColor: AppColors.primaryPurple,
              onChanged: (value) => setState(() => _qrEnabled = value),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAsset,
                child: Text(_isLoading ? 'Saving...' : 'Save Asset'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
