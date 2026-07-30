import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/conversation_list_screen.dart';
import 'screens/onboarding_tone_screen.dart';
import 'screens/signup_screen.dart';
import 'state/session_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
    return true;
  };

  try {
    final session = SessionState();
    await session.restore().timeout(const Duration(seconds: 8));
    runApp(BunsinApp(session: session));
  } catch (e, st) {
    debugPrint('BOOT FAIL: $e\n$st');
    runApp(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText('앱 시작 실패\n\n$e\n\n$st'),
            ),
          ),
        ),
      ),
    );
  }
}

class BunsinApp extends StatelessWidget {
  const BunsinApp({super.key, required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: session,
      child: MaterialApp(
        title: '분신',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        // Twin Shadow phase-1: light only (dark kept in AppTheme for later).
        themeMode: ThemeMode.light,
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
