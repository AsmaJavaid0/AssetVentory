import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../auth/models/user_model.dart';
import '../models/family_model.dart';
import '../models/family_member_model.dart';
import 'invite_member_screen.dart';

class FamilyMembersScreen extends StatelessWidget {
  final FamilyModel family;
  final UserModel currentUser;

  const FamilyMembersScreen({
    super.key,
    required this.family,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final familyRepository = serviceLocator.familyRepository;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Family Members',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              color: AppColors.primaryPurple,
            ),
            tooltip: 'Invite Member',
            onPressed: () => InviteMemberScreen.navigateTo(
              context,
              family: family,
              currentUser: currentUser,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'family_members_fab',
        onPressed: () => InviteMemberScreen.navigateTo(
          context,
          family: family,
          currentUser: currentUser,
        ),
        backgroundColor: AppColors.primaryPurple,
        elevation: 4,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: Text(
          'Invite Member',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: StreamBuilder<List<FamilyMemberModel>>(
        stream: familyRepository.streamFamilyMembers(family.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            );
          }

          final members = snapshot.data ?? [];
          final owner = members.firstWhere(
            (m) => m.isOwner,
            orElse: () => FamilyMemberModel(
              id: 'owner',
              familyId: family.id,
              userId: family.ownerId,
              name: 'Family Owner',
              displayName: 'Family Owner',
              email: '',
              role: 'owner',
              joinedAt: family.createdAt,
            ),
          );
          final otherMembers = members.where((m) => !m.isOwner).toList();
          final canEditAll = owner.userId == currentUser.id;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              Text(
                'Family Owner',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              _MemberCard(
                member: owner,
                isCurrent: owner.userId == currentUser.id,
                canEdit: canEditAll || owner.userId == currentUser.id,
                onEdit: () => _showDisplayNameDialog(context, owner),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Members (${otherMembers.length})',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Code: ${family.inviteCode}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (otherMembers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.lightLavenderBorder),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.people_outline_rounded,
                        size: 36,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No other family members yet',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Invite your family members using their email or share the invite code ${family.inviteCode}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...otherMembers.map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MemberCard(
                      member: member,
                      isCurrent: member.userId == currentUser.id,
                      canEdit: canEditAll || member.userId == currentUser.id,
                      onEdit: () => _showDisplayNameDialog(context, member),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDisplayNameDialog(
    BuildContext context,
    FamilyMemberModel member,
  ) async {
    final controller = TextEditingController(text: member.familyDisplayName);

    final displayName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Family display name',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This is the name your family will see. Your account name stays unchanged.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display name',
                hintText: 'e.g. Asma - Phone, Dad, Mom',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
            ),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (displayName == null || displayName.isEmpty || !context.mounted) return;

    final repository = serviceLocator.familyRepository;
    try {
      await repository.updateFamilyMemberDisplayName(
        familyId: family.id,
        userId: member.userId,
        displayName: displayName,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Family name updated')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update name: $e')),
      );
    }
  }
}

class _MemberCard extends StatelessWidget {
  final FamilyMemberModel member;
  final bool isCurrent;
  final bool canEdit;
  final VoidCallback? onEdit;

  const _MemberCard({
    required this.member,
    this.isCurrent = false,
    this.canEdit = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = member.familyDisplayName;
    final initial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : member.email.isNotEmpty
            ? member.email[0].toUpperCase()
            : 'U';

    return Container(
      constraints: const BoxConstraints(minHeight: 124),
      padding: const EdgeInsets.fromLTRB(16, 15, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent
              ? AppColors.primaryPurple.withAlpha(80)
              : AppColors.lightLavenderBorder,
          width: isCurrent ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: member.isOwner
                    ? Colors.amber.shade700
                    : AppColors.primaryPurple,
                backgroundImage: member.photoUrl.isNotEmpty
                    ? NetworkImage(member.photoUrl)
                    : null,
                child: member.photoUrl.isEmpty
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              softWrap: true,
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              margin: const EdgeInsets.only(left: 6, top: 1),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'You',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryPurple,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (member.email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          member.email,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (canEdit)
                IconButton(
                  tooltip: 'Edit family name',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 19,
                    color: AppColors.primaryPurple,
                  ),
                  onPressed: onEdit,
                ),
              if (canEdit) const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: member.isOwner
                      ? Colors.amber.withAlpha(40)
                      : AppColors.lightLavender,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  member.isOwner ? 'Owner' : member.role.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: member.isOwner
                        ? Colors.amber.shade900
                        : AppColors.primaryPurple,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
