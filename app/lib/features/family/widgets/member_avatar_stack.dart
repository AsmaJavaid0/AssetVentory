import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../models/family_member_model.dart';

class MemberAvatarStack extends StatelessWidget {
  final List<FamilyMemberModel> members;
  final int maxVisible;
  final double size;
  final VoidCallback? onTap;

  const MemberAvatarStack({
    super.key,
    required this.members,
    this.maxVisible = 4,
    this.size = 38,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();

    final visibleMembers = members.take(maxVisible).toList();
    final remainingCount = members.length - visibleMembers.length;
    final totalSlots = visibleMembers.length + (remainingCount > 0 ? 1 : 0);
    final overlap = size * 0.28;
    final totalWidth = size + (totalSlots - 1) * (size - overlap);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: SizedBox(
        width: totalWidth,
        height: size,
        child: Stack(
          children: [
            for (int i = 0; i < visibleMembers.length; i++)
              Positioned(
                left: i * (size - overlap),
                child: _buildAvatar(visibleMembers[i], i),
              ),
            if (remainingCount > 0)
              Positioned(
                left: visibleMembers.length * (size - overlap),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: AppColors.heroCardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '+$remainingCount',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: size * 0.34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(FamilyMemberModel member, int index) {
    final initial = member.name.isNotEmpty
        ? member.name[0].toUpperCase()
        : member.email.isNotEmpty
            ? member.email[0].toUpperCase()
            : 'U';

    final colors = [
      AppColors.primaryPurple,
      AppColors.primaryBlue,
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
    ];
    final color = colors[index % colors.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: member.photoUrl.isNotEmpty
          ? ClipOval(
              child: Image.network(
                member.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: size * 0.42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }
}
