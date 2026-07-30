import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/conversation_list_screen.dart';
import 'screens/onboarding_tone_screen.dart';
import 'screens/signup_screen.dart';
import 'state/session_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionState();
  await session.restore();
  runApp(BunsinApp(session: session));
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
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
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
