import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/conversation_list_screen.dart';
import 'screens/onboarding_tone_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/splash_screen.dart';
import 'state/session_state.dart';
import 'theme/app_theme.dart';
import 'widgets/gradient_backdrop.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
    return true;
  };

  runApp(const _Bootstrap());
}

/// Shows [SplashScreen] while [SessionState.restore] is in flight, then
/// swaps to the real app. Runs `runApp` immediately (rather than awaiting
/// restore() first) so the branded splash actually paints instead of
/// leaving a blank frame during the async gap. Falls back to a readable
/// error screen if restore fails or hangs, rather than crashing silently.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  SessionState? _session;
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final session = SessionState();
      await session.restore().timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() => _session = session);
    } catch (e, st) {
      debugPrint('BOOT FAIL: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e;
        _stackTrace = st;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText('앱 시작 실패\n\n$error\n\n${_stackTrace ?? ''}'),
            ),
          ),
        ),
      );
    }

    final session = _session;
    if (session == null) {
      return MaterialApp(
        title: '와카뷰',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        builder: (context, child) => GradientBackdrop(child: child),
        home: const SplashScreen(),
      );
    }
    return YkavuApp(session: session);
  }
}

class YkavuApp extends StatelessWidget {
  const YkavuApp({super.key, required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: session,
      child: MaterialApp(
        title: '와카뷰',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        builder: (context, child) => GradientBackdrop(child: child),
        home: Consumer<SessionState>(
          builder: (context, s, _) {
            if (s.user == null) return const SignupScreen();
            if (!s.toneOnboardingDone) return const OnboardingToneScreen();
            return const ConversationListScreen();
          },
        ),
      ),
    );
  }
}
