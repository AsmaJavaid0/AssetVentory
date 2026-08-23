import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads an asset document and returns its download URL and storage path.
  Future<Map<String, String>> uploadAssetDocument({
    required String userId,
    required String assetId,
    required String filePath,
    required String fileName,
  }) async {
    final file = File(filePath);
    final storagePath = 'users/$userId/assets/$assetId/documents/$fileName';
    final ref = _storage.ref().child(storagePath);
    final uploadTask = await ref.putFile(file);
    final url = await uploadTask.ref.getDownloadURL();
    return {
      'url': url,
      'path': storagePath,
    };
  }

  /// Deletes a file from Firebase Storage
  Future<void> deleteFile(String storagePath) async {
    if (storagePath.isEmpty) return;
    try {
      final ref = _storage.ref().child(storagePath);
      await ref.delete();
    } catch (e) {
      // Ignore or log error
    }
  }
}
