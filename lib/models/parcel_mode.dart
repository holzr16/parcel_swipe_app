// lib/models/parcel_mode.dart

enum ParcelMode {
  view,
  landType,
  landSubType,
}

extension ParcelModeExtension on ParcelMode {
  String get name {
    switch (this) {
      case ParcelMode.view:
        return 'View Mode';
      case ParcelMode.landType:
        return 'Land Type Mode';
      case ParcelMode.landSubType:
        return 'Land Sub-Type Mode';
      default:
        return '';
    }
  }
}
