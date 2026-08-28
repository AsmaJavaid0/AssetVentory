import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/local_file_storage.dart';
import '../models/local_asset.dart';
import '../models/local_category.dart';
import '../repositories/asset_repository.dart';
import '../repositories/category_repository.dart';
import 'asset_details_screen.dart';
import 'category_detail_screen.dart';
import '../../home/widgets/add_quick_asset_sheet.dart';
import '../widgets/create_category_sheet.dart';

enum _AssetView { all, categories }
enum _AssetSort { newest, name, location }

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});
  @override State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> with SingleTickerProviderStateMixin {
  static const _ownerId = 'local_user';
  final _searchController = TextEditingController();
  late final AppDatabase _database;
  late final AssetRepository _assetRepository;
  late final CategoryRepository _categoryRepository;
  late final AnimationController _searchControllerAnim;
  late final Animation<double> _searchAnimation;
  List<LocalAsset> _assets = [];
  List<LocalCategory> _categories = [];
  bool _loading = true;
  bool _searchVisible = false;
  String _searchQuery = '';
  _AssetView _view = _AssetView.all;
  _AssetSort _sort = _AssetSort.newest;

  @override
  void initState() { super.initState(); _database = AppDatabase(); _assetRepository = AssetRepository(database: _database, fileStorage: LocalFileStorage()); _categoryRepository = CategoryRepository(database: _database); _searchControllerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 200)); _searchAnimation = CurvedAnimation(parent: _searchControllerAnim, curve: Curves.easeOutCubic); _load(); }
  @override
  void dispose() { _searchController.dispose(); _searchControllerAnim.dispose(); super.dispose(); }

  Future<void> _load() async {
    try { final assets = await _assetRepository.getAssets(_ownerId); final categories = await _categoryRepository.getCategories(_ownerId); if (!mounted) return; setState(() { _assets = assets; _categories = categories; _loading = false; }); }
    catch (e, st) { debugPrint('Assets load error: $e'); debugPrintStack(stackTrace: st); if (mounted) setState(() => _loading = false); }
  }

  List<LocalAsset> get _filteredAssets {
    final query = _searchQuery.toLowerCase();
    final result = _assets.where((a) => query.isEmpty || a.name.toLowerCase().contains(query) || (a.location?.toLowerCase().contains(query) ?? false) || (a.description?.toLowerCase().contains(query) ?? false)).toList();
    result.sort((a, b) { switch (_sort) { case _AssetSort.newest: return b.createdAt.compareTo(a.createdAt); case _AssetSort.name: return a.name.toLowerCase().compareTo(b.name.toLowerCase()); case _AssetSort.location: return (a.location ?? '').toLowerCase().compareTo((b.location ?? '').toLowerCase()); } });
    return result;
  }
  int _countFor(String id) => _assets.where((a) => a.categoryId == id).length;
  Future<void> _openAsset(LocalAsset asset) async { await AssetDetailsScreen.navigateTo(context, asset); if (mounted) await _load(); }
  Future<void> _openCategory(LocalCategory category) async { await CategoryDetailScreen.navigateTo(context, category); if (mounted) await _load(); }
  void _toggleSearch() { setState(() => _searchVisible = !_searchVisible); if (_searchVisible) { _searchControllerAnim.forward(); } else { _searchControllerAnim.reverse(); _searchController.clear(); setState(() => _searchQuery = ''); } }
  Future<void> _addAsset() async { await AddQuickAssetSheet.show(context); if (mounted) await _load(); }
  Future<void> _addCategory() async {
    final created = await CreateCategorySheet.show(
      context,
      onCreateCategory: (name, emoji) async {
        await _categoryRepository.createCategoryIfNotExists(
          ownerId: _ownerId,
          name: name,
          emoji: emoji,
        );
      },
    );
    if (created == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final categoriesMode = _view == _AssetView.categories;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'assets_fab',
        onPressed: categoriesMode ? _addCategory : _addAsset,
        backgroundColor: AppColors.primaryPurple,
        icon: Icon(categoriesMode ? Icons.create_new_folder_outlined : Icons.add_rounded, color: Colors.white),
        label: Text(categoriesMode ? 'Add Category' : 'Add Asset', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [_header(), _tabs(), Expanded(child: categoriesMode ? _categoriesView() : _assetsView())]),
    );
  }

  Widget _header() { final top = MediaQuery.of(context).padding.top; return Container(padding: EdgeInsets.fromLTRB(20, top + 16, 12, 20), decoration: const BoxDecoration(color: AppColors.heroDarkBg, borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))), child: Row(children: [Expanded(child: Text('My Assets', style: GoogleFonts.outfit(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700))), IconButton(onPressed: _toggleSearch, tooltip: 'Search', icon: Icon(_searchVisible ? Icons.close_rounded : Icons.search_rounded, color: Colors.white)), PopupMenuButton<_AssetSort>(tooltip: 'Sort', icon: const Icon(Icons.sort_rounded, color: Colors.white), color: Colors.white, onSelected: (v) => setState(() => _sort = v), itemBuilder: (_) => const [PopupMenuItem(value: _AssetSort.newest, child: Text('Newest first')), PopupMenuItem(value: _AssetSort.name, child: Text('Name A–Z')), PopupMenuItem(value: _AssetSort.location, child: Text('Location A–Z'))]) ])); }

  Widget _tabs() => Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: Row(children: [Expanded(child: _tab('All', _AssetView.all)), const SizedBox(width: 8), Expanded(child: _tab('Categories', _AssetView.categories))]));
  Widget _tab(String label, _AssetView view) { final selected = _view == view; return GestureDetector(onTap: () => setState(() => _view = view), child: AnimatedContainer(duration: const Duration(milliseconds: 160), height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: selected ? AppColors.primaryPurple : AppColors.scaffoldBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? AppColors.primaryPurple : const Color(0xFFE5E0EC))), child: Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textSecondary)))); }

  Widget _searchBar() => SizeTransition(
        sizeFactor: _searchAnimation,
        child: Container(
          color: const Color(0xFF1F1040),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search assets...',
              hintStyle: const TextStyle(color: Color(0xFFB8AED6)),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFB8AED6)),
              filled: true,
              fillColor: Colors.white.withAlpha(18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      );

  Widget _assetsView() { final assets = _filteredAssets; return Column(children: [if (_searchVisible) _searchBar(), Expanded(child: assets.isEmpty ? _emptyAssets() : RefreshIndicator(color: AppColors.primaryPurple, onRefresh: _load, child: ListView.separated(padding: const EdgeInsets.fromLTRB(16, 14, 16, 100), physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), itemCount: assets.length, separatorBuilder: (_, _) => const SizedBox(height: 10), itemBuilder: (_, i) => _assetCard(assets[i]))))]); }
  Widget _emptyAssets() => RefreshIndicator(color: AppColors.primaryPurple, onRefresh: _load, child: ListView(children: [const SizedBox(height: 150), Center(child: Icon(Icons.inventory_2_outlined, size: 58, color: AppColors.primaryPurple)), const SizedBox(height: 14), Center(child: Text('No assets yet', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700))), const SizedBox(height: 6), Center(child: Text('Tap the + button below to add your first asset.', style: GoogleFonts.outfit(color: AppColors.textSecondary)))]));
  Widget _assetCard(LocalAsset a) => GestureDetector(onTap: () => _openAsset(a), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEFEBF6))), child: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(14), child: Container(width: 78, height: 68, color: AppColors.primaryPurple.withAlpha(15), child: a.imagePath?.isNotEmpty == true ? Image.file(File(a.imagePath!), fit: BoxFit.cover, errorBuilder: (_, _, _) => _assetEmoji(a)) : _assetEmoji(a))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15)), const SizedBox(height: 5), Text(a.categoryId == null ? 'No category' : (_categories.where((c) => c.id == a.categoryId).map((c) => c.name).firstOrNull ?? 'Category'), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)), if (a.location?.isNotEmpty == true) Text(a.location!, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted))])), const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted)])));
  Widget _assetEmoji(LocalAsset a) => Center(child: Text(a.emoji ?? '📦', style: const TextStyle(fontSize: 32)));

  Widget _categoriesView() => RefreshIndicator(color: AppColors.primaryPurple, onRefresh: _load, child: _categories.isEmpty ? ListView(children: [const SizedBox(height: 170), Center(child: Text('No categories yet.')), const SizedBox(height: 16), Center(child: Text('Use Add Category below to create one.', style: TextStyle(color: AppColors.textSecondary)))]) : ListView.separated(padding: const EdgeInsets.fromLTRB(16, 14, 16, 100), physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), itemCount: _categories.length, separatorBuilder: (_, _) => const SizedBox(height: 10), itemBuilder: (_, i) { final c = _categories[i]; final count = _countFor(c.id); return GestureDetector(onTap: () => _openCategory(c), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEFEBF6))), child: Row(children: [Container(width: 54, height: 54, alignment: Alignment.center, decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(15)), child: Text(c.emoji ?? '📂', style: const TextStyle(fontSize: 27))), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text('$count ${count == 1 ? 'asset' : 'assets'}', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary))])), const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted)]))); }));
}
