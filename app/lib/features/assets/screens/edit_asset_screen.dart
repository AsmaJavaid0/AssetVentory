import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/widgets/custom_text_field.dart';

import '../models/local_asset.dart';
import '../models/local_category.dart';

class EditAssetScreen extends StatefulWidget {
  final LocalAsset asset;

  const EditAssetScreen({
    super.key,
    required this.asset,
  });

  static Future<void> navigateTo(
    BuildContext context,
    LocalAsset asset,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditAssetScreen(
          asset: asset,
        ),
      ),
    );
  }

  @override
  State<EditAssetScreen> createState() =>
      _EditAssetScreenState();
}

class _EditAssetScreenState
    extends State<EditAssetScreen> {
  final _formKey =
      GlobalKey<FormState>();

  final _assetRepository =
      serviceLocator.assetRepository;

  final _categoryRepository =
      serviceLocator.categoryRepository;

  late final TextEditingController
      _nameController;

  late final TextEditingController
      _locationController;

  late final TextEditingController
      _descriptionController;

  late String _emoji;

  String? _categoryId;

  late bool _qrEnabled;

  late Map<String, String>
      _customFields;

  List<LocalCategory> _categories = [];

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final asset = widget.asset;

    _nameController =
        TextEditingController(
      text: asset.name,
    );

    _locationController =
        TextEditingController(
      text: asset.location ?? '',
    );

    _descriptionController =
        TextEditingController(
      text: asset.description ?? '',
    );

    _emoji = asset.emoji ?? '📦';

    _categoryId = asset.categoryId;

    _qrEnabled = asset.qrEnabled;

    _customFields =
        Map<String, String>.from(
      asset.customFields,
    );

    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories =
          await _categoryRepository
              .getCategories('local_user');

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'Error loading categories: $e',
      );

      if (!mounted) return;

      setState(() {
        _categories = [];
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

  Future<void> _save() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final updated =
          widget.asset.copyWith(
        name: _nameController.text.trim(),
        categoryId: _categoryId,
        emoji: _emoji,
        location: _locationController
                .text
                .trim()
                .isEmpty
            ? null
            : _locationController.text
                .trim(),
        description: _descriptionController
                .text
                .trim()
                .isEmpty
            ? null
            : _descriptionController.text
                .trim(),
        qrEnabled: _qrEnabled,
        customFields: _customFields,
        updatedAt: DateTime.now(),
      );

      await _assetRepository
          .updateAsset(updated);

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e, stackTrace) {
      debugPrint(
        'Error updating asset: $e',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to update asset.',
          ),
        ),
      );
    }
  }

  void _chooseEmoji() {
    const emojis = [
      '📦',
      '💻',
      '📱',
      '🚗',
      '🏠',
      '🔧',
      '📚',
      '👕',
      '🎮',
      '🎨',
      '🛠️',
      '💍',
    ];

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            padding:
                const EdgeInsets.all(24),
            children: emojis.map((emoji) {
              return InkWell(
                onTap: () {
                  setState(() {
                    _emoji = emoji;
                  });

                  Navigator.pop(
                    sheetContext,
                  );
                },
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(
                      fontSize: 32,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          AppColors.scaffoldBg,

      appBar: AppBar(
        title: Text(
          'Edit Asset',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _chooseEmoji,
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: AppColors
                          .primaryPurple
                          .withAlpha(18),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _emoji,
                        style:
                            const TextStyle(
                          fontSize: 42,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              CustomTextField(
                controller:
                    _nameController,
                labelText:
                    'Asset Name *',
                hintText:
                    'e.g. My Laptop',
                prefixIcon:
                    Icons.inventory_2_outlined,
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Name is required';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              Text(
                'Category',
                style: GoogleFonts.outfit(
                  fontWeight:
                      FontWeight.w600,
                  color:
                      AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 7),

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
                    color:
                        const Color(
                      0xFFE4DFEE,
                    ),
                  ),
                ),
                child:
                    DropdownButtonHideUnderline(
                  child:
                      DropdownButton<String?>(
                    value: _categoryId,
                    isExpanded: true,
                    hint: const Text(
                      'Select category',
                    ),
                    items: [
                      const DropdownMenuItem<
                          String?>(
                        value: null,
                        child:
                            Text('Uncategorized'),
                      ),
                      ..._categories.map(
                        (category) {
                          return DropdownMenuItem<
                              String?>(
                            value:
                                category.id,
                            child: Row(
                              children: [
                                Text(
                                  category
                                          .emoji ??
                                      '📂',
                                ),
                                const SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  category.name,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _categoryId =
                            value;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 18),

              CustomTextField(
                controller:
                    _locationController,
                labelText:
                    'Location',
                hintText:
                    'e.g. Bedroom, Garage',
                prefixIcon:
                    Icons.location_on_outlined,
              ),

              const SizedBox(height: 18),

              CustomTextField(
                controller:
                    _descriptionController,
                labelText:
                    'Description / Notes',
                hintText:
                    'Additional information',
                prefixIcon:
                    Icons.notes_rounded,
              ),

              const SizedBox(height: 20),

              SwitchListTile(
                value: _qrEnabled,
                onChanged: (value) {
                  setState(() {
                    _qrEnabled = value;
                  });
                },
                activeThumbColor:
                    AppColors.primaryPurple,
                title: Text(
                  'Generate QR Code',
                  style: GoogleFonts.outfit(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Enable QR identification for this asset.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color:
                        AppColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _saving ? null : _save,
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        AppColors
                            .primaryPurple,
                    foregroundColor:
                        Colors.white,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : Text(
                          'Save Changes',
                          style:
                              GoogleFonts.outfit(
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}