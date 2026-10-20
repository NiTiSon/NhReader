import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret user settings. Secrets belong in AccountsRepository.
class SettingsRepository {
  SettingsRepository(this._prefs);

  static const _keyTheme = 'theme';
  static const _keyActiveAccountId = 'active_account_id';

  final SharedPreferences _prefs;

  /// Follows the device setting until the user picks Light or Dark.
  ThemeMode get themeMode =>
      ThemeMode.values[_prefs.getInt(_keyTheme) ?? ThemeMode.system.index];

  Future<void> setThemeMode(ThemeMode value) =>
      _prefs.setInt(_keyTheme, value.index);

  /// Id of the Account whose API key requests should use, null for guest.
  String? get activeAccountId => _prefs.getString(_keyActiveAccountId);

  Future<void> setActiveAccountId(String? id) => id == null
      ? _prefs.remove(_keyActiveAccountId)
      : _prefs.setString(_keyActiveAccountId, id);
}
