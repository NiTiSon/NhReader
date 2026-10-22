import 'dart:math';

/// A stored nhentai account.
///
/// Two kinds of credentials are supported: a [TokenAccount] API key for
/// advanced users, and a [LoggedInAccount] username/password session that
/// carries the access and refresh tokens. Secrets are kept encrypted at rest
/// by AccountsRepository.
sealed class Account {
  const Account({required this.id, this.username, this.avatarUrl});

  factory Account.fromJson(Map<String, dynamic> json) {
    // Entries written before login support have no type and are API keys.
    return switch (json['type']) {
      'loggedIn' => LoggedInAccount.fromJson(json),
      _ => TokenAccount.fromJson(json),
    };
  }

  final String id;

  /// Cached from the API so the account renders without a network round trip.
  final String? username;
  final String? avatarUrl;

  /// Display name used before (or without) a profile fetch.
  String get label;

  /// Value for the `Authorization` header. The API distinguishes API keys
  /// (`Key`) from user sessions (`User`).
  String get authHeader;

  Account withProfile({required String username, required String avatarUrl});

  Map<String, dynamic> toJson();

  static String newId() =>
      // Epoch plus randomness: ids created in the same microsecond (fast
      // taps, tests) must still be distinct.
      '${DateTime.now().microsecondsSinceEpoch}'
      '-${Random.secure().nextInt(0x7FFFFFF0).toRadixString(16)}';
}

/// An account authenticated with an API key created in nhentai's settings.
final class TokenAccount extends Account {
  const TokenAccount({
    required super.id,
    required this.apiKey,
    super.username,
    super.avatarUrl,
  });

  factory TokenAccount.create({required String apiKey}) {
    return TokenAccount(id: Account.newId(), apiKey: apiKey);
  }

  factory TokenAccount.fromJson(Map<String, dynamic> json) {
    return TokenAccount(
      id: json['id'] as String,
      apiKey: json['apiKey'] as String,
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  final String apiKey;

  @override
  String get label => username ?? maskedKey;

  @override
  String get authHeader => 'Key $apiKey';

  /// Only a tail of the key is shown; the full secret never reaches the UI.
  String get maskedKey => apiKey.length <= 4
      ? '••••'
      : 'Account ••••${apiKey.substring(apiKey.length - 4)}';

  @override
  TokenAccount withProfile({
    required String username,
    required String avatarUrl,
  }) {
    return TokenAccount(
      id: id,
      apiKey: apiKey,
      username: username,
      avatarUrl: avatarUrl,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'token',
    'id': id,
    'apiKey': apiKey,
    'username': username,
    'avatarUrl': avatarUrl,
  };
}

/// An account authenticated with a username/password login session.
final class LoggedInAccount extends Account {
  const LoggedInAccount({
    required super.id,
    required this.accessToken,
    required this.refreshToken,
    super.username,
    super.avatarUrl,
  });

  factory LoggedInAccount.create({
    required String accessToken,
    required String refreshToken,
    String? username,
    String? avatarUrl,
  }) {
    return LoggedInAccount(
      id: Account.newId(),
      accessToken: accessToken,
      refreshToken: refreshToken,
      username: username,
      avatarUrl: avatarUrl,
    );
  }

  factory LoggedInAccount.fromJson(Map<String, dynamic> json) {
    return LoggedInAccount(
      id: json['id'] as String,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  final String accessToken;
  final String refreshToken;

  @override
  String get label => username ?? 'Account';

  @override
  String get authHeader => 'User $accessToken';

  @override
  LoggedInAccount withProfile({
    required String username,
    required String avatarUrl,
  }) {
    return LoggedInAccount(
      id: id,
      accessToken: accessToken,
      refreshToken: refreshToken,
      username: username,
      avatarUrl: avatarUrl,
    );
  }

  /// Refresh rotates both tokens, so the old refresh token becomes invalid.
  LoggedInAccount withTokens({
    required String accessToken,
    required String refreshToken,
  }) {
    return LoggedInAccount(
      id: id,
      accessToken: accessToken,
      refreshToken: refreshToken,
      username: username,
      avatarUrl: avatarUrl,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'loggedIn',
    'id': id,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'username': username,
    'avatarUrl': avatarUrl,
  };
}
