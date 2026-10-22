import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Shows the Cloudflare Turnstile widget required by nhentai's login API.
///
/// Resolves with the captcha token, or null when the user cancels. The page is
/// loaded with nhentai's base URL because Turnstile validates the site key
/// against the page's hostname.
Future<String?> showTurnstileDialog(BuildContext context, String siteKey) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TurnstileDialog(siteKey: siteKey),
  );
}

class _TurnstileDialog extends StatefulWidget {
  const _TurnstileDialog({required this.siteKey});

  final String siteKey;

  @override
  State<_TurnstileDialog> createState() => _TurnstileDialogState();
}

class _TurnstileDialogState extends State<_TurnstileDialog> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = WebViewController();
      // Android blocks third-party cookies by default; Turnstile needs them
      // for its challenges.cloudflare.com iframe.
      try {
        final platform = controller.platform;
        final cookies = WebViewCookieManager().platform;
        if (platform is AndroidWebViewController &&
            cookies is AndroidWebViewCookieManager) {
          await cookies.setAcceptThirdPartyCookies(platform, true);
        }
      } catch (_) {
        // The setting improves captcha reliability but isn't required to show
        // the widget; don't fail the whole login over it.
      }
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel('Turnstile', onMessageReceived: _onMessage)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
          ),
        )
        ..loadHtmlString(
          _html(widget.siteKey),
          baseUrl: 'https://nhentai.net/',
        );
      if (mounted) setState(() => _controller = controller);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't start the verification widget";
        _loading = false;
      });
    }
  }

  void _onMessage(JavaScriptMessage message) {
    if (!mounted) return;
    final value = message.message;
    if (value.startsWith('error:')) {
      setState(() {
        _loading = false;
        _error = 'Verification failed (${value.substring(6)})';
      });
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text("Verify you're human"),
      content: SizedBox(
        width: 300,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_controller != null)
              WebViewWidget(controller: _controller!),
            if (_loading) const CircularProgressIndicator(),
            if (_error != null)
              Text(_error!, textAlign: TextAlign.center),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

String _html(String siteKey) => '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    html, body {
      margin: 0;
      height: 100%;
      background: #141414;
      color: #eeeeee;
      font-family: sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
    }
  </style>
</head>
<body>
  <div id="widget"></div>
  <script>
    function fail(message) {
      Turnstile.postMessage('error:' + message);
    }
    function onTurnstileLoad() {
      try {
        turnstile.render('#widget', {
          sitekey: ${jsonEncode(siteKey)},
          theme: 'dark',
          callback: function (token) { Turnstile.postMessage(token); },
          'error-callback': function (code) { fail(String(code)); },
          'expired-callback': function () { fail('expired'); }
        });
      } catch (e) {
        fail(e.message || 'render');
      }
    }
  </script>
  <script
    src="https://challenges.cloudflare.com/turnstile/v0/api.js?onload=onTurnstileLoad&render=explicit"
    async defer></script>
</body>
</html>
''';
