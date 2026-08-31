import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

class ProfileSettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? iconBgColor;
  final String title;
  final String? subtitle;
  final String? valueText;
  final VoidCallback? onTap;
  final bool isSwitch;
  final bool switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final bool isDestructive;
  final bool showChevron;
  final Widget? customTrailing;

  const ProfileSettingsTile({
    super.key,
    required this.icon,
    this.iconColor,
    this.iconBgColor,
    required this.title,
    this.subtitle,
    this.valueText,
    this.onTap,
    this.isSwitch = false,
    this.switchValue = false,
    this.onSwitchChanged,
    this.isDestructive = false,
    this.showChevron = true,
    this.customTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = isDestructive
        ? AppColors.error
        : (iconColor ?? AppColors.primaryPurple);
    final effectiveIconBgColor = isDestructive
        ? AppColors.error.withAlpha(20)
        : (iconBgColor ?? AppColors.primaryPurple.withAlpha(16));

    Widget? trailingWidget;
    if (customTrailing != null) {
      trailingWidget = customTrailing;
    } else if (isSwitch) {
      trailingWidget = Switch.adaptive(
        value: switchValue,
        onChanged: onSwitchChanged,
        activeTrackColor: AppColors.primaryPurple,
      );
    } else if (valueText != null && valueText!.isNotEmpty) {
      trailingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            valueText!,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ],
      );
    } else if (showChevron) {
      trailingWidget = const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
        size: 20,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSwitch
            ? (onSwitchChanged != null ? () => onSwitchChanged!(!switchValue) : null)
            : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: effectiveIconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: effectiveIconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDestructive
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
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
              if (trailingWidget != null) ...[
                const SizedBox(width: 8),
                trailingWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
