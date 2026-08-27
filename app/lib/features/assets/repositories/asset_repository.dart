import 'dart:io';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/local_file_storage.dart';
import '../models/local_asset.dart';
import 'interfaces/i_asset_repository.dart';

class AssetRepository implements IAssetRepository {
  final AppDatabase _database;
  final LocalFileStorage _fileStorage;
  static const Uuid _uuid = Uuid();
  AssetRepository({required this._database, required this._fileStorage});

  @override
  Future<void> createAsset(LocalAsset asset) async {
    await _database.into(_database.assets).insert(AssetsCompanion.insert(
      id: asset.id, ownerId: asset.ownerId, name: asset.name,
      categoryId: Value(asset.categoryId), emoji: Value(asset.emoji), imagePath: Value(asset.imagePath),
      location: Value(asset.location), description: Value(asset.description), qrEnabled: Value(asset.qrEnabled),
      customFields: Value(asset.customFields), createdAt: asset.createdAt, updatedAt: asset.updatedAt,
    ));
  }

  @override
  Future<LocalAsset> createAssetWithImage({required String ownerId, required String name, String? categoryId,
    String? emoji, File? imageFile, String? location, String? description, bool qrEnabled = false,
    Map<String, String> customFields = const {}}) async {
    final now = DateTime.now();
    final assetId = _uuid.v4();
    String? imagePath;
    try {
      if (imageFile != null) imagePath = await _fileStorage.saveImage(assetId: assetId, sourceFile: imageFile);
      final asset = LocalAsset(id: assetId, ownerId: ownerId, name: name, categoryId: categoryId, emoji: emoji,
        imagePath: imagePath, location: location, description: description, qrEnabled: qrEnabled,
        customFields: customFields, createdAt: now, updatedAt: now);
      await createAsset(asset);
      return asset;
    } catch (e) {
      await _fileStorage.deleteAssetFiles(assetId);
      rethrow;
    }
  }

  @override
  Future<LocalAsset?> getAsset(String assetId) async {
    final query = _database.select(_database.assets)..where((asset) => asset.id.equals(assetId));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toLocalAsset(row);
  }

  @override
  Future<List<LocalAsset>> getAssets(String ownerId) async {
    final query = _database.select(_database.assets)..where((asset) => asset.ownerId.equals(ownerId))
      ..orderBy([(asset) => OrderingTerm.desc(asset.createdAt)]);
    return (await query.get()).map(_toLocalAsset).toList();
  }

  @override
  Future<List<LocalAsset>> getAssetsByCategory({required String ownerId, required String categoryId}) async {
    final query = _database.select(_database.assets)
      ..where((asset) => asset.ownerId.equals(ownerId) & asset.categoryId.equals(categoryId))
      ..orderBy([(asset) => OrderingTerm.desc(asset.createdAt)]);
    return (await query.get()).map(_toLocalAsset).toList();
  }

  @override
  Future<void> updateAsset(LocalAsset asset) async {
    await (_database.update(_database.assets)..where((row) => row.id.equals(asset.id))).write(AssetsCompanion(
      ownerId: Value(asset.ownerId), name: Value(asset.name), categoryId: Value(asset.categoryId), emoji: Value(asset.emoji),
      imagePath: Value(asset.imagePath), location: Value(asset.location), description: Value(asset.description), qrEnabled: Value(asset.qrEnabled),
      customFields: Value(asset.customFields), createdAt: Value(asset.createdAt), updatedAt: Value(asset.updatedAt),
    ));
  }

  @override
  Future<LocalAsset> updateAssetImage({required LocalAsset asset, required File imageFile}) async {
    final oldPath = asset.imagePath;
    final newPath = await _fileStorage.saveImage(assetId: asset.id, sourceFile: imageFile);
    final updated = asset.copyWith(imagePath: newPath, updatedAt: DateTime.now());
    try {
      await updateAsset(updated);
      if (oldPath != null && oldPath.isNotEmpty && oldPath != newPath) await _fileStorage.deleteFile(oldPath);
      return updated;
    } catch (e) {
      await _fileStorage.deleteFile(newPath);
      rethrow;
    }
  }

  @override
  Future<void> deleteAsset(String assetId) async {
    await (_database.delete(_database.assets)..where((asset) => asset.id.equals(assetId))).go();
    await _fileStorage.deleteAssetFiles(assetId);
  }

  LocalAsset _toLocalAsset(Asset row) => LocalAsset(id: row.id, ownerId: row.ownerId, name: row.name,
    categoryId: row.categoryId, emoji: row.emoji, imagePath: row.imagePath, location: row.location,
    description: row.description, qrEnabled: row.qrEnabled, customFields: row.customFields,
    createdAt: row.createdAt, updatedAt: row.updatedAt);

  // _decodeCustomFields is no longer needed as Drift handles it via TypeConverter
}
