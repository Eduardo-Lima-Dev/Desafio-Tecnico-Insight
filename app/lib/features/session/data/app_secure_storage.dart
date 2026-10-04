import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// O Keychain "data protection" exige o entitlement keychain-access-groups, que
// só existe em builds assinados com um Apple Developer Team. O Keychain
// tradicional funciona no sandbox com a assinatura ad-hoc do build local.
const appSecureStorage = FlutterSecureStorage(
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);
