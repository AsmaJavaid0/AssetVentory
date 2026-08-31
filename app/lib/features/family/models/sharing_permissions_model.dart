class SharingPermissionsModel {
  final bool viewDetails;
  final bool viewLocation;
  final bool viewDocuments;
  final bool viewMaintenance;

  const SharingPermissionsModel({
    this.viewDetails = true,
    this.viewLocation = false,
    this.viewDocuments = false,
    this.viewMaintenance = false,
  });

  factory SharingPermissionsModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const SharingPermissionsModel();
    return SharingPermissionsModel(
      viewDetails: map['viewDetails'] as bool? ?? true,
      viewLocation: map['viewLocation'] as bool? ?? false,
      viewDocuments: map['viewDocuments'] as bool? ?? false,
      viewMaintenance: map['viewMaintenance'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'viewDetails': viewDetails,
      'viewLocation': viewLocation,
      'viewDocuments': viewDocuments,
      'viewMaintenance': viewMaintenance,
    };
  }

  SharingPermissionsModel copyWith({
    bool? viewDetails,
    bool? viewLocation,
    bool? viewDocuments,
    bool? viewMaintenance,
  }) {
    return SharingPermissionsModel(
      viewDetails: viewDetails ?? this.viewDetails,
      viewLocation: viewLocation ?? this.viewLocation,
      viewDocuments: viewDocuments ?? this.viewDocuments,
      viewMaintenance: viewMaintenance ?? this.viewMaintenance,
    );
  }
}
