import 'dart:io';
import '../../models/local_asset_document.dart';

abstract class IAssetDocumentRepository {
  Future<List<LocalAssetDocument>> getDocuments(String assetId);
  Future<LocalAssetDocument> addDocument({
    required String assetId,
    required File sourceFile,
    String? displayName,
  });
  Future<void> deleteDocument(LocalAssetDocument document);
  Future<void> deleteDocumentsForAsset(String assetId);
}
