import 'dart:async';

import 'package:flutter/services.dart';
import '../logging/app_log.dart';

/// Deep link parse result
final class DeepLinkData {
  final String? server;
  final String? session;
  final String? window;
  final int? pane;

  const DeepLinkData({
    this.server,
    this.session,
    this.window,
    this.pane,
  });

  bool get hasTarget => server != null;

  @override
  String toString() =>
      'DeepLinkData(server: $server, session: $session, window: $window, pane: $pane)';
}

/// Service for handling deep links from the `muxpod://` URL scheme
///
/// URL format: `muxpod://connect?server=id&session=name&window=name&pane=index`
final class DeepLinkService {
  static const _tag = 'DeepLinkService';
  static const _channel = MethodChannel('com.muxpod.app/deeplink');

  final _linkController = StreamController<DeepLinkData>.broadcast();

  Stream<DeepLinkData> get linkStream => _linkController.stream;

  DeepLinkData? _initialLink;
  DeepLinkData? get initialLink => _initialLink;

  bool _initialized = false;

  /// Initialize. Handles both cold-start links and hot links.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Receive deep links from native via MethodChannel
    _channel.setMethodCallHandler(_handleMethodCall);

    // Get initial link on cold start
    try {
      final initialUri = await _channel.invokeMethod<String>('getInitialLink');
      if (initialUri != null) {
        final data = parseUri(initialUri);
        if (data.hasTarget) {
          _initialLink = data;
          AppLog.d('Initial deep link: $data', tag: _tag);
        }
      }
    } on MissingPluginException {
      // Platform channel not implemented (e.g., during tests)
      AppLog.d('Deep link channel not available', tag: _tag);
    } catch (e) {
      AppLog.d('Error getting initial link: $e', tag: _tag);
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onDeepLink') {
      final uri = call.arguments as String?;
      if (uri != null) {
        final data = parseUri(uri);
        if (data.hasTarget) {
          AppLog.d('Hot deep link received: $data', tag: _tag);
          _linkController.add(data);
        }
      }
    }
  }

  /// Parse URI string to DeepLinkData
  static DeepLinkData parseUri(String uriString) {
    try {
      final uri = Uri.parse(uriString);

      // Only accept muxpod://connect?... format
      if (uri.scheme != 'muxpod') {
        return const DeepLinkData();
      }

      final server = uri.queryParameters['server'];
      final session = uri.queryParameters['session'];
      final window = uri.queryParameters['window'];
      final paneStr = uri.queryParameters['pane'];
      final pane = paneStr != null ? int.tryParse(paneStr) : null;

      return DeepLinkData(
        server: server,
        session: session,
        window: window,
        pane: pane,
      );
    } catch (e) {
      AppLog.d('Failed to parse deep link URI: $e', tag: _tag);
      return const DeepLinkData();
    }
  }

  void dispose() {
    _linkController.close();
  }
}
