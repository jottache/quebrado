import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/models/agent_action_record.dart';

void main() {
  test('AgentActionRecord guarda sus datos y empieza sin deshacer', () {
    final at = DateTime(2026, 11, 18, 10);
    final record = AgentActionRecord(
      undoId: 'u-1',
      sessionId: 's-1',
      artifactId: 'a-1',
      toolName: 'registerTransaction',
      undoPayload: const {'kind': 'transaction', 'transactionId': 't-1'},
      profileId: 'libro-prueba.db',
      createdAt: at,
    );

    expect(record.undoId, 'u-1');
    expect(record.sessionId, 's-1');
    expect(record.artifactId, 'a-1');
    expect(record.toolName, 'registerTransaction');
    expect(record.undoPayload['transactionId'], 't-1');
    expect(record.profileId, 'libro-prueba.db');
    expect(record.createdAt, at);
    expect(record.undone, isFalse);

    record.undone = true;
    expect(record.undone, isTrue);
  });

  test('sin fecha usa la hora actual y el libro es opcional', () {
    final before = DateTime.now();
    final record = AgentActionRecord(
      undoId: 'u-2',
      sessionId: 's-1',
      artifactId: 'a-2',
      toolName: 'logMood',
      undoPayload: const {'logId': 'm-1'},
    );
    expect(record.profileId, isNull);
    expect(record.createdAt.isBefore(before), isFalse);
  });
}
