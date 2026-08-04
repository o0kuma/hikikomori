import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_state.dart';

/// One-time dismissible tips for the web demo/preview surface (N4-W2).
///
/// Hidden on non-web builds. Dismissal is stored in the local DB KV so it
/// survives hard refresh after W1.
class WebPreviewBanner extends StatefulWidget {
  const WebPreviewBanner({super.key});

  static const dismissKvKey = 'web_preview_tips_dismissed';

  @override
  State<WebPreviewBanner> createState() => _WebPreviewBannerState();
}

class _WebPreviewBannerState extends State<WebPreviewBanner> {
  bool _visible = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    } else {
      _loaded = true;
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    final session = context.read<SessionState>();
    final db = session.db;
    final dismissed = db == null
        ? false
        : await db.getBoolKv(WebPreviewBanner.dismissKvKey);
    if (!mounted) return;
    setState(() {
      _visible = !dismissed;
      _loaded = true;
    });
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    final db = context.read<SessionState>().db;
    await db?.setBoolKv(WebPreviewBanner.dismissKvKey, true);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_loaded || !_visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.web_asset, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '웹 프리뷰입니다. 말투·설정은 새로고침 후에도 이 브라우저에 남습니다. '
                '브라우저 알림·홈 화면 추가는 곧 이어집니다.',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
            ),
            IconButton(
              tooltip: '닫기',
              onPressed: _dismiss,
              icon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
