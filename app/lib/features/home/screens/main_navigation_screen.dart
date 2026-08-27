import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../assets/screens/assets_screen.dart';
import '../../tasks/screens/tasks_screen.dart';
import '../../family/screens/family_share_screen.dart';
import 'home_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

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
      const FamilyShareScreen(),
      const TasksScreen(),
      _buildProfilePage(),
    ];
  }

  Widget _buildProfilePage() {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Profile & Settings',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.primaryPurple,
            child: const Text(
              'U',
              style: TextStyle(
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Local User',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Personal mode',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFEFEBF6),
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
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withAlpha(16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.storage_rounded,
                      color: AppColors.primaryPurple,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Local Storage',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    'Your personal assets are stored on this device.',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withAlpha(16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.group_rounded,
                      color: AppColors.primaryPurple,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Family Sharing',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    'Sign in only when you need remote sharing.',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
            backgroundColor: Colors.white,
            elevation: 0,
            selectedItemColor: AppColors.primaryPurple,
            unselectedItemColor: const Color(0xFF9E98AD),
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