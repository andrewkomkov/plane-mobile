import 'package:flutter/material.dart';
import '../../utils/say.dart';
import '../../widgets/m3e/app_bar.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Opens Plane login in a WebView with a Chrome user agent to bypass
/// Google's disallowed_useragent. After login, auto-creates an API token.
class WebViewLoginScreen extends StatefulWidget {
  final String baseUrl;
  const WebViewLoginScreen({super.key, required this.baseUrl});

  @override
  State<WebViewLoginScreen> createState() => _WebViewLoginScreenState();
}

class _WebViewLoginScreenState extends State<WebViewLoginScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _extracting = false;

  // Chrome user agent — Google allows OAuth from Chrome but not WebView
  static const _chromeUA =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.6778.200 Mobile Safari/537.36';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_chromeUA)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (url) {
          if (mounted) setState(() => _loading = false);
          debugPrint('[LOGIN] Page finished: $url');
          // After login, Plane redirects to dashboard (not /sign-in or oauth pages)
          if (_isLoggedInPage(url)) {
            debugPrint('[LOGIN] Detected logged-in page, extracting token...');
            _tryExtractToken();
          }
        },
      ))
      ..loadRequest(Uri.parse('${widget.baseUrl}/sign-in/'));

    // Poll for login state since SPA may not trigger onPageFinished
    _pollForLogin();
  }

  Future<void> _pollForLogin() async {
    while (mounted && !_extracting) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || _extracting) return;
      try {
        final url = await _controller.currentUrl();
        if (url != null && _isLoggedInPage(url)) {
          debugPrint('[LOGIN] Poll detected logged-in URL: $url');
          _tryExtractToken();
          return;
        }
      } catch (_) {}
    }
  }

  bool _isLoggedInPage(String url) {
    final uri = Uri.parse(url);
    final base = Uri.parse(widget.baseUrl);
    if (uri.host != base.host) return false;
    final path = uri.path.toLowerCase();
    if (path.contains('sign-in') ||
        path.contains('sign-up') ||
        path.contains('accounts.google') ||
        path.contains('/auth/')) {
      return false;
    }
    return true;
  }

  Future<void> _tryExtractToken() async {
    if (_extracting) return;
    _extracting = true;

    try {
      // Step 1: Verify we're actually logged in
      final authCheck = await _runJS('''
        (async () => {
          const r = await fetch('/api/users/me/', {credentials:'include'});
          return r.ok ? 'OK' : 'FAIL';
        })()
      ''');

      if (authCheck != 'OK') {
        _extracting = false;
        return;
      }

      if (mounted) {
        setState(() => _loading = true);
      }

      // Step 2: Try to create API token
      final tokenResult = await _runJS('''
        (async () => {
          try {
            const r = await fetch('/api/users/me/api-tokens/', {
              method: 'POST',
              credentials: 'include',
              headers: {'Content-Type':'application/json'},
              body: JSON.stringify({label:'Plane Mobile', description:'Auto-created'})
            });
            if (r.ok || r.status === 201) {
              const d = await r.json();
              if (d.token) return d.token;
              const vals = Object.values(d);
              for (const v of vals) {
                if (typeof v === 'string' && v.startsWith('plane_api_')) return v;
              }
              return JSON.stringify(d);
            }
            return 'FAIL:' + r.status;
          } catch(e) { return 'ERR:' + e.message; }
        })()
      ''');

      if (tokenResult.startsWith('plane_api_')) {
        if (mounted) Navigator.pop(context, 'apitoken:$tokenResult');
        return;
      }

      // Step 3: Try v1 API endpoint
      final v1Result = await _runJS('''
        (async () => {
          try {
            const r = await fetch('/api/v1/users/me/api-tokens/', {
              method: 'POST',
              credentials: 'include',
              headers: {'Content-Type':'application/json'},
              body: JSON.stringify({label:'Plane Mobile', description:'Auto-created'})
            });
            if (r.ok || r.status === 201) {
              const d = await r.json();
              return JSON.stringify(d);
            }
            return 'FAIL:' + r.status;
          } catch(e) { return 'ERR:' + e.message; }
        })()
      ''');

      final tokenMatch = RegExp(r'plane_api_[a-f0-9]+').firstMatch(v1Result);
      if (tokenMatch != null && mounted) {
        Navigator.pop(context, 'apitoken:${tokenMatch.group(0)}');
        return;
      }

      // Step 4: If nothing works, tell the user.
      //
      // There used to be a session-cookie fallback here that scraped
      // `document.cookie` and popped `session:<id>`. It could not have
      // produced anything: Plane's session cookie is named "session-id", not
      // "sessionid", and it is HttpOnly, so `document.cookie` never contains
      // it. Nothing parsed the `session:` prefix either — the only credential
      // this screen can usefully return is an `apitoken:`. Falling through to
      // the message below is the honest outcome; popping a value no caller
      // reads just closed the screen with no token and no explanation.
      _extracting = false;
      if (mounted) {
        setState(() => _loading = false);
        say(context, 'Logged in! Tap the checkmark to continue.');
      }
    } catch (e) {
      _extracting = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _runJS(String code) async {
    final result = await _controller.runJavaScriptReturningResult(code);
    return result.toString().replaceAll('"', '').replaceAll("'", '');
  }

  void _manualContinue() async {
    setState(() => _loading = true);
    _extracting = false;
    await _tryExtractToken();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: M3EAppBar(
        title: 'Sign In',
        leading: M3EAppBarAction(
          icon: Icons.close,
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          M3EAppBarAction(
            icon: Icons.check_circle_outline,
            tooltip: 'Done',
            emphasized: true,
            onPressed: _manualContinue,
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          // Named, or the only indication that the sign-in page is still
          // loading is a moving bar — silent to a screen reader, and nothing
          // for `adb_drive.py` to wait on.
          if (_loading)
            const LinearProgressIndicator(
                semanticsLabel: 'Loading sign-in page'),
        ],
      ),
    );
  }
}
