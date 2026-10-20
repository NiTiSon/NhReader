import 'dart:math';

/// A stored nhentai account: a display label plus its API key.
///
/// The API key is a secret; accounts are persisted through
/// AccountsRepository, which keeps them encrypted at rest.
class Account {
  const Account({
    required this.id,
    required this.apiKey,
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
    );
  }

  final String id;
  final String apiKey;

  Map<String, dynamic> toJson() => {'id': id, 'apiKey': apiKey};
}
