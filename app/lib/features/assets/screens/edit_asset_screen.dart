import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

/// Screen for editing an existing asset. Mirrors AddAssetScreen's layout and
/// validation so the two forms feel identical, but pre-fills from [asset]
/// and writes back via [FirestoreService.updateAsset] instead of creating
/// a new document.
class EditAssetScreen extends StatefulWidget {
  final AssetModel asset;

  const EditAssetScreen({super.key, required this.asset});

  static Future<void> navigateTo(BuildContext context, AssetModel asset) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => EditAssetScreen(asset: asset)),
    );
  }

  @override
  State<EditAssetScreen> createState() => _EditAssetScreenState();
}

class _EditAssetScreenState extends State<EditAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;

  late String _selectedEmoji;
  String? _existingImageUrl;
  File? _newPrimaryImage;
  String? _selectedCategoryId;
  late bool _qrEnabled;
  bool _isSaving = false;

  // Custom fields are edited as a mutable list of {name, value} pairs,
  // seeded from the asset's existing map.
  late final List<Map<String, String>> _customFields;

  // Newly picked files staged for upload on save.
  final List<File> _newFiles = [];
  // Existing documents the user has marked for removal (deleted on save).
  final Set<String> _pendingDeleteDocIds = {};

  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  late final Stream<List<CategoryModel>> _categoriesStream;
  late final Stream<List<DocumentModel>> _documentsStream;

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    _nameController = TextEditingController(text: asset.name);
    _locationController = TextEditingController(text: asset.location ?? '');
    _descriptionController = TextEditingController(text: asset.description ?? '');
    _selectedEmoji = asset.emoji ?? '📦';
    _existingImageUrl = asset.imageUrl;
    _selectedCategoryId = asset.categoryId;
    _qrEnabled = asset.qrEnabled;
    _customFields = asset.customFields.entries
        .map((e) => {'name': e.key, 'value': e.value})
        .toList();
    _categoriesStream = _firestoreService.streamUserCategories(asset.ownerId);
    _documentsStream = _firestoreService.streamAssetDocuments(asset.id);
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
      final picked = await _imagePicker.pickImage(source: source, imageQuality: 85, maxWidth: 1024);
      if (picked != null) {
        setState(() {
          _newPrimaryImage = File(picked.path);
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e', isError: true);
    }
  }

  void _showPrimaryImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Asset Photo',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primaryPurple.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryPurple),
                ),
                title: Text('Take Photo', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pickPrimaryImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primaryBlue.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primaryBlue),
                ),
                title: Text('Choose from Gallery', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
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

  void _showEmojiPicker() {
    final emojis = [
      '📦', '💻', '📱', '🚗', '🏠', '📺', '⌚', '📄', '💎', '🎮',
      '🛠️', '🚲', '🎸', '✈️', '💼', '👜', '📷', '🎧', '🔋', '🔑',
      '🎨', '👟', '💍', '📚'
    ];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: emojis.length,
            itemBuilder: (context, index) {
              final em = emojis[index];
              return InkWell(
                onTap: () {
                  setState(() => _selectedEmoji = em);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: em == _selectedEmoji ? AppColors.primaryPurple.withAlpha(25) : AppColors.scaffoldBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: em == _selectedEmoji ? AppColors.primaryPurple : const Color(0xFFE4DFEE),
                    ),
                  ),
                  child: Center(child: Text(em, style: const TextStyle(fontSize: 24))),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source, imageQuality: 85);
      if (pickedFile != null) {
        setState(() => _newFiles.add(File(pickedFile.path)));
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e', isError: true);
    }
  }

  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'],
      );
      if (file != null && file.path != null) {
        setState(() => _newFiles.add(File(file.path!)));
      }
    } catch (e) {
      _showSnackBar('Failed to pick document: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showAddCustomFieldDialog() {
    final nameCtrl = TextEditingController();
    final valCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Add Custom Field',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(controller: nameCtrl, hintText: 'e.g. RAM, Brand, Warranty Year', labelText: 'Field Name'),
              const SizedBox(height: 14),
              CustomTextField(controller: valCtrl, hintText: 'e.g. 16 GB, Apple, 2 Years', labelText: 'Field Value'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final val = valCtrl.text.trim();
                if (name.isNotEmpty && val.isNotEmpty) {
                  setState(() => _customFields.add({'name': name, 'value': val}));
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Add', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showCreateCategoryDialog() {
    final nameCtrl = TextEditingController();
    String catEmoji = '📂';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Create New Category',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomTextField(controller: nameCtrl, hintText: 'e.g. Tools, Books, Office', labelText: 'Category Name'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Category Emoji:',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(width: 14),
                      DropdownButton<String>(
                        value: catEmoji,
                        items: ['📂', '🛠️', '📚', '👔', '🎨', '🍳', '👟', '💍', '🎮', '🚗']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 22))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => catEmoji = val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final user = FirebaseAuth.instance.currentUser;
                    if (name.isNotEmpty && user != null) {
                      try {
                        final newCat = CategoryModel(
                          id: '',
                          ownerId: user.uid,
                          name: name,
                          emoji: catEmoji,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        final catId = await _firestoreService.addCategory(newCat);
                        if (!context.mounted) return;
                        setState(() => _selectedCategoryId = catId);
                        Navigator.pop(context);
                      } catch (e) {
                        debugPrint('Error creating category: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to create category. Please try again.'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Create', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDocumentPickerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Document',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primaryPurple.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryPurple),
                ),
                title: Text('Take Photo', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primaryBlue.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primaryBlue),
                ),
                title: Text('Choose from Gallery', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.file_present_rounded, color: Colors.orange),
                ),
                title: Text('Choose File (PDF, DOC)', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
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

  Future<void> _confirmDeleteDocument(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove document?', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently delete "${doc.fileName}" from this asset.',
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: GoogleFonts.outfit(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _pendingDeleteDocIds.add(doc.id));
      try {
        await _storageService.deleteFile(doc.storagePath);
        await _firestoreService.deleteDocument(doc.id);
      } catch (e) {
        debugPrint('Error removing document: $e');
        if (mounted) {
          setState(() => _pendingDeleteDocIds.remove(doc.id));
          _showSnackBar('Failed to remove document. Please try again.', isError: true);
        }
      }
    }
  }

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final Map<String, String> fieldsMap = {};
      for (var f in _customFields) {
        if (f['name'] != null && f['value'] != null) {
          fieldsMap[f['name']!] = f['value']!;
        }
      }

      final now = DateTime.now();

      final updatedAsset = AssetModel(
        id: widget.asset.id,
        ownerId: widget.asset.ownerId,
        name: _nameController.text.trim(),
        emoji: _selectedEmoji,
        imageUrl: _existingImageUrl,
        categoryId: _selectedCategoryId,
        location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        qrEnabled: _qrEnabled,
        customFields: fieldsMap,
        createdAt: widget.asset.createdAt,
        updatedAt: now,
      );

      // 1. Update asset in Firestore - must succeed before we navigate
      await _firestoreService.updateAsset(updatedAsset);

      // 2. Upload new cover photo in background if selected
      if (_newPrimaryImage != null) {
        _storageService
            .uploadAssetImage(
              userId: user.uid,
              assetId: widget.asset.id,
              filePath: _newPrimaryImage!.path,
            )
            .then((uploadRes) {
              final url = uploadRes['url'];
              if (url != null && url.isNotEmpty) {
                _firestoreService.updateAsset(
                  updatedAsset.copyWith(imageUrl: url),
                );
              }
            })
            .catchError((e) {
              debugPrint('Background update cover photo failed: $e');
            });
      }

      // 3. Upload any newly attached documents in background
      for (var file in _newFiles) {
        final rawName = file.path.split('/').last.split('\\').last;
        final extension = rawName.split('.').last.toLowerCase();
        _storageService
            .uploadAssetDocument(
              userId: user.uid,
              assetId: widget.asset.id,
              filePath: file.path,
              fileName: rawName,
            )
            .then((uploadResult) {
              final docModel = DocumentModel(
                id: '',
                ownerId: user.uid,
                assetId: widget.asset.id,
                fileUrl: uploadResult['url'] ?? '',
                storagePath: uploadResult['path'] ?? '',
                fileName: rawName,
                fileType: extension,
                createdAt: now,
                updatedAt: now,
              );
              _firestoreService.addDocument(docModel);
            })
            .catchError((e) {
              debugPrint('Failed to upload file $rawName: $e');
            });
      }

      if (!mounted) return;

      setState(() => _isSaving = false);

      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error updating asset: $e');
      if (!mounted) return;

      setState(() => _isSaving = false);

      _showSnackBar('Failed to save changes. Please try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _newPrimaryImage != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Asset',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20, color: AppColors.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo & Emoji Selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Asset Photo & Emoji',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                  if (hasPhoto)
                    Text('Photo active (Emoji optional)',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.primaryPurple)),
                ],
              ),
              const SizedBox(height: 8),

              if (hasPhoto) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryPurple.withAlpha(80), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _newPrimaryImage != null
                            ? Image.file(_newPrimaryImage!, width: 56, height: 56, fit: BoxFit.cover)
                            : Image.network(_existingImageUrl!, width: 56, height: 56, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Asset Photo',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Displayed instead of emoji.',
                              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Change photo',
                        icon: const Icon(Icons.edit_outlined, color: AppColors.primaryPurple, size: 20),
                        onPressed: _showPrimaryImageSourcePicker,
                      ),
                      IconButton(
                        tooltip: 'Remove photo',
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                        onPressed: () {
                          setState(() {
                            _newPrimaryImage = null;
                            _existingImageUrl = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _showEmojiPicker,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      children: [
                        Text(_selectedEmoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          'Fallback emoji: $_selectedEmoji (tap to change)',
                          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
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
                              Text(_selectedEmoji, style: const TextStyle(fontSize: 28)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('Choose Emoji',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              ),
                              const Icon(Icons.emoji_emotions_outlined, color: AppColors.primaryPurple, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _showPrimaryImageSourcePicker,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 58,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple.withAlpha(12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primaryPurple.withAlpha(60)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_a_photo_outlined, color: AppColors.primaryPurple, size: 18),
                              const SizedBox(width: 6),
                              Text('Add Photo',
                                  style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primaryPurple)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),

              // Asset Name
              CustomTextField(
                controller: _nameController,
                hintText: 'e.g. My Laptop, Toyota Camry',
                labelText: 'Asset Name *',
                prefixIcon: Icons.drive_file_rename_outline_rounded,
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 18),

              // Category
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Category',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                  TextButton.icon(
                    onPressed: _showCreateCategoryDialog,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: Text('Create New', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
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
                  // Guard against a category that was deleted elsewhere while
                  // this asset still references it.
                  final validIds = categories.map((c) => c.id).toSet();
                  final dropdownValue = validIds.contains(_selectedCategoryId) ? _selectedCategoryId : null;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4DFEE), width: 1.2),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: dropdownValue,
                        hint: Text('Select category (optional)', style: GoogleFonts.outfit(color: AppColors.textMuted)),
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                        style: GoogleFonts.outfit(fontSize: 15, color: AppColors.textPrimary),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None', style: GoogleFonts.outfit(color: AppColors.textMuted)),
                          ),
                          ...categories.map((cat) {
                            return DropdownMenuItem<String?>(
                              value: cat.id,
                              child: Row(
                                children: [
                                  Text(cat.emoji ?? '📂', style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Text(cat.name),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) => setState(() => _selectedCategoryId = val),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              // Location
              CustomTextField(
                controller: _locationController,
                hintText: 'e.g. Master Bedroom, Garage',
                labelText: 'Location (Optional)',
                prefixIcon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 18),

              // Description
              CustomTextField(
                controller: _descriptionController,
                hintText: 'e.g. Warranty details, purchase info...',
                labelText: 'Description / Notes (Optional)',
                prefixIcon: Icons.notes_rounded,
              ),
              const SizedBox(height: 24),

              // Custom Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Custom Fields (Optional)',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                  TextButton.icon(
                    onPressed: _showAddCustomFieldDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text('Add Field', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryPurple, padding: EdgeInsets.zero),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_customFields.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1EEFB)),
                  ),
                  child: Text(
                    'No custom fields added yet. Add details like RAM, Color, or Model.',
                    style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13, height: 1.3),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _customFields.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final f = _customFields[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE4DFEE)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f['name'] ?? '',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(f['value'] ?? '',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                            onPressed: () => setState(() => _customFields.removeAt(index)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),

              // Existing Documents
              Text('Documents & Photos',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              StreamBuilder<List<DocumentModel>>(
                stream: _documentsStream,
                builder: (context, snapshot) {
                  final docs = (snapshot.data ?? [])
                      .where((d) => !_pendingDeleteDocIds.contains(d.id))
                      .toList();

                  if (docs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1EEFB)),
                      ),
                      child: Text(
                        'No documents attached yet.',
                        style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13, height: 1.3),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final isImage = ['jpg', 'jpeg', 'png', 'heic'].contains(doc.fileType.toLowerCase());

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE4DFEE)),
                        ),
                        child: Row(
                          children: [
                            Icon(isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded,
                                color: AppColors.primaryPurple, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(doc.fileName,
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                              onPressed: () => _confirmDeleteDocument(doc),
                              tooltip: 'Remove document',
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),

              // Newly staged documents (not yet uploaded)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add More', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                  TextButton.icon(
                    onPressed: _showDocumentPickerDialog,
                    icon: const Icon(Icons.attach_file_rounded, size: 16),
                    label: Text('Add File', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryPurple, padding: EdgeInsets.zero),
                  ),
                ],
              ),
              if (_newFiles.isNotEmpty) ...[
                const SizedBox(height: 8),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _newFiles.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final file = _newFiles[index];
                    final fileName = file.path.split('/').last.split('\\').last;
                    final isImage = ['jpg', 'jpeg', 'png', 'heic'].contains(fileName.split('.').last.toLowerCase());

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE4DFEE)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: isImage
                                ? Image.file(file, width: 40, height: 40, fit: BoxFit.cover)
                                : Container(
                                    width: 40,
                                    height: 40,
                                    color: AppColors.lightLavender,
                                    child: const Icon(Icons.insert_drive_file_rounded, color: AppColors.primaryPurple),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(fileName,
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                            onPressed: () => setState(() => _newFiles.removeAt(index)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),

              // QR Code Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4DFEE)),
                ),
                child: SwitchListTile(
                  value: _qrEnabled,
                  onChanged: (val) => setState(() => _qrEnabled = val),
                  activeThumbColor: AppColors.primaryPurple,
                  activeTrackColor: AppColors.primaryPurple.withAlpha(120),
                  title: Text('Generate QR Code',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                  subtitle: Text(
                    'Create a unique QR code for easy scanning and asset identification.',
                    style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Save Button
              GradientButton(text: 'Save Changes', isLoading: _isSaving, onPressed: _saveAsset),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
