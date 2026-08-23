import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../models/asset_model.dart';
import '../models/category_model.dart';
import '../models/document_model.dart';
import '../../auth/services/firestore_service.dart';
import '../services/storage_service.dart';

class AddAssetScreen extends StatefulWidget {
  final String? initialCategoryId;

  const AddAssetScreen({super.key, this.initialCategoryId});

  static Future<void> navigateTo(BuildContext context, {String? categoryId}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddAssetScreen(initialCategoryId: categoryId),
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

  String _selectedEmoji = '📦';
  String? _selectedCategoryId; // Nullable if no category
  bool _qrEnabled = false;
  bool _isLoading = false;

  final List<Map<String, String>> _customFields = [];
  final List<File> _selectedFiles = [];

  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  // Cached once instead of being called inline inside build(), where every
  // setState (picking an emoji, adding a custom field, toggling QR, etc.)
  // would otherwise create a brand-new Stream and force this listener to
  // reconnect from scratch on every keystroke/tap.
  late final Stream<List<CategoryModel>> _categoriesStream;

  // ignore: unused_field
  final List<String> _emojis = [
    '📦',
    '💻',
    '📱',
    '🚗',
    '🏠',
    '📺',
    '⌚',
    '📄',
    '💎',
    '🎮',
    '🛠️',
    '🚲',
    '🎸',
    '✈️',
    '💼',
    '👜',
    '📷',
    '🎧',
    '🔋',
    '🔑',
    '🎨',
    '👟',
    '💍',
    '📚',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _categoriesStream = _firestoreService.streamUserCategories(uid);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Pick Image from Gallery or Camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedFiles.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e', isError: true);
    }
  }

