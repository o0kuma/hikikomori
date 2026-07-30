import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_state.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _invite = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _invite.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Text('분신', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                '초대 코드로 클로즈드 베타에 참여합니다.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _invite,
                decoration: const InputDecoration(
                  labelText: '초대 코드',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: '표시 이름',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
              ),
              if (session.error != null) ...[
                const SizedBox(height: 12),
                Text(session.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const Spacer(),
              FilledButton(
                onPressed: session.loading
                    ? null
                    : () => session.signup(_invite.text.trim(), _name.text.trim()),
                child: session.loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('시작하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
