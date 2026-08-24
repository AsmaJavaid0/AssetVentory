import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';

class LocalFileStorage {
  static const String _assetsDirectoryName = 'assets';
  static const Uuid _uuid = Uuid();
  /// Returns the root directory where AssetVentory stores
  /// user-generated asset files.
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

  /// Returns the directory belonging to one asset.
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

  /// Saves an image selected by the user into permanent app storage.
  ///
  /// Returns the permanent local path of the copied image.
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

    final fileName = '${_uuid.v4()}$extension';
    final destination = File(
      '${imagesDirectory.path}/$fileName',
    );

    final copiedFile = await sourceFile.copy(destination.path);

    return copiedFile.path;
  }

  /// Deletes all locally stored files belonging to an asset.
  Future<void> deleteAssetFiles(String assetId) async {
    final assetsDirectory = await _getAssetsDirectory();

    final assetDirectory = Directory(
      '${assetsDirectory.path}/$assetId',
    );

    if (await assetDirectory.exists()) {
      await assetDirectory.delete(recursive: true);
    }
  }

  /// Extracts the file extension, including the dot.
  String _getExtension(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final dotIndex = fileName.lastIndexOf('.');

    if (dotIndex == -1) {
      return '';
    }

    return fileName.substring(dotIndex);
  }
}