import 'dart:async';

bool get webNavigatorOffline => false;

StreamSubscription<void>? listenWebOnline(void Function() onOnline) => null;

StreamSubscription<void>? listenWebOffline(void Function() onOffline) => null;
