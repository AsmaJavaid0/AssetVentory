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

  // Cached once — see AddAssetScreen for why this must not be created
  // inline inside build().
  late final Stream<List<CategoryModel>> _categoriesStream;
  late final Stream<List<DocumentModel>> _documentsStream;

  final List<String> _emojis = [
    '📦', '💻', '📱', '🚗', '🏠', '📺', '⌚', '📄', '💎', '🎮',
    '🛠️', '🚲', '🎸', '✈️', '💼', '👜', '📷', '🎧', '🔋', '🔑',
    '🎨', '👟', '💍', '📚'
  ];

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    _nameController = TextEditingController(text: asset.name);
    _locationController = TextEditingController(text: asset.location ?? '');
    _descriptionController = TextEditingController(text: asset.description ?? '');
    _selectedEmoji = asset.emoji ?? '📦';
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
                      final newCat = CategoryModel(
                        id: '',
                        ownerId: user.uid,
                        name: name,
                        emoji: catEmoji,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      final catId = await _firestoreService.addCategory(newCat);
                      setState(() => _selectedCategoryId = catId);
                      if (context.mounted) Navigator.pop(context);
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
        if (mounted) {
          setState(() => _pendingDeleteDocIds.remove(doc.id));
          _showSnackBar('Failed to remove document: $e', isError: true);
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
        categoryId: _selectedCategoryId,
        location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        qrEnabled: _qrEnabled,
        customFields: fieldsMap,
        createdAt: widget.asset.createdAt,
        updatedAt: now,
      );

      await _firestoreService.updateAsset(updatedAsset);

      // Upload any newly attached documents.
      for (var file in _newFiles) {
        final rawName = file.path.split('/').last.split('\\').last;
        final extension = rawName.split('.').last.toLowerCase();
        try {
          final uploadResult = await _storageService.uploadAssetDocument(
            userId: user.uid,
            assetId: widget.asset.id,
            filePath: file.path,
            fileName: rawName,
          );
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
          await _firestoreService.addDocument(docModel);
        } catch (e) {
          _showSnackBar('Failed to upload file $rawName: $e', isError: true);
        }
      }

      _showSnackBar('Asset updated successfully!');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Failed to update asset: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // Emoji Picker
              Text('Asset Emoji',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _emojis.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final em = _emojis[index];
                    final isSelected = em == _selectedEmoji;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedEmoji = em),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 48,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryPurple.withAlpha(20) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryPurple : const Color(0xFFE4DFEE),
                            width: isSelected ? 2 : 1.2,
                          ),
                        ),
                        child: Center(child: Text(em, style: const TextStyle(fontSize: 22))),
                      ),
                    );
                  },
                ),
              ),
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
