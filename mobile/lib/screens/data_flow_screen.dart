import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_state.dart';
import '../theme/app_theme.dart';

/// Shows what stays on-device vs what may leave the device (roadmap B / privacy).
class DataFlowScreen extends StatelessWidget {
  const DataFlowScreen({super.key});

  Widget _section(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glassFill(theme.brightness),
        borderRadius: BorderRadius.circular(AppTheme.rPanel),
        border: Border.all(color: AppTheme.glassBorder(theme.brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final theme = Theme.of(context);
    final samples = session.styleExamples;

    return Scaffold(
      appBar: AppBar(title: const Text('데이터 흐름')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            context,
            title: '기기 안에만 둡니다',
            body: '말투 샘플·온보딩 입력은 이 기기의 로컬 저장소에만 보관합니다. '
                '원문 대화 전체를 서버로 올리지 않는 것이 기본 원칙입니다.',
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.glassFill(theme.brightness),
              borderRadius: BorderRadius.circular(AppTheme.rPanel),
              border: Border.all(color: AppTheme.glassBorder(theme.brightness)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('말투 샘플 ${samples.length}개', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  [
                    samples.isEmpty ? '(아직 없음 — 말투 샘플 화면에서 추가)' : samples.take(3).join(' · '),
                    session.localDbEncrypted
                        ? '저장: drift + SQLCipher(암호화)'
                        : '저장: 메모리/웹 스텁(이 환경에 SQLCipher 없음 — Chrome·Linux 폴백)',
                  ].join('\n'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          _section(
            context,
            title: '서버로 보낼 수 있는 것',
            body: '초안이 필요할 때: 최근 대화 몇 줄 + 말투 샘플 일부(최소 컨텍스트)\n'
                '채팅 릴레이: 보낸 메시지 본문\n'
                '계정: 표시 이름·초대 코드·세션 토큰\n'
                '푸시: Firebase 연결 시 실 FCM 토큰 등록 · 미연결 시 install 플레이스홀더 (docs/fcm-setup.md)',
          ),
          _section(
            context,
            title: '보내지 않는 것',
            body: '전체 채팅 백업 업로드, 온디바이스 말투 학습 원문 코퍼스, '
                '관계 메모의 자동 클라우드 분석',
          ),
        ],
      ),
    );
  }
}
