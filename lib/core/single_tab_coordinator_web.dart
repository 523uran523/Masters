import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:web/web.dart' as web;

/// Browser-only helper for warning about other active instances.
class BrowserTabCoordinator extends ChangeNotifier {
  BrowserTabCoordinator._();

  static final BrowserTabCoordinator instance = BrowserTabCoordinator._();

  BrowserTabCoordinator? get _self => this;
  web.BroadcastChannel? _channel;
  final String _tabId =
      '${DateTime.now().microsecondsSinceEpoch}-'
      '${DateTime.now().microsecondsSinceEpoch.hashCode}';

  bool _started = false;
  bool _hasOtherActiveTabs = false;

  bool get hasOtherActiveTabs => _hasOtherActiveTabs;

  void start() {
    if (_started) return;
    _started = true;
    try {
      _channel = web.BroadcastChannel('masters-active-tabs-v1');
      _channel!.onmessage = _onMessage.toJS;
      // Announce this tab after the listener is installed.
      _channel!.postMessage({'type': 'open', 'tabId': _tabId}.jsify());
      // Best-effort cleanup on close. We do not rely on it for correctness.
      web.window.addEventListener(
        'beforeunload',
        (web.Event _) {
          try {
            _channel?.postMessage(
              {'type': 'close', 'tabId': _tabId}.jsify(),
            );
          } catch (_) {
            // ignored
          }
        }.toJS,
      );
    } catch (_) {
      // If BroadcastChannel is unavailable, keep the app working normally.
    }
  }

  void _onMessage(web.MessageEvent event) {
    try {
      final data = event.data;
      if (data is! JSObject) return;
      final dataMap = data as JSObject;
      final otherId = dataMap.getProperty('tabId'.toJS)?.toString();
      final type = dataMap.getProperty('type'.toJS)?.toString();
      if (otherId == null || otherId == _tabId) return;
      if (type == 'open' || type == 'close') {
        _hasOtherActiveTabs = (type == 'open');
        notifyListeners();
      }
    } catch (_) {
      // Ignore malformed messages from unknown pages.
    }
  }

  @override
  void dispose() {
    _channel?.close();
    super.dispose();
  }
}
