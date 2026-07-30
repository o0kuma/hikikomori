import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_state.dart';

/// Shows what stays on-device vs what may leave the device (roadmap B / privacy).
class DataFlowScreen extends StatelessWidget {
  const DataFlowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final theme = Theme.of(context);
    final samples = session.styleExamples;

    return Scaffold(
      appBar: AppBar(title: const Text('데이터 흐름')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('기기 안에만 둡니다', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            '말투 샘플·온보딩 입력은 이 기기의 로컬 저장소에만 보관합니다. '
            '원문 대화 전체를 서버로 올리지 않는 것이 기본 원칙입니다.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: Text('말투 샘플 ${samples.length}개'),
              subtitle: Text(
                [
                  samples.isEmpty ? '(아직 없음 — 말투 샘플 화면에서 추가)' : samples.take(3).join(' · '),
                  session.localDbEncrypted
                      ? '저장: drift + SQLCipher(암호화)'
                      : '저장: 메모리/웹 스텁(이 환경에 SQLCipher 없음 — Chrome·Linux 폴백)',
                ].join('\n'),
              ),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 24),
          Text('서버로 보낼 수 있는 것', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            '초안이 필요할 때: 최근 대화 몇 줄 + 말투 샘플 일부(최소 컨텍스트).\n'
            '채팅 릴레이: 보낸 메시지 본문.\n'
            '계정: 표시 이름·초대 코드·세션 토큰.\n'
            '푸시(준비 중): 디바이스 토큰만 등록, 실제 전송은 FCM 프로젝트 연결 후.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Text('보내지 않는 것', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            '전체 채팅 백업 업로드, 온디바이스 말투 학습 원문 코퍼스, '
            '관계 메모의 자동 클라우드 분석.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
