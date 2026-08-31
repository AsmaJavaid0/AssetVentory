import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// A reusable bottom sheet widget for creating a new category with a full
/// emoji picker embedded inline — avoids nested modals that cause the
/// `_dependants.isEmpty` assertion error.
class CreateCategorySheet extends StatefulWidget {
  final Future<void> Function(String name, String emoji) onCreateCategory;

  const CreateCategorySheet({super.key, required this.onCreateCategory});

  static Future<bool?> show(
    BuildContext context, {
    required Future<void> Function(String name, String emoji) onCreateCategory,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CreateCategorySheet(onCreateCategory: onCreateCategory),
    );
  }

  @override
  State<CreateCategorySheet> createState() => _CreateCategorySheetState();
}

class _CreateCategorySheetState extends State<CreateCategorySheet> {
  final _nameController = TextEditingController();
  String _selectedEmoji = '📂';
  bool _showEmojiPicker = false;
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _creating) return;

    setState(() => _creating = true);
    try {
      await widget.onCreateCategory(name, _selectedEmoji);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error creating category: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to create category. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _creating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Create New Category',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _nameController,
                autofocus: true,
                style: GoogleFonts.outfit(fontSize: 15),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleCreate(),
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. Electronics, Tools, Books',
                  prefixIcon: GestureDetector(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _showEmojiPicker = !_showEmojiPicker);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        _selectedEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showEmojiPicker
                          ? Icons.keyboard_rounded
                          : Icons.emoji_emotions_outlined,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: _showEmojiPicker ? 'Show keyboard' : 'Pick emoji',
                    onPressed: () {
                      if (_showEmojiPicker) {
                        setState(() => _showEmojiPicker = false);
                        FocusScope.of(context).requestFocus(FocusNode());
                      } else {
                        FocusScope.of(context).unfocus();
                        setState(() => _showEmojiPicker = true);
                      }
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primaryPurple.withAlpha(120),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _creating ? null : _handleCreate,
                  child: _creating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Create Category',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
            if (_showEmojiPicker)
              SizedBox(
                height: 280,
                child: emoji_picker.EmojiPicker(
                  onEmojiSelected: (_, emoji) {
                    setState(() => _selectedEmoji = emoji.emoji);
                  },
                  config: const emoji_picker.Config(
                    height: 280,
                    checkPlatformCompatibility: true,
                    emojiViewConfig: emoji_picker.EmojiViewConfig(
                      columns: 8,
                      emojiSizeMax: 28,
                      verticalSpacing: 0,
                      horizontalSpacing: 0,
                      recentsLimit: 28,
                      noRecents: Text(
                        'No Recents',
                        style: TextStyle(fontSize: 16, color: Colors.black26),
                      ),
                      buttonMode: emoji_picker.ButtonMode.MATERIAL,
                    ),
                    categoryViewConfig: emoji_picker.CategoryViewConfig(
                      initCategory: emoji_picker.Category.OBJECTS,
                    ),
                    bottomActionBarConfig:
                        emoji_picker.BottomActionBarConfig(enabled: false),
                    searchViewConfig: emoji_picker.SearchViewConfig(
                      buttonIconColor: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
