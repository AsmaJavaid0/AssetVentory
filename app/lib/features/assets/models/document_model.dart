import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentModel {
  final String id;
  final String ownerId;
  final String assetId;
  final String fileUrl;
  final String storagePath;
  final String fileName;
  final String fileType;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentModel({
    required this.id,
    required this.ownerId,
    required this.assetId,
    required this.fileUrl,
    required this.storagePath,
    required this.fileName,
    required this.fileType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DocumentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return DocumentModel(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      assetId: data['assetId'] as String? ?? '',
      fileUrl: data['fileUrl'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      fileName: data['fileName'] as String? ?? '',
      fileType: data['fileType'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'assetId': assetId,
      'fileUrl': fileUrl,
      'storagePath': storagePath,
      'fileName': fileName,
      'fileType': fileType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
