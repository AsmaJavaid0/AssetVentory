import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/local_file_storage.dart';
import '../models/local_asset.dart';

class AssetRepository {
  final AppDatabase _database;
  final LocalFileStorage _fileStorage;
  static const Uuid _uuid = Uuid();
  AssetRepository({
    required this._database,
    required this._fileStorage,
  });

  /// Creates a new asset in the local database.
  Future<void> createAsset(LocalAsset asset) async {
    await _database.into(_database.assets).insert(
          AssetsCompanion.insert(
            id: asset.id,
            ownerId: asset.ownerId,
            name: asset.name,
            categoryId: Value(asset.categoryId),
            emoji: Value(asset.emoji),
            imagePath: Value(asset.imagePath),
            location: Value(asset.location),
            description: Value(asset.description),
            qrEnabled: Value(asset.qrEnabled),
            customFields: Value(jsonEncode(asset.customFields)),
            createdAt: asset.createdAt,
            updatedAt: asset.updatedAt,
          ),
        );
  }
  Future<LocalAsset> createAssetWithImage({
  required String ownerId,
  required String name,
  String? categoryId,
  String? emoji,
  File? imageFile,
  String? location,
  String? description,
  bool qrEnabled = false,
  Map<String, String> customFields = const {},
}) async {
  final now = DateTime.now();
  final assetId = _uuid.v4();

  String? imagePath;

  try {
    // 1. Save image locally first.
    if (imageFile != null) {
      imagePath = await _fileStorage.saveImage(
        assetId: assetId,
        sourceFile: imageFile,
      );
    }

    // 2. Build local asset.
    final asset = LocalAsset(
      id: assetId,
      ownerId: ownerId,
      name: name,
      categoryId: categoryId,
      emoji: emoji,
      imagePath: imagePath,
      location: location,
      description: description,
      qrEnabled: qrEnabled,
      customFields: customFields,
      createdAt: now,
      updatedAt: now,
    );

    // 3. Save asset metadata in SQLite.
    await createAsset(asset);

    return asset;
  } catch (e) {
    // If database saving fails after the image was copied,
    // remove the orphaned image.
    await _fileStorage.deleteAssetFiles(assetId);

    rethrow;
  }
}
  /// Gets one asset by its ID.
  Future<LocalAsset?> getAsset(String assetId) async {
    final query = _database.select(_database.assets)
      ..where((asset) => asset.id.equals(assetId));

    final row = await query.getSingleOrNull();

    if (row == null) {
      return null;
    }

    return _toLocalAsset(row);
  }

  /// Gets all locally stored assets for an owner.
  Future<List<LocalAsset>> getAssets(String ownerId) async {
    final query = _database.select(_database.assets)
      ..where((asset) => asset.ownerId.equals(ownerId))
      ..orderBy([
        (asset) => OrderingTerm.desc(asset.createdAt),
      ]);

    final rows = await query.get();

    return rows.map(_toLocalAsset).toList();
  }

  /// Updates an existing local asset.
  Future<void> updateAsset(LocalAsset asset) async {
    await (_database.update(_database.assets)
          ..where((row) => row.id.equals(asset.id)))
        .write(
      AssetsCompanion(
        ownerId: Value(asset.ownerId),
        name: Value(asset.name),
        categoryId: Value(asset.categoryId),
        emoji: Value(asset.emoji),
        imagePath: Value(asset.imagePath),
        location: Value(asset.location),
        description: Value(asset.description),
        qrEnabled: Value(asset.qrEnabled),
        customFields: Value(jsonEncode(asset.customFields)),
        createdAt: Value(asset.createdAt),
        updatedAt: Value(asset.updatedAt),
      ),
    );
  }

  /// Deletes an asset and its locally stored files.
  Future<void> deleteAsset(String assetId) async {
    await (_database.delete(_database.assets)
          ..where((asset) => asset.id.equals(assetId)))
        .go();

    await _fileStorage.deleteAssetFiles(assetId);
  }

  LocalAsset _toLocalAsset(Asset row) {
    return LocalAsset(
      id: row.id,
      ownerId: row.ownerId,
      name: row.name,
      categoryId: row.categoryId,
      emoji: row.emoji,
      imagePath: row.imagePath,
      location: row.location,
      description: row.description,
      qrEnabled: row.qrEnabled,
      customFields: _decodeCustomFields(row.customFields),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Map<String, String> _decodeCustomFields(String value) {
    try {
      final decoded = jsonDecode(value);

      if (decoded is Map<String, dynamic>) {
        return decoded.map(
          (key, value) => MapEntry(key, value.toString()),
        );
      }

      return {};
    } catch (_) {
      return {};
    }
  }
}