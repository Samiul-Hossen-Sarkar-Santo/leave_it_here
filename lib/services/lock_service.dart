import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class LockService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const _pinSaltKey = 'app_lock_pin_salt_v1';
  static const _pinHashKey = 'app_lock_pin_hash_v1';

  Future<bool> hasPin() async {
    return (await _secureStorage.read(key: _pinHashKey)) != null;
  }

  Future<bool> canUseBiometric() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final isSupported = await _localAuth.isDeviceSupported();
    return canCheck || isSupported;
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock your journal',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    final salt = _randomBytes(16);
    final hash = _pbkdf2(pin, salt, 10000);
    await _secureStorage.write(key: _pinSaltKey, value: base64Encode(salt));
    await _secureStorage.write(key: _pinHashKey, value: base64Encode(hash));
  }

  Future<bool> verifyPin(String pin) async {
    final saltRaw = await _secureStorage.read(key: _pinSaltKey);
    final hashRaw = await _secureStorage.read(key: _pinHashKey);

    if (saltRaw == null || hashRaw == null) {
      return false;
    }

    final salt = base64Decode(saltRaw);
    final expected = base64Decode(hashRaw);
    final computed = _pbkdf2(pin, salt, 10000);

    return _constantTimeEquals(expected, computed);
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  List<int> _pbkdf2(String pin, List<int> salt, int iterations) {
    var block = Hmac(sha256, utf8.encode(pin)).convert(salt).bytes;
    for (var i = 1; i < iterations; i++) {
      block = Hmac(sha256, utf8.encode(pin)).convert(block).bytes;
    }
    return block;
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }

    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
