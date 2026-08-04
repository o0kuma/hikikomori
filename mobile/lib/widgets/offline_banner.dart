import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'web_connectivity.dart';

/// Thin bar when the browser reports offline (docs/web-upgrade.md N4-W5).
/// API/WS still require a network — this only sets expectation.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _offline = false;
  StreamSubscription? _onlineSub;
  StreamSubscription? _offlineSub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    _offline = webNavigatorOffline;
    _onlineSub = listenWebOnline(() {
      if (mounted) setState(() => _offline = false);
    });
    _offlineSub = listenWebOffline(() {
      if (mounted) setState(() => _offline = true);
    });
  }

  @override
  void dispose() {
    _onlineSub?.cancel();
    _offlineSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_offline) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          '오프라인입니다. 메시지·로그인에는 인터넷 연결이 필요합니다.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}
