/// User service — manages the user alias stored locally.
library;

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class UserService extends GetxService {
  static const _aliasKey = 'user_alias';
  final _storage = GetStorage();

  final alias = ''.obs;

  @override
  void onInit() {
    super.onInit();
    alias.value = _storage.read<String>(_aliasKey) ?? '';
  }

  /// Whether the user has completed onboarding.
  bool get hasAlias => alias.value.isNotEmpty;

  /// Save the user alias.
  Future<void> saveAlias(String name) async {
    final trimmed = name.trim();
    await _storage.write(_aliasKey, trimmed);
    alias.value = trimmed;
  }

  /// Clear the user alias (for testing/reset).
  Future<void> clearAlias() async {
    await _storage.remove(_aliasKey);
    alias.value = '';
  }
}
