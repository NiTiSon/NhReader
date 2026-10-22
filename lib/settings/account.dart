import 'dart:math';

/// A stored nhentai account: a display label plus its API key.
///
/// The API key is a secret; accounts are persisted through
/// AccountsRepository, which keeps them encrypted at rest.
class Account {
  const Account({
    required this.id,
    required this.apiKey,
    this.username,
    this.avatarUrl,
  });

  factory Account.create({required String apiKey}) {
    return Account(
      // Epoch plus randomness: ids created in the same microsecond (fast
      // taps, tests) must still be distinct.
      id:
          '${DateTime.now().microsecondsSinceEpoch}'
          '-${Random.secure().nextInt(0x7FFFFFF0).toRadixString(16)}',
      apiKey: apiKey,
    );
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      apiKey: json['apiKey'] as String,
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  final String id;
  final String apiKey;

  /// Cached from the API so the account renders without a network round trip.
  final String? username;
  final String? avatarUrl;

  /// Copy carrying the fetched profile, ready to be persisted by the
  /// repository.
  Account withProfile({required String username, required String avatarUrl}) {
    return Account(
      id: id,
      apiKey: apiKey,
      username: username,
      avatarUrl: avatarUrl,
    );
  }

  /// Display label for the account selector. Accounts have no username, so
  /// only a tail of the key is shown; the full secret never reaches the UI.
  String get maskedKey => apiKey.length <= 4
      ? '••••'
      : 'Account ••••${apiKey.substring(apiKey.length - 4)}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'apiKey': apiKey,
    'username': username,
    'avatarUrl': avatarUrl,
  };
}
