import 'user.dart';

/// Public metadata for a login attempt.
class PowChallenge {
  const PowChallenge({required this.challenge, required this.difficulty});

  factory PowChallenge.fromJson(Map<String, dynamic> json) {
    return PowChallenge(
      challenge: json['challenge'] as String,
      difficulty: json['difficulty'] as int,
    );
  }

  final String challenge;
  final int difficulty;
}

class CaptchaConfig {
  const CaptchaConfig({required this.provider, required this.siteKey});

  factory CaptchaConfig.fromJson(Map<String, dynamic> json) {
    return CaptchaConfig(
      provider: json['provider'] as String,
      siteKey: json['site_key'] as String,
    );
  }

  final String provider;
  final String siteKey;
}

/// Tokens and profile returned by login and refresh.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final String refreshToken;
  final UserProfile user;
}
