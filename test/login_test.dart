import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nh_reader/api/auth.dart';
import 'package:nh_reader/api/nhentai_api.dart';
import 'package:nh_reader/api/user.dart';
import 'package:nh_reader/auth/login_service.dart';
import 'package:nh_reader/auth/proof_of_work.dart';
import 'package:nh_reader/settings/account.dart';
import 'package:nh_reader/settings/accounts_repository.dart';

class _FakeApi extends NhentaiApi {
  String? lastNonce;
  String? lastCaptcha;

  @override
  Future<PowChallenge> pow(String action) async {
    return const PowChallenge(challenge: 'test', difficulty: 8);
  }

  @override
  Future<CaptchaConfig> captcha() async {
    return const CaptchaConfig(provider: 'turnstile', siteKey: 'site-key');
  }

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
    required String powChallenge,
    required String powNonce,
    required String captchaResponse,
  }) async {
    lastNonce = powNonce;
    lastCaptcha = captchaResponse;
    return const AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      user: UserProfile(
        username: 'Alice',
        avatarUrl: 'https://i.nhentai.net/avatars/alice.png',
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('proof of work matches the reference nonces', () {
    expect(solveProofOfWork('test', 8), '304');
    expect(solveProofOfWork('nhreader-pow-test', 12), '4180');
  });

  test('login stores a session account and sends the challenges', () async {
    final api = _FakeApi();
    final repo = AccountsRepository(const FlutterSecureStorage());
    final service = LoginService(api: api, accounts: repo);
    String? siteKey;

    final account = await service.login(
      username: 'alice',
      password: 'secret',
      solveCaptcha: (key) async {
        siteKey = key;
        return 'captcha-token';
      },
    );

    expect(siteKey, 'site-key');
    expect(api.lastNonce, '304');
    expect(api.lastCaptcha, 'captcha-token');
    expect(account, isA<LoggedInAccount>());

    final stored = (await repo.readAll()).single as LoggedInAccount;
    expect(stored.accessToken, 'access');
    expect(stored.refreshToken, 'refresh');
    expect(stored.authHeader, 'User access');
    expect(stored.username, 'Alice');
    expect(stored.avatarUrl, 'https://i.nhentai.net/avatars/alice.png');
    expect(stored.label, 'Alice');
  });

  test('cancelling the captcha leaves no account behind', () async {
    final repo = AccountsRepository(const FlutterSecureStorage());
    final service = LoginService(api: _FakeApi(), accounts: repo);

    await expectLater(
      service.login(
        username: 'alice',
        password: 'secret',
        solveCaptcha: (_) async => null,
      ),
      throwsA(isA<LoginCancelled>()),
    );
    expect(await repo.readAll(), isEmpty);
  });
}
