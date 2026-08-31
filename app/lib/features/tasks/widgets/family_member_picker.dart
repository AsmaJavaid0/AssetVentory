import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../family/models/family_member_model.dart';

class FamilyMemberPickerSheet extends StatefulWidget {
  final String familyId;
  final String currentUserId;
  final String? selectedUserId;

  const FamilyMemberPickerSheet({
    super.key,
    required this.familyId,
    required this.currentUserId,
    this.selectedUserId,
  });

  static Future<FamilyMemberModel?> show(
    BuildContext context, {
    required String familyId,
    required String currentUserId,
    String? selectedUserId,
  }) {
    return showModalBottomSheet<FamilyMemberModel?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FamilyMemberPickerSheet(
        familyId: familyId,
        currentUserId: currentUserId,
        selectedUserId: selectedUserId,
      ),
    );
  }

  @override
  State<FamilyMemberPickerSheet> createState() => _FamilyMemberPickerSheetState();
}

class _FamilyMemberPickerSheetState extends State<FamilyMemberPickerSheet> {
  final _familyRepository = serviceLocator.familyRepository;
  List<FamilyMemberModel> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await _familyRepository.getFamilyMembers(widget.familyId);
      if (mounted) {
        setState(() {
          _members = members;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _members = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  'Assign Task To',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      ..._members.map((member) {
                        final isSelf = member.userId == widget.currentUserId;
                        final isSelected = widget.selectedUserId == member.userId ||
                            (widget.selectedUserId == null && isSelf);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            tileColor: isSelected
                                ? AppColors.primaryPurple.withAlpha(20)
                                : Colors.white,
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryPurple,
                              child: Text(
                                member.name.isNotEmpty
                                    ? member.name[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              isSelf ? '${member.name} (Myself)' : member.name,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              member.role.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryPurple)
                                : null,
                            onTap: () => Navigator.pop(context, member),
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
