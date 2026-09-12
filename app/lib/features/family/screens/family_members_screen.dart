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
    final repository = serviceLocator.familyRepository;

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
        backgroundColor: AppColors.primaryPurple,
        onPressed: () => InviteMemberScreen.navigateTo(
          context,
          family: family,
          currentUser: currentUser,
        ),
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
        stream: repository.streamFamilyMembers(family.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load family members.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: AppColors.error),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            );
          }

          final members = snapshot.data ?? [];
          final owner = members.firstWhere(
            (member) => member.isOwner,
            orElse: () => FamilyMemberModel(
              id: '${family.id}_${family.ownerId}',
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            children: [
              _sectionTitle('Family Owner'),
              const SizedBox(height: 10),
              _MemberCard(
                member: owner,
                isCurrent: owner.userId == currentUser.id,
                canEdit: true,
                onEdit: () => _editName(context, owner),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionTitle('Members (${otherMembers.length})'),
                  Text(
                    'Code: ${family.inviteCode}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (otherMembers.isEmpty)
                _emptyMembersCard()
              else
                ...otherMembers.map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MemberCard(
                      member: member,
                      isCurrent: member.userId == currentUser.id,
                      // This is a viewer-local alias, so every family member
                      // can rename anyone for their own screen only.
                      canEdit: true,
                      onEdit: () => _editName(context, member),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _emptyMembersCard() {
    return Container(
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
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(
    BuildContext context,
    FamilyMemberModel member,
  ) async {
    String newName = member.familyDisplayName;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Family display name',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            controller: TextEditingController(text: newName),
            onChanged: (value) => newName = value,
            decoration: const InputDecoration(
              labelText: 'Display name',
              hintText: 'e.g. Dad, Mom, Asma Phone',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
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
                final value = newName.trim();
                if (value.isEmpty) return;
                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null || result.trim().isEmpty || !context.mounted) return;

    try {
      await serviceLocator.familyRepository.updateFamilyMemberDisplayName(
        familyId: family.id,
        userId: member.userId,
        displayName: result.trim(),
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Family name updated')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update name: $e'),
          backgroundColor: AppColors.error,
        ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            softWrap: true,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
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
                      const SizedBox(height: 3),
                      Text(
                        member.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
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
