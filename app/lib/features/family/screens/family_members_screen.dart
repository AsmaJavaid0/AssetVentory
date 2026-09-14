import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../auth/models/user_model.dart';
import '../models/family_model.dart';
import '../models/family_member_model.dart';
import 'invite_member_screen.dart';

class FamilyMembersScreen extends StatefulWidget {
  final FamilyModel family;
  final UserModel currentUser;

  const FamilyMembersScreen({super.key, required this.family, required this.currentUser});

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  final Map<String, String> _nameOverrides = {};
  final Map<String, UserModel> _cachedUsers = {};
  UserModel? _ownerUser;

  @override
  void initState() {
    super.initState();
    _loadOwnerUser();
  }

  Future<void> _loadOwnerUser() async {
    if (widget.family.ownerId.isEmpty) return;
    if (widget.family.ownerId == widget.currentUser.id) {
      if (mounted) setState(() => _ownerUser = widget.currentUser);
      return;
    }
    try {
      final res = await serviceLocator.firestoreService.getUser(widget.family.ownerId);
      final user = res.orNull;
      if (user != null && mounted) {
        setState(() {
          _ownerUser = user;
          _cachedUsers[widget.family.ownerId] = user;
        });
      }
    } catch (_) {}
  }

  void _ensureUserProfile(String userId) {
    if (userId.isEmpty || _cachedUsers.containsKey(userId)) return;
    if (userId == widget.currentUser.id) {
      _cachedUsers[userId] = widget.currentUser;
      return;
    }
    serviceLocator.firestoreService.getUser(userId).then((res) {
      final user = res.orNull;
      if (user != null && mounted) {
        setState(() {
          _cachedUsers[userId] = user;
        });
      }
    }).catchError((_) {});
  }

  String _defaultMemberName(FamilyMemberModel member) {
    if (_nameOverrides.containsKey(member.userId)) {
      return _nameOverrides[member.userId]!;
    }
    final savedPref = serviceLocator.familyRepository.getFamilyMemberDisplayName(
      familyId: widget.family.id,
      userId: member.userId,
      fallback: '',
    );
    if (savedPref.isNotEmpty) return savedPref;

    if (member.displayName.trim().isNotEmpty && member.displayName.trim() != member.email.trim()) {
      return member.displayName.trim();
    }
    final cached = _cachedUsers[member.userId] ?? (member.userId == widget.currentUser.id ? widget.currentUser : null);
    if (cached != null && cached.name.trim().isNotEmpty) {
      return cached.name.trim();
    }
    if (member.name.trim().isNotEmpty && member.name.trim() != member.email.trim()) {
      return member.name.trim();
    }
    if (member.emailBasedName.isNotEmpty) {
      return member.emailBasedName;
    }
    return member.isOwner ? 'Family Owner' : 'Member';
  }

