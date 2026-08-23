import 'package:flutter/material.dart';
import '../../assets/screens/add_asset_screen.dart';

/// Entry point for adding an asset from Home/Assets quick actions.
///
/// This used to be its own bottom-sheet form with a separate, simplified
/// field set (fixed category list, no custom fields/documents/QR). It now
/// just opens [AddAssetScreen] so there's a single Add Asset form to
/// maintain, matching the full V1 spec (custom fields, document upload,
/// QR toggle, dynamic categories).
class AddQuickAssetSheet {
  AddQuickAssetSheet._();

  static Future<void> show(BuildContext context) {
    return AddAssetScreen.navigateTo(context);
  }
}
