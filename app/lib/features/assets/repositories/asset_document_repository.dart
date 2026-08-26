import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/storage/local_file_storage.dart';
import '../models/local_asset_document.dart';
import 'interfaces/i_asset_document_repository.dart';

class AssetDocumentRepository implements IAssetDocumentRepository {
  final AppDatabase _database;
  final LocalFileStorage _fileStorage;

  static const Uuid _uuid = Uuid();

  AssetDocumentRepository({
    required this._database,
    required this._fileStorage,
  });

  Future<List<LocalAssetDocument>> getDocuments(String assetId) async {
    final query = _database.select(_database.assetDocuments)
      ..where((document) => document.assetId.equals(assetId))
      ..orderBy([
        (document) => OrderingTerm.desc(document.createdAt),
      ]);

    final rows = await query.get();
    return rows.map(_toModel).toList();
  }

  /// Total number of documents attached to every asset owned by [ownerId].
  Future<int> countDocuments(String ownerId) async {
    final assets = await _database
        .select(_database.assets)
        .join([
          innerJoin(
            _database.assetDocuments,
            _database.assetDocuments.assetId.equalsExp(_database.assets.id),
          ),
        ])
      ..where(_database.assets.ownerId.equals(ownerId));

    return assets.get().length;
  }

  Future<LocalAssetDocument> addDocument({
    required String assetId,
    required File sourceFile,
    String? displayName,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final permanentPath = await _fileStorage.saveDocument(
      assetId: assetId,
      sourceFile: sourceFile,
    );

    final name = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : sourceFile.path.split(Platform.pathSeparator).last;

    final document = LocalAssetDocument(
      id: id,
      assetId: assetId,
      name: name,
      filePath: permanentPath,
      fileType: _extension(sourceFile.path),
      fileSize: await sourceFile.length(),
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _database.into(_database.assetDocuments).insert(
            AssetDocumentsCompanion.insert(
              id: document.id,
              assetId: document.assetId,
              name: document.name,
              filePath: document.filePath,
              fileType: Value(document.fileType),
              fileSize: Value(document.fileSize),
              createdAt: document.createdAt,
              updatedAt: document.updatedAt,
            ),
          );
    } catch (_) {
      await _fileStorage.deleteFile(permanentPath);
      rethrow;
    }

    return document;
  }

  Future<void> deleteDocument(LocalAssetDocument document) async {
    await (_database.delete(_database.assetDocuments)
          ..where((row) => row.id.equals(document.id)))
        .go();

    await _fileStorage.deleteFile(document.filePath);
  }

  Future<void> deleteDocumentsForAsset(String assetId) async {
    final documents = await getDocuments(assetId);

    await (_database.delete(_database.assetDocuments)
          ..where((row) => row.assetId.equals(assetId)))
        .go();

    for (final document in documents) {
      await _fileStorage.deleteFile(document.filePath);
    }
  }

  LocalAssetDocument _toModel(AssetDocument row) {
    return LocalAssetDocument(
      id: row.id,
      assetId: row.assetId,
      name: row.name,
      filePath: row.filePath,
      fileType: row.fileType,
      fileSize: row.fileSize,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  String? _extension(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final index = name.lastIndexOf('.');
    if (index == -1) return null;
    return name.substring(index + 1).toLowerCase();
  }
}
