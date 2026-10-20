import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'account.dart';

/// Stores every account (label + API key) encrypted as a single JSON list
/// under one key, so the list and its secrets can never drift apart.
class AccountsRepository {
  AccountsRepository(this._storage);

  static const _key = 'accounts';

  final FlutterSecureStorage _storage;
  Future<void> _lastWrite = Future.value();

  Future<List<Account>> readAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Account.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Account> add({required String apiKey}) {
    final account = Account.create(apiKey: apiKey);
    return _synchronized(() async {
      final accounts = await readAll();
      await _write([...accounts, account]);
      return account;
    });
  }

  Future<void> remove(String id) {
    return _synchronized(() async {
      final accounts = await readAll();
      await _write(accounts.where((a) => a.id != id).toList());
    });
  }

  /// Chains read-modify-write calls so two quick saves can't drop an account.
  Future<T> _synchronized<T>(Future<T> Function() action) {
    final result = _lastWrite.then((_) => action(), onError: (_) => action());
    _lastWrite = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _write(List<Account> accounts) {
    return _storage.write(
      key: _key,
      value: jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }
}
