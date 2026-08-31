import '../../models/local_asset.dart';
import 'dart:io';

abstract class IAssetRepository {
  Future<void> createAsset(LocalAsset asset);
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
  });
  Future<LocalAsset?> getAsset(String assetId);
  Future<List<LocalAsset>> getAssets(String ownerId);
  Future<List<LocalAsset>> getAssetsByCategory({
    required String ownerId,
    required String categoryId,
  });
  Future<void> updateAsset(LocalAsset asset);
  Future<LocalAsset> updateAssetImage({
    required LocalAsset asset,
    required File imageFile,
  });
  Future<void> deleteAsset(String assetId);
}
