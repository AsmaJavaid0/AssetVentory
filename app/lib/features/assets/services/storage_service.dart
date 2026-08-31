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

  /// Uploads an asset main cover image
  Future<Map<String, String>> uploadAssetImage({
    required String userId,
    required String assetId,
    required String filePath,
  }) async {
    final file = File(filePath);
    final ext = filePath.split('.').last.toLowerCase();
    final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storagePath = 'users/$userId/assets/$assetId/images/$fileName';
    final ref = _storage.ref().child(storagePath);
    final uploadTask = await ref.putFile(file);
    final url = await uploadTask.ref.getDownloadURL();
    return {
      'url': url,
      'path': storagePath,
    };
  }

  /// Uploads a task image
  Future<Map<String, String>> uploadTaskImage({
    required String userId,
    required String taskId,
    required String filePath,
  }) async {
    final file = File(filePath);
    final ext = filePath.split('.').last.toLowerCase();
    final fileName = 'task_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storagePath = 'users/$userId/tasks/$taskId/images/$fileName';
    final ref = _storage.ref().child(storagePath);
    final uploadTask = await ref.putFile(file);
    final url = await uploadTask.ref.getDownloadURL();
    return {
      'url': url,
      'path': storagePath,
    };
  }

  /// Uploads a user profile photo and returns its download URL
  Future<String> uploadProfilePhoto({
    required String userId,
    required String filePath,
  }) async {
    final file = File(filePath);
    final ext = filePath.split('.').last.toLowerCase();
    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storagePath = 'users/$userId/profile/$fileName';
    final ref = _storage.ref().child(storagePath);
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
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
