import 'package:flutter/foundation.dart' show ChangeNotifier;

/// Android/iOS: there is no multi-tab runtime, so this is always safe.
class BrowserTabCoordinator extends ChangeNotifier {
  BrowserTabCoordinator._();

  static final BrowserTabCoordinator instance = BrowserTabCoordinator._();

  bool get hasOtherActiveTabs => false;

  void start() {}
}
