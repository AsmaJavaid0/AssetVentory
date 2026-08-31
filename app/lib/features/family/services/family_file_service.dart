import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyFileService {
  static const bucket = 'family-files';

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to access family files.');
    }

    // The edge function verifies this token against Firestore. Refresh it at
    // the point of use so a recently signed-in or newly joined member is not
    // rejected because the client supplied a cached credential.
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw StateError(
        'Your Firebase session has expired. Please sign in again.',
      );
    }

    final response = await _supabase.functions.invoke(
      'family-files',
      headers: {'Authorization': 'Bearer $token'},
      body: body,
    );

    if (response.status != 200) {
      final data = response.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'Family file operation failed.';
      throw Exception(message);
    }

    final data = response.data;
    if (data is! Map) throw Exception('Invalid family file response.');
    return Map<String, dynamic>.from(data);
  }

  Future<String> uploadFile({
    required String familyId,
    required String assetId,
    required String filePath,
    required String fileName,
    required String contentType,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('The selected file no longer exists.');
    }

    final result = await _invoke({
      'action': 'create-upload-url',
      'familyId': familyId,
      'assetId': assetId,
      'fileName': fileName,
      'contentType': contentType,
    });

    final path = result['path'] as String?;
    final token = result['token'] as String?;
    if (path == null || token == null) {
      throw Exception('The secure upload URL was not returned.');
    }

    await _supabase.storage
        .from(bucket)
        .uploadToSignedUrl(
          path,
          token,
          file,
          FileOptions(contentType: contentType, upsert: false),
        );

    return path;
  }

  Future<String> getDownloadUrl({
    required String familyId,
    required String path,
  }) async {
    final result = await _invoke({
      'action': 'create-download-url',
      'familyId': familyId,
      'path': path,
    });

    final url = result['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Could not create a secure download URL.');
    }
    return url;
  }

  Future<void> deleteFile({
    required String familyId,
    required String path,
  }) async {
    await _invoke({'action': 'delete', 'familyId': familyId, 'path': path});
  }
}
