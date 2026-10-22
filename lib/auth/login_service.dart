import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/nhentai_api.dart';
import '../settings/account.dart';
import '../settings/accounts_repository.dart';
import '../settings/settings_providers.dart';
import 'proof_of_work.dart';

class LoginException implements Exception {
  const LoginException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The user dismissed the captcha dialog; not an error worth showing.
class LoginCancelled implements Exception {
  const LoginCancelled();
}

/// Orchestrates the username/password login: fetch the challenges, let the
/// caller show the captcha widget, solve the proof of work, then exchange the
/// credentials for tokens.
class LoginService {
  LoginService({required this.api, required this.accounts});

  final NhentaiApi api;
  final AccountsRepository accounts;

  Future<Account> login({
    required String username,
    required String password,
    required Future<String?> Function(String siteKey) solveCaptcha,
  }) async {
    try {
      final pow = await api.pow('login');
      final captcha = await api.captcha();
      // nhentai's own web client treats an empty site key as dev mode.
      final captchaResponse = captcha.siteKey.isEmpty
          ? 'dev-bypass'
          : await solveCaptcha(captcha.siteKey);
      if (captchaResponse == null) throw const LoginCancelled();

      final nonce = await Isolate.run(
        () => solveProofOfWork(pow.challenge, pow.difficulty),
      );
      final session = await api.login(
        username: username,
        password: password,
        powChallenge: pow.challenge,
        powNonce: nonce,
        captchaResponse: captchaResponse,
      );
      return await accounts.addSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        username: session.user.username,
        avatarUrl: session.user.avatarUrl,
      );
    } on LoginCancelled {
      rethrow;
    } catch (error) {
      throw LoginException(_message(error));
    }
  }
}

final loginServiceProvider = Provider<LoginService>(
  (ref) => LoginService(
    api: NhentaiApi(),
    accounts: ref.watch(accountsProvider),
  ),
);

String _message(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    return switch (error.response?.statusCode) {
      401 => 'Incorrect username or password',
      429 => 'Too many attempts, try again later',
      _ => 'Login failed, check your connection',
    };
  }
  return 'Login failed, check your connection';
}