  // Pick Document File
  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'],
      );
      if (file != null && file.path != null) {
        setState(() {
          _selectedFiles.add(File(file.path!));
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick document: $e', isError: true);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (pickerContext) => SafeArea(
        child: SizedBox(
          height: 360,
          child: EmojiPicker(
            onEmojiSelected: (_, emoji) {
              setState(() => _selectedEmoji = emoji.emoji);
              Navigator.of(pickerContext).pop();
            },
          ),
        ),
      ),
    );
  }

  // Add Custom Field Dialog
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
                final val = valCtrl.text.trim();
                if (name.isNotEmpty && val.isNotEmpty) {
                  setState(() {
                    _customFields.add({'name': name, 'value': val});
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

  // Create Category Inline Dialog
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
                        items:
                            [
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
                                ]
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => catEmoji = val);
                          }
                        },
                      ),
                    ],
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
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final user = FirebaseAuth.instance.currentUser;
                    if (name.isNotEmpty && user != null) {
                      final newCat = CategoryModel(
                        id: '',
                        ownerId: user.uid,
                        name: name,
                        emoji: catEmoji,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      final catId = await _firestoreService.addCategory(newCat);
                      setState(() {
                        _selectedCategoryId = catId;
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
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

  // Upload document dialog picker
  void _showDocumentPickerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
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
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
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
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
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
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
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

  // Save Asset Form submission
  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. Build map of custom fields
      final Map<String, String> fieldsMap = {};
      for (var f in _customFields) {
        if (f['name'] != null && f['value'] != null) {
          fieldsMap[f['name']!] = f['value']!;
        }
      }

      final now = DateTime.now();
      final newAsset = AssetModel(
        id: '',
        ownerId: user.uid,
        name: _nameController.text.trim(),
        emoji: _selectedEmoji,
        categoryId: _selectedCategoryId,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        qrEnabled: _qrEnabled,
        customFields: fieldsMap,
        createdAt: now,
        updatedAt: now,
      );

      // 2. Add Asset to Firestore
      final assetId = await _firestoreService.addAsset(newAsset);

      // The asset is safely created at this point, so return to the list
      // immediately. Previously the screen stayed in its loading state until
      // every selected attachment had uploaded, which can take a long time on
      // a slow connection.
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 3. Upload documents (if any) and write metadata to Firestore in the
      // background. The new asset is already visible in the previous screen.
      for (var file in _selectedFiles) {
        final rawName = file.path.split('/').last.split('\\').last;
        final extension = rawName.split('.').last.toLowerCase();

        try {
          // Upload to Storage
          final uploadResult = await _storageService.uploadAssetDocument(
            userId: user.uid,
            assetId: assetId,
            filePath: file.path,
            fileName: rawName,
          );

          // Save metadata
          final docModel = DocumentModel(
            id: '',
            ownerId: user.uid,
            assetId: assetId,
            fileUrl: uploadResult['url'] ?? '',
            storagePath: uploadResult['path'] ?? '',
            fileName: rawName,
            fileType: extension,
            createdAt: now,
            updatedAt: now,
          );
          await _firestoreService.addDocument(docModel);
        } catch (e) {
          _showSnackBar('Failed to upload file $rawName: $e', isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Failed to create asset: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji Picker Section
                    Text(
                      'Asset Emoji',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _showEmojiPicker,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 58,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE4DFEE)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _selectedEmoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Choose an emoji',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.emoji_emotions_outlined,
                              color: AppColors.primaryPurple,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Asset Name Field
                    CustomTextField(
                      controller: _nameController,
                      hintText: 'e.g. My Laptop, Toyota Camry',
                      labelText: 'Asset Name *',
                      prefixIcon: Icons.drive_file_rename_outline_rounded,
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 18),

                    // Category Selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          onPressed: _showCreateCategoryDialog,
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
                            foregroundColor: AppColors.primaryPurple,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    StreamBuilder<List<CategoryModel>>(
                      stream: _categoriesStream,
                      builder: (context, snapshot) {
                        final categories = snapshot.data ?? [];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
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
                                color: AppColors.textSecondary,
                              ),
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    'None',
                                    style: GoogleFonts.outfit(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                ...categories.map((cat) {
                                  return DropdownMenuItem<String?>(
                                    value: cat.id,
                                    child: Row(
                                      children: [
                                        Text(
                                          cat.emoji ?? '📂',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(cat.name),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() => _selectedCategoryId = val);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),

                    // Location Field
                    CustomTextField(
                      controller: _locationController,
                      hintText: 'e.g. Master Bedroom, Garage',
                      labelText: 'Location (Optional)',
                      prefixIcon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 18),

                    // Description Field
                    CustomTextField(
                      controller: _descriptionController,
                      hintText: 'e.g. Warranty details, purchase info...',
                      labelText: 'Description / Notes (Optional)',
                      prefixIcon: Icons.notes_rounded,
                    ),
                    const SizedBox(height: 24),

                    // Custom Fields Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          onPressed: _showAddCustomFieldDialog,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(
                            'Add Field',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryPurple,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_customFields.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1EEFB)),
                        ),
                        child: Text(
                          'No custom fields added yet. Add details like RAM, Color, or Model.',
                          style: GoogleFonts.outfit(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _customFields.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final f = _customFields[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE4DFEE),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        f['name'] ?? '',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        f['value'] ?? '',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.error,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _customFields.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),

                    // Documents Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          onPressed: _showDocumentPickerDialog,
                          icon: const Icon(Icons.attach_file_rounded, size: 16),
                          label: Text(
                            'Add File',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryPurple,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_selectedFiles.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1EEFB)),
                        ),
                        child: Text(
                          'No documents or images selected. Attach invoices, warranties, or photos.',
                          style: GoogleFonts.outfit(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _selectedFiles.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final file = _selectedFiles[index];
                          final fileName = file.path
                              .split('/')
                              .last
                              .split('\\')
                              .last;
                          final isImage = [
                            'jpg',
                            'jpeg',
                            'png',
                            'heic',
                          ].contains(fileName.split('.').last.toLowerCase());

                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE4DFEE),
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
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
                                          color: AppColors.lightLavender,
                                          child: const Icon(
                                            Icons.insert_drive_file_rounded,
                                            color: AppColors.primaryPurple,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    fileName,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedFiles.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),

                    // QR Code Switch
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE4DFEE)),
                      ),
                      child: SwitchListTile(
                        value: _qrEnabled,
                        onChanged: (val) {
                          setState(() => _qrEnabled = val);
                        },
                        activeThumbColor: AppColors.primaryPurple,
                        activeTrackColor: AppColors.primaryPurple.withAlpha(
                          120,
                        ),
                        title: Text(
                          'Generate QR Code',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Create a unique QR code for easy scanning and asset identification.',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Save Button
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
