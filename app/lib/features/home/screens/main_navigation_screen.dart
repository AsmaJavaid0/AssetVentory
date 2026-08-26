import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_palette.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../assets/screens/assets_screen.dart';
import '../../tasks/screens/tasks_screen.dart';
import 'home_screen.dart';
import '../../../core/theme/app_settings.dart';

class MainNavigationScreen extends StatefulWidget {
  final AppSettings settings;
  const MainNavigationScreen({super.key, required this.settings});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      HomeScreen(
        onTabSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      const AssetsScreen(),
      _buildFamilySharePage(),
      const TasksScreen(),
      _buildProfilePage(),
    ];
  }

  Widget _buildFamilySharePage() {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.isDark ? AppColors.heroDarkBg : AppColors.scaffoldBg,
      appBar: AppBar(title: const Text('Family Share')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.group_rounded,
                  size: 54,
                  color: AppColors.primaryPurple,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Family Sharing',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: palette.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your personal assets work completely offline. '
                'Google/Firebase sign-in will only be required '
                'when you use Family Sharing.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: palette.onSurfaceMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    AppSnackBar.show(context, 'Family Share sign-in coming soon.');
                  },
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign in for Family Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePage() {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.isDark ? AppColors.heroDarkBg : AppColors.scaffoldBg,
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.primaryPurple,
            child: const Text(
              'U',
              style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Local User',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: palette.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Personal mode',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13, color: palette.onSurfaceMuted),
          ),
          const SizedBox(height: 28),
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border),
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
                _themeToggleTile(palette),
                Divider(height: 1, indent: 16, endIndent: 16, color: palette.divider),
                _profileTile(palette, Icons.storage_rounded, 'Local Storage',
                    'Your personal assets are stored on this device.'),
                Divider(height: 1, indent: 16, endIndent: 16, color: palette.divider),
                _profileTile(palette, Icons.group_rounded, 'Family Sharing',
                    'Sign in only when you need remote sharing.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileTile(AppPalette palette, IconData icon, String title, String subtitle) => ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withAlpha(16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryPurple, size: 20),
        ),
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: palette.onSurfaceMuted)),
      );

  Widget _themeToggleTile(AppPalette palette) => ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withAlpha(16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            widget.settings.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: AppColors.primaryPurple,
            size: 20,
          ),
        ),
        title: Text('Dark Mode', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          widget.settings.isSystem
              ? 'Following system'
              : (widget.settings.isDark ? 'On' : 'Off'),
          style: GoogleFonts.outfit(fontSize: 12, color: palette.onSurfaceMuted),
        ),
        trailing: Switch(
          value: widget.settings.isDark,
          activeColor: AppColors.primaryPurple,
          onChanged: (_) => widget.settings.toggle(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: palette.surface,
            elevation: 0,
            selectedItemColor: AppColors.primaryPurple,
            unselectedItemColor: palette.iconMuted,
            selectedLabelStyle: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_filled),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2_rounded),
                label: 'Assets',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.group_outlined),
                activeIcon: Icon(Icons.group_rounded),
                label: 'Family',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.task_alt_outlined),
                activeIcon: Icon(Icons.task_alt_rounded),
                label: 'Tasks',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}