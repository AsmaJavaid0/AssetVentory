import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../widgets/profile_section.dart';
import '../widgets/profile_settings_tile.dart';

class DataStorageScreen extends StatefulWidget {
  const DataStorageScreen({super.key});

  static Future<void> navigateTo(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DataStorageScreen()),
    );
  }

  @override
  State<DataStorageScreen> createState() => _DataStorageScreenState();
}

class _DataStorageScreenState extends State<DataStorageScreen> {
  final _assetRepository = serviceLocator.assetRepository;
  final _categoryRepository = serviceLocator.categoryRepository;

  int _assetCount = 0;
  int _categoryCount = 0;
  String _cacheSizeStr = 'Calculating...';
  bool _isLoading = true;
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadStorageStats();
  }

  Future<void> _loadStorageStats() async {
    try {
      final assets = await _assetRepository.getAssets('local_user');
      final categories = await _categoryRepository.getCategories('local_user');
      final cacheSize = await _calculateCacheSize();

      if (!mounted) return;
      setState(() {
        _assetCount = assets.length;
        _categoryCount = categories.length;
        _cacheSizeStr = _formatBytes(cacheSize);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<int> _calculateCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int totalSize = 0;
      if (tempDir.existsSync()) {
        tempDir.listSync(recursive: true, followLinks: false).forEach((FileSystemEntity entity) {
          if (entity is File) {
            totalSize += entity.lengthSync();
          }
        });
      }
      return totalSize;
    } catch (_) {
      return 0;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear Temporary Cache?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will delete cached temporary preview files to free up storage. Your assets, tasks, categories, and account will NOT be deleted.',
          style: GoogleFonts.outfit(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isClearingCache = true);

    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.listSync(recursive: false).forEach((entity) {
          try {
            entity.deleteSync(recursive: true);
          } catch (_) {}
        });
      }

      await _loadStorageStats();

      if (!mounted) return;
      setState(() => _isClearingCache = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Temporary cache cleared successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isClearingCache = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear cache: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        appBar: AppBar(
          title: Text(
            'Data & Storage',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Data & Storage',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            ProfileSection(
              title: 'Local Vault Storage',
              children: [
                ProfileSettingsTile(
                  icon: Icons.inventory_2_rounded,
                  title: 'Saved Assets',
                  valueText: '$_assetCount items',
                  showChevron: false,
                ),
                ProfileSettingsTile(
                  icon: Icons.folder_rounded,
                  title: 'Custom Categories',
                  valueText: '$_categoryCount folders',
                  showChevron: false,
                ),
                ProfileSettingsTile(
                  icon: Icons.sd_storage_rounded,
                  title: 'Database Engine',
                  valueText: 'Drift SQLite (Encrypted)',
                  showChevron: false,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ProfileSection(
              title: 'Temporary Files',
              children: [
                ProfileSettingsTile(
                  icon: Icons.cached_rounded,
                  title: 'Cached Images & Previews',
                  subtitle: 'Temporary thumbnail caches',
                  valueText: _cacheSizeStr,
                  showChevron: false,
                ),
                ProfileSettingsTile(
                  icon: Icons.cleaning_services_rounded,
                  title: 'Clear Temporary Cache',
                  subtitle: _isClearingCache ? 'Cleaning cache...' : 'Free up temporary space safely',
                  onTap: _isClearingCache ? null : _clearCache,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEFEBF6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, color: AppColors.primaryPurple, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your personal vault is stored securely on your local device. Remote syncing is activated when using Family Sharing.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