  @override
  Widget build(BuildContext context) {
    final repository = serviceLocator.familyRepository;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Family Members', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryPurple), onPressed: () => InviteMemberScreen.navigateTo(context, family: widget.family, currentUser: widget.currentUser))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'family_members_fab', backgroundColor: AppColors.primaryPurple,
        onPressed: () => InviteMemberScreen.navigateTo(context, family: widget.family, currentUser: widget.currentUser),
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: Text('Invite Member', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<List<FamilyMemberModel>>(
        stream: repository.streamFamilyMembers(widget.family.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load family members.\n${snapshot.error}', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: AppColors.error))));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple));

          final members = snapshot.data ?? [];

          // Preload profiles for members if needed
          for (final m in members) {
            if (m.userId.isNotEmpty) _ensureUserProfile(m.userId);
          }
          if (widget.family.ownerId.isNotEmpty) {
            _ensureUserProfile(widget.family.ownerId);
          }

          // Identify owner in members list
          FamilyMemberModel? ownerMember;
          try {
            ownerMember = members.firstWhere((m) => m.userId == widget.family.ownerId || m.isOwner);
          } catch (_) {
            ownerMember = null;
          }

          final ownerUserId = widget.family.ownerId.isNotEmpty
              ? widget.family.ownerId
              : (ownerMember?.userId ?? '');

          final ownerCached = _ownerUser ?? _cachedUsers[ownerUserId];

          final ownerRealName = (ownerCached?.name.trim().isNotEmpty == true)
              ? ownerCached!.name.trim()
              : (ownerUserId == widget.currentUser.id
                  ? widget.currentUser.name.trim()
                  : (ownerMember?.name.trim().isNotEmpty == true
                      ? ownerMember!.name.trim()
                      : ''));

          final ownerEmail = (ownerCached?.email.trim().isNotEmpty == true)
              ? ownerCached!.email.trim()
              : (ownerUserId == widget.currentUser.id
                  ? widget.currentUser.email.trim()
                  : (ownerMember?.email ?? ''));

          final owner = FamilyMemberModel(
            id: ownerMember?.id ?? '${widget.family.id}_$ownerUserId',
            familyId: widget.family.id,
            userId: ownerUserId,
            name: ownerRealName.isNotEmpty
                ? ownerRealName
                : (ownerMember?.name.isNotEmpty == true ? ownerMember!.name : 'Family Owner'),
            displayName: ownerMember?.displayName.trim().isNotEmpty == true
                ? ownerMember!.displayName.trim()
                : ownerRealName,
            email: ownerEmail,
            photoUrl: ownerMember?.photoUrl.isNotEmpty == true
                ? ownerMember!.photoUrl
                : (ownerCached?.photoUrl ?? ''),
            role: 'owner',
            joinedAt: ownerMember?.joinedAt ?? widget.family.createdAt,
          );

          // Other members excludes owner
          final otherMembers = members.where((m) => !m.isOwner && m.userId != widget.family.ownerId).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            children: [
              Text('Family Owner', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryPurple)),
              const SizedBox(height: 6),
              _MemberCard(
                member: owner,
                isCurrent: owner.userId == widget.currentUser.id,
                displayNameOverride: _nameOverrides[owner.userId],
                cachedUser: ownerCached,
                onEdit: () => _editName(context, owner),
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _sectionTitle('Members (${otherMembers.length})'),
                Text('Code: ${widget.family.inviteCode}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryPurple)),
              ]),
              const SizedBox(height: 10),
              if (otherMembers.isEmpty) _emptyMembersCard()
              else ...otherMembers.map((member) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MemberCard(
                  member: member,
                  isCurrent: member.userId == widget.currentUser.id,
                  displayNameOverride: _nameOverrides[member.userId],
                  cachedUser: _cachedUsers[member.userId],
                  onEdit: () => _editName(context, member),
                ),
              )),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary));

  Widget _emptyMembersCard() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.lightLavenderBorder)),
    child: Column(children: [const Icon(Icons.people_outline_rounded, size: 36, color: AppColors.textMuted), const SizedBox(height: 10), Text('No other family members yet', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary))]),
  );

  Future<void> _editName(BuildContext context, FamilyMemberModel member) async {
    String newName = _nameOverrides[member.userId] ?? _defaultMemberName(member);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit family name', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: TextField(
          autofocus: true, maxLength: 40, textCapitalization: TextCapitalization.words,
          controller: TextEditingController(text: newName), onChanged: (value) => newName = value,
          decoration: InputDecoration(labelText: 'Name', hintText: 'e.g. Dad, Mom, Sister', prefixIcon: const Icon(Icons.badge_outlined),
            helperText: member.email.isNotEmpty ? 'Account: ${member.email}' : null),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.primaryPurple), onPressed: () { final value = newName.trim(); if (value.isNotEmpty) Navigator.pop(dialogContext, value); }, child: const Text('Save')),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty || !context.mounted) return;
    try {
      await serviceLocator.familyRepository.updateFamilyMemberDisplayName(familyId: widget.family.id, userId: member.userId, displayName: result.trim());
      if (!context.mounted) return;
      setState(() => _nameOverrides[member.userId] = result.trim());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Family name updated')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update name: $e'), backgroundColor: AppColors.error));
    }
  }
}

class _MemberCard extends StatelessWidget {
  final FamilyMemberModel member;
  final bool isCurrent;
  final String? displayNameOverride;
  final UserModel? cachedUser;
  final VoidCallback? onEdit;

  const _MemberCard({
    required this.member,
    this.isCurrent = false,
    this.displayNameOverride,
    this.cachedUser,
    this.onEdit,
  });

  String _resolveName() {
    if (displayNameOverride?.trim().isNotEmpty == true) {
      return displayNameOverride!.trim();
    }
    final savedPref = serviceLocator.familyRepository.getFamilyMemberDisplayName(
      familyId: member.familyId,
      userId: member.userId,
      fallback: '',
    );
    if (savedPref.isNotEmpty) return savedPref;

    if (member.displayName.trim().isNotEmpty && member.displayName.trim() != member.email.trim()) {
      return member.displayName.trim();
    }
    if (cachedUser != null && cachedUser!.name.trim().isNotEmpty) {
      return cachedUser!.name.trim();
    }
    if (member.name.trim().isNotEmpty && member.name.trim() != member.email.trim()) {
      return member.name.trim();
    }
    if (member.emailBasedName.isNotEmpty) {
      return member.emailBasedName;
    }
    return member.isOwner ? 'Family Owner' : 'Member';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _resolveName();
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Container(
      constraints: const BoxConstraints(minHeight: 110),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent ? AppColors.primaryPurple.withAlpha(80) : AppColors.lightLavenderBorder,
          width: isCurrent ? 1.5 : 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.lightLavender,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryPurple.withAlpha(150), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.outfit(
                      color: AppColors.primaryPurple,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Edit family name',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(Icons.edit_outlined, size: 19, color: AppColors.primaryPurple),
                onPressed: onEdit,
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: member.isOwner ? Colors.amber.withAlpha(40) : AppColors.lightLavender,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: member.isOwner ? Colors.amber.shade200 : AppColors.lightLavenderBorder,
                    width: 1,
                  ),
                ),
                child: Text(
                  member.isOwner ? 'Owner' : member.role.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: member.isOwner ? Colors.amber.shade900 : AppColors.primaryPurple,
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
