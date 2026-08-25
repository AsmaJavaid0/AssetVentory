import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/database/app_database.dart';
import '../../../core/storage/local_file_storage.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';

import '../models/local_category.dart';
import '../repositories/category_repository.dart';
import '../repositories/asset_repository.dart';

class AddAssetScreen extends StatefulWidget {
  final String? initialCategoryId;

  const AddAssetScreen({
    super.key,
    this.initialCategoryId,
  });

  static Future<void> navigateTo(
    BuildContext context, {
    String? categoryId,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddAssetScreen(
          initialCategoryId: categoryId,
        ),
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

  late final AssetRepository _assetRepository;
  late final CategoryRepository _categoryRepository;

  List<LocalCategory> _categories = [];

  String _selectedEmoji = '📦';
  String? _selectedCategoryId;

  File? _primaryImage;

  bool _qrEnabled = false;
  bool _isLoading = false;

  final List<Map<String, String>> _customFields = [];
  final List<File> _selectedFiles = [];

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();

    _selectedCategoryId = widget.initialCategoryId;

    final database = AppDatabase();

    _assetRepository = AssetRepository(
      database: database,
      fileStorage: LocalFileStorage(),
    );

    _categoryRepository = CategoryRepository(
      database: database,
    );

    _loadLocalCategories();
  }

  Future<void> _loadLocalCategories() async {
    try {
      final categories =
          await _categoryRepository.getCategories('local_user');

      if (!mounted) return;

      setState(() {
        _categories = categories;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading local categories: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _categories = [];
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

  // ---------------------------------------------------------------------------
  // IMAGE PICKING
  // ---------------------------------------------------------------------------

  Future<void> _pickPrimaryImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
      );

      if (picked != null) {
        setState(() {
          _primaryImage = File(picked.path);
        });
      }
    } catch (e) {
      _showSnackBar(
        'Failed to pick asset photo: $e',
        isError: true,
      );
    }
  }

  void _showPrimaryImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(
            vertical: 24,
            horizontal: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Asset Photo',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.primaryPurple,
                  ),
                ),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickPrimaryImage(ImageSource.camera);
                },
              ),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.primaryBlue,
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickPrimaryImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // DOCUMENT / ADDITIONAL IMAGE PICKING
  // ---------------------------------------------------------------------------

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedFiles.add(
            File(pickedFile.path),
          );
        });
      }
    } catch (e) {
      _showSnackBar(
        'Failed to pick image: $e',
        isError: true,
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'txt',
          'xls',
          'xlsx',
        ],
      );

      if (files.isNotEmpty) {
        final selectedFile = files.first;

        if (selectedFile.path != null) {
          setState(() {
            _selectedFiles.add(
              File(selectedFile.path!),
            );
          });
        }
      }
    } catch (e) {
      _showSnackBar(
        'Failed to pick document: $e',
        isError: true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  void _showSnackBar(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor:
            isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMOJI PICKER
  // ---------------------------------------------------------------------------

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (pickerContext) {
        return SafeArea(
          child: SizedBox(
            height: 360,
            child: EmojiPicker(
              onEmojiSelected: (_, emoji) {
                setState(() {
                  _selectedEmoji = emoji.emoji;
                });

                Navigator.of(pickerContext).pop();
              },
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CUSTOM FIELDS
  // ---------------------------------------------------------------------------

  void _showAddCustomFieldDialog() {
    final nameCtrl = TextEditingController();
    final valCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Add Custom Field',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: nameCtrl,
                hintText: 'e.g. RAM, Brand, Warranty Year',
                labelText: 'Field Name',
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: valCtrl,
                hintText: 'e.g. 16 GB, Apple, 2 Years',
                labelText: 'Field Value',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final value = valCtrl.text.trim();

                if (name.isNotEmpty && value.isNotEmpty) {
                  setState(() {
                    _customFields.add({
                      'name': name,
                      'value': value,
                    });
                  });

                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Add',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // LOCAL CATEGORY CREATION
  // ---------------------------------------------------------------------------

  void _showCreateCategoryDialog() {
    final nameCtrl = TextEditingController();
    String catEmoji = '📂';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Create New Category',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomTextField(
                    controller: nameCtrl,
                    hintText: 'e.g. Tools, Books, Office',
                    labelText: 'Category Name',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Category Emoji:',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      DropdownButton<String>(
                        value: catEmoji,
                        items: [
                          '📂',
                          '🛠️',
                          '📚',
                          '👔',
                          '🎨',
                          '🍳',
                          '👟',
                          '💍',
                          '🎮',
                          '🚗',
                        ].map(
                          (emoji) {
                            return DropdownMenuItem<String>(
                              value: emoji,
                              child: Text(
                                emoji,
                                style: const TextStyle(
                                  fontSize: 22,
                                ),
                              ),
                            );
                          },
                        ).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              catEmoji = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();

                    if (name.isEmpty) {
                      return;
                    }

                    try {
                      final categoryId =
                          await _categoryRepository
                              .createCategoryIfNotExists(
                        ownerId: 'local_user',
                        name: name,
                        emoji: catEmoji,
                      );

                      await _loadLocalCategories();

                      if (!mounted) return;

                      setState(() {
                        _selectedCategoryId = categoryId;
                      });

                      Navigator.pop(context);
                    } catch (e, stackTrace) {
                      debugPrint(
                        'Error creating local category: $e',
                      );

                      debugPrintStack(
                        stackTrace: stackTrace,
                      );

                      if (!mounted) return;

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Failed to create category.',
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        AppColors.primaryPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Create',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // DOCUMENT PICKER
  // ---------------------------------------------------------------------------

  void _showDocumentPickerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(
            vertical: 24,
            horizontal: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Document',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.primaryPurple,
                  ),
                ),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.primaryBlue,
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.file_present_rounded,
                    color: Colors.orange,
                  ),
                ),
                title: Text(
                  'Choose File (PDF, DOC)',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SAVE ASSET LOCALLY
  // ---------------------------------------------------------------------------

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, String> fieldsMap = {};

      for (final field in _customFields) {
        final name = field['name'];
        final value = field['value'];

        if (name != null && value != null) {
          fieldsMap[name] = value;
        }
      }

      final localAsset =
          await _assetRepository.createAssetWithImage(
        ownerId: 'local_user',
        name: _nameController.text.trim(),
        emoji: _selectedEmoji.isNotEmpty
            ? _selectedEmoji
            : null,
        categoryId: _selectedCategoryId,
        imageFile: _primaryImage,
        location:
            _locationController.text.trim().isNotEmpty
                ? _locationController.text.trim()
                : null,
        description:
            _descriptionController.text.trim().isNotEmpty
                ? _descriptionController.text.trim()
                : null,
        qrEnabled: _qrEnabled,
        customFields: fieldsMap,
      );

      debugPrint(
        'LOCAL ASSET CREATED: ${localAsset.id}',
      );

      debugPrint(
        'LOCAL IMAGE PATH: ${localAsset.imagePath}',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      Navigator.of(context).pop();
    } catch (e, stackTrace) {
      debugPrint(
        'Error saving local asset: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showSnackBar(
        'Failed to save asset. Please try again.',
        isError: true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Asset',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [

              // ---------------------------------------------------------------
              // ASSET PHOTO & EMOJI
              // ---------------------------------------------------------------

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Asset Photo & Emoji',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_primaryImage != null)
                    Text(
                      'Photo active',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color:
                            AppColors.primaryPurple,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              if (_primaryImage != null) ...[
                Container(
                  padding:
                      const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryPurple
                          .withAlpha(80),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(12),
                        child: Image.file(
                          _primaryImage!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Asset Photo Selected',
                              style:
                                  GoogleFonts.outfit(
                                fontWeight:
                                    FontWeight.w700,
                                fontSize: 14,
                                color:
                                    AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'This image will be displayed instead of an emoji.',
                              style:
                                  GoogleFonts.outfit(
                                fontSize: 11,
                                color:
                                    AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        tooltip: 'Change photo',
                        icon: const Icon(
                          Icons.edit_outlined,
                          color:
                              AppColors.primaryPurple,
                          size: 20,
                        ),
                        onPressed:
                            _showPrimaryImageSourcePicker,
                      ),

                      IconButton(
                        tooltip: 'Remove photo',
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _primaryImage = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                InkWell(
                  onTap: _showEmojiPicker,
                  borderRadius:
                      BorderRadius.circular(12),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Text(
                          _selectedEmoji,
                          style:
                              const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Optional fallback emoji',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color:
                                AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: _showEmojiPicker,
                        borderRadius:
                            BorderRadius.circular(14),
                        child: Container(
                          height: 58,
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  const Color(0xFFE4DFEE),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _selectedEmoji,
                                style:
                                    const TextStyle(
                                  fontSize: 28,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Choose Emoji',
                                  style:
                                      GoogleFonts.outfit(
                                    fontWeight:
                                        FontWeight.w600,
                                    color: AppColors
                                        .textPrimary,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons
                                    .emoji_emotions_outlined,
                                color:
                                    AppColors.primaryPurple,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap:
                            _showPrimaryImageSourcePicker,
                        borderRadius:
                            BorderRadius.circular(14),
                        child: Container(
                          height: 58,
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors
                                .primaryPurple
                                .withAlpha(12),
                            borderRadius:
                                BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors
                                  .primaryPurple
                                  .withAlpha(60),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons
                                    .add_a_photo_outlined,
                                color:
                                    AppColors.primaryPurple,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Add Photo',
                                style:
                                    GoogleFonts.outfit(
                                  fontWeight:
                                      FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors
                                      .primaryPurple,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  child: Text(
                    'Upload a photo or choose an emoji to represent your asset.',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ---------------------------------------------------------------
              // NAME
              // ---------------------------------------------------------------

              CustomTextField(
                controller: _nameController,
                hintText:
                    'e.g. My Laptop, Toyota Camry',
                labelText: 'Asset Name *',
                prefixIcon:
                    Icons.drive_file_rename_outline_rounded,
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Name is required';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              // ---------------------------------------------------------------
              // CATEGORY
              // ---------------------------------------------------------------

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Category',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  TextButton.icon(
                    onPressed:
                        _showCreateCategoryDialog,
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 16,
                    ),
                    label: Text(
                      'Create New',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          AppColors.primaryPurple,
                      padding: EdgeInsets.zero,
                      minimumSize:
                          const Size(50, 30),
                      tapTargetSize:
                          MaterialTapTargetSize
                              .shrinkWrap,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE4DFEE),
                    width: 1.2,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedCategoryId,

                    hint: Text(
                      'Select category (optional)',
                      style: GoogleFonts.outfit(
                        color: AppColors.textMuted,
                      ),
                    ),

                    isExpanded: true,

                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color:
                          AppColors.textSecondary,
                    ),

                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color:
                          AppColors.textPrimary,
                    ),

                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'None',
                          style:
                              GoogleFonts.outfit(
                            color:
                                AppColors.textMuted,
                          ),
                        ),
                      ),

                      ..._categories.map(
                        (category) {
                          return DropdownMenuItem<
                              String?>(
                            value: category.id,
                            child: Row(
                              children: [
                                Text(
                                  category.emoji ??
                                      '📂',
                                  style:
                                      const TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(
                                    width: 8),
                                Text(category.name),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId =
                            value;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ---------------------------------------------------------------
              // LOCATION
              // ---------------------------------------------------------------

              CustomTextField(
                controller: _locationController,
                hintText:
                    'e.g. Master Bedroom, Garage',
                labelText: 'Location (Optional)',
                prefixIcon:
                    Icons.location_on_outlined,
              ),

              const SizedBox(height: 18),

              // ---------------------------------------------------------------
              // DESCRIPTION
              // ---------------------------------------------------------------

              CustomTextField(
                controller:
                    _descriptionController,
                hintText:
                    'e.g. Warranty details, purchase info...',
                labelText:
                    'Description / Notes (Optional)',
                prefixIcon: Icons.notes_rounded,
              ),

              const SizedBox(height: 24),

              // ---------------------------------------------------------------
              // CUSTOM FIELDS
              // ---------------------------------------------------------------

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Custom Fields (Optional)',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  TextButton.icon(
                    onPressed:
                        _showAddCustomFieldDialog,
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 16,
                    ),
                    label: Text(
                      'Add Field',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          AppColors.primaryPurple,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              if (_customFields.isEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          const Color(0xFFF1EEFB),
                    ),
                  ),
                  child: Text(
                    'No custom fields added yet. Add details like RAM, Color, or Model.',
                    style: GoogleFonts.outfit(
                      color:
                          AppColors.textMuted,
                      fontSize: 13,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  itemCount:
                      _customFields.length,
                  separatorBuilder:
                      (context, index) =>
                          const SizedBox(height: 8),
                  itemBuilder:
                      (context, index) {
                    final field =
                        _customFields[index];

                    return Container(
                      padding:
                          const EdgeInsets.all(12),
                      decoration:
                          BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(
                                12),
                        border: Border.all(
                          color: const Color(
                              0xFFE4DFEE),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  field['name'] ??
                                      '',
                                  style:
                                      GoogleFonts
                                          .outfit(
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                    fontSize: 12,
                                    color: AppColors
                                        .textSecondary,
                                  ),
                                ),
                                const SizedBox(
                                    height: 2),
                                Text(
                                  field['value'] ??
                                      '',
                                  style:
                                      GoogleFonts
                                          .outfit(
                                    fontWeight:
                                        FontWeight
                                            .w600,
                                    fontSize: 14,
                                    color: AppColors
                                        .textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            icon: const Icon(
                              Icons
                                  .delete_outline_rounded,
                              color:
                                  AppColors.error,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _customFields
                                    .removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // ---------------------------------------------------------------
              // DOCUMENTS
              // ---------------------------------------------------------------

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Documents & Images (Optional)',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  TextButton.icon(
                    onPressed:
                        _showDocumentPickerDialog,
                    icon: const Icon(
                      Icons.attach_file_rounded,
                      size: 16,
                    ),
                    label: Text(
                      'Add File',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          AppColors.primaryPurple,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              if (_selectedFiles.isEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          const Color(0xFFF1EEFB),
                    ),
                  ),
                  child: Text(
                    'No documents or images selected. Attach invoices, warranties, or photos.',
                    style: GoogleFonts.outfit(
                      color:
                          AppColors.textMuted,
                      fontSize: 13,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  itemCount:
                      _selectedFiles.length,
                  separatorBuilder:
                      (context, index) =>
                          const SizedBox(height: 8),
                  itemBuilder:
                      (context, index) {
                    final file =
                        _selectedFiles[index];

                    final fileName = file.path
                        .split('/')
                        .last
                        .split('\\')
                        .last;

                    final extension = fileName
                        .split('.')
                        .last
                        .toLowerCase();

                    final isImage = [
                      'jpg',
                      'jpeg',
                      'png',
                      'heic',
                    ].contains(extension);

                    return Container(
                      padding:
                          const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(
                                12),
                        border: Border.all(
                          color: const Color(
                              0xFFE4DFEE),
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius
                                    .circular(8),
                            child: isImage
                                ? Image.file(
                                    file,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 40,
                                    height: 40,
                                    color: AppColors
                                        .lightLavender,
                                    child:
                                        const Icon(
                                      Icons
                                          .insert_drive_file_rounded,
                                      color: AppColors
                                          .primaryPurple,
                                    ),
                                  ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              fileName,
                              style:
                                  GoogleFonts.outfit(
                                fontWeight:
                                    FontWeight.w600,
                                fontSize: 13,
                                color: AppColors
                                    .textPrimary,
                              ),
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          ),

                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors
                                  .textSecondary,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedFiles
                                    .removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // ---------------------------------------------------------------
              // QR CODE
              // ---------------------------------------------------------------

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        const Color(0xFFE4DFEE),
                  ),
                ),
                child: SwitchListTile(
                  value: _qrEnabled,
                  onChanged: (value) {
                    setState(() {
                      _qrEnabled = value;
                    });
                  },
                  activeThumbColor:
                      AppColors.primaryPurple,
                  activeTrackColor: AppColors
                      .primaryPurple
                      .withAlpha(120),
                  title: Text(
                    'Generate QR Code',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color:
                          AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Create a unique QR code for easy scanning and asset identification.',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color:
                          AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ---------------------------------------------------------------
              // SAVE
              // ---------------------------------------------------------------

              GradientButton(
                text: 'Save Asset',
                isLoading: _isLoading,
                onPressed: _saveAsset,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}