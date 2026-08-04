import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

bool get webNavigatorOffline => !(html.window.navigator.onLine ?? true);

StreamSubscription<void>? listenWebOnline(void Function() onOnline) {
  return html.window.onOnline.listen((_) => onOnline());
}

StreamSubscription<void>? listenWebOffline(void Function() onOffline) {
  return html.window.onOffline.listen((_) => onOffline());
}
