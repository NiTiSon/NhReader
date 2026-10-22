import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret user settings. Secrets belong in AccountsRepository.
class SettingsRepository {
  SettingsRepository(this._prefs);

  static const _keyTheme = 'theme';
  static const _keyActiveAccountId = 'active_account_id';
  static const _keySecureWindow = 'secure_window';
  static const _keyBookmarksGrid = 'bookmarks_grid';
  static const _keyBookmarksColumns = 'bookmarks_columns';
  static const _keyBookmarksNewestFirst = 'bookmarks_newest_first';

  final SharedPreferences _prefs;

  /// Follows the device setting until the user picks Light or Dark.
  ThemeMode get themeMode =>
      ThemeMode.values[_prefs.getInt(_keyTheme) ?? ThemeMode.system.index];

  Future<void> setThemeMode(ThemeMode value) =>
      _prefs.setInt(_keyTheme, value.index);

  /// Id of the active Account, null for guest.
  String? get activeAccountId => _prefs.getString(_keyActiveAccountId);

  Future<void> setActiveAccountId(String? id) => id == null
      ? _prefs.remove(_keyActiveAccountId)
      : _prefs.setString(_keyActiveAccountId, id);

  /// Blocks screenshots and hides the app in recents when enabled.
  bool get secureWindow => _prefs.getBool(_keySecureWindow) ?? false;

  Future<void> setSecureWindow(bool value) =>
      _prefs.setBool(_keySecureWindow, value);

  /// Grid layout for bookmarks; false means a list.
  bool get bookmarksGrid => _prefs.getBool(_keyBookmarksGrid) ?? true;

  Future<void> setBookmarksGrid(bool value) =>
      _prefs.setBool(_keyBookmarksGrid, value);

  /// Grid columns per row, kept between 2 and 4.
  int get bookmarksColumns {
    final value = _prefs.getInt(_keyBookmarksColumns) ?? 3;
    return value < 2 ? 2 : (value > 4 ? 4 : value);
  }

  Future<void> setBookmarksColumns(int value) =>
      _prefs.setInt(_keyBookmarksColumns, value);

  /// Whether bookmarks are shown newest first.
  bool get bookmarksNewestFirst =>
      _prefs.getBool(_keyBookmarksNewestFirst) ?? true;

  Future<void> setBookmarksNewestFirst(bool value) =>
      _prefs.setBool(_keyBookmarksNewestFirst, value);
}
