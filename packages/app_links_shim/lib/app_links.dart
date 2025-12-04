// Minimal shim for the `app_links` package used by the app.
// This provides a safe no-op implementation so the app can build in
// environments where the real `app_links` package is incompatible.

import 'dart:async';

/// Minimal surface of the AppLinks class used in the app.
class AppLinks {
  AppLinks();

  /// Returns the initial deep-link Uri if present. Shim returns null.
  Future<Uri?> getInitialLink() async => null;

  /// Same as above (some versions call this name).
  Future<Uri?> getInitialAppLink() async => null;

  /// Alternative name used in some releases.
  Future<Uri?> getInitialAppLinkUri() async => null;

  /// Stream of incoming URIs. Shim provides an empty stream.
  Stream<Uri> get uriLinkStream => const Stream<Uri>.empty();
}
