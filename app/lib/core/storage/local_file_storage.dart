import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class LocalFileStorage {
  static const String _assetsDirectoryName = 'assets';
  static const Uuid _uuid = Uuid();

  Future<Directory> _getAssetsDirectory() async {
    final appDirectory = await getApplicationDocumentsDirectory();
    final assetsDirectory = Directory(
      '${appDirectory.path}/$_assetsDirectoryName',
    );

    if (!await assetsDirectory.exists()) {
      await assetsDirectory.create(recursive: true);
    }

    return assetsDirectory;
  }

  Future<Directory> _getAssetDirectory(String assetId) async {
    final assetsDirectory = await _getAssetsDirectory();
    final assetDirectory = Directory(
      '${assetsDirectory.path}/$assetId',
    );

    if (!await assetDirectory.exists()) {
      await assetDirectory.create(recursive: true);
    }

    return assetDirectory;
  }

  Future<String> saveImage({
    required String assetId,
    required File sourceFile,
  }) async {
    final assetDirectory = await _getAssetDirectory(assetId);
    final imagesDirectory = Directory(
      '${assetDirectory.path}/images',
    );

    if (!await imagesDirectory.exists()) {
      await imagesDirectory.create(recursive: true);
    }

    final extension = _getExtension(sourceFile.path);
    final destination = File(
      '${imagesDirectory.path}/${_uuid.v4()}$extension',
    );

    final copiedFile = await sourceFile.copy(destination.path);
    return copiedFile.path;
  }

  Future<String> saveDocument({
    required String assetId,
    required File sourceFile,
  }) async {
    final assetDirectory = await _getAssetDirectory(assetId);
    final documentsDirectory = Directory(
      '${assetDirectory.path}/documents',
    );

    if (!await documentsDirectory.exists()) {
      await documentsDirectory.create(recursive: true);
    }

    final extension = _getExtension(sourceFile.path);
    final destination = File(
      '${documentsDirectory.path}/${_uuid.v4()}$extension',
    );

    final copiedFile = await sourceFile.copy(destination.path);
    return copiedFile.path;
  }

  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteAssetFiles(String assetId) async {
    final assetsDirectory = await _getAssetsDirectory();
    final assetDirectory = Directory(
      '${assetsDirectory.path}/$assetId',
    );

    if (await assetDirectory.exists()) {
      await assetDirectory.delete(recursive: true);
    }
  }

  String _getExtension(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final dotIndex = fileName.lastIndexOf('.');

    if (dotIndex == -1) {
      return '';
    }

    return fileName.substring(dotIndex);
  }
}
