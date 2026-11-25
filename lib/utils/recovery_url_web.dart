import 'package:web/web.dart' as web;

/// Remove the consumed recovery URL without navigating away.
void clearRecoveryUrl() {
  web.window.history.replaceState(null, '', '/');
}
