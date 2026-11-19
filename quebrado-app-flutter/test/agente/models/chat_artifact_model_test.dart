import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/models/chat_artifact_model.dart';
import 'package:quebrado_app_flutter/agente/models/daily_briefing.dart';

void main() {
  group('ArtifactType.dailyBriefing', () {
    test('se guarda como daily_briefing y se lee de vuelta', () {
      expect(ArtifactType.dailyBriefing.code, 'daily_briefing');
      expect(ArtifactType.fromString('daily_briefing'), ArtifactType.dailyBriefing);
      expect(ArtifactType.fromString('DAILY_BRIEFING'), ArtifactType.dailyBriefing);
      expect(ArtifactType.dailyBriefing.label, 'Resumen del día');
    });

    test('cada tipo hace ida y vuelta por su código', () {
      for (final type in ArtifactType.values) {
        expect(ArtifactType.fromString(type.code), type, reason: type.code);
      }
    });

    test('un código desconocido sigue cayendo en nota', () {
      expect(ArtifactType.fromString('otro'), ArtifactType.note);
      expect(ArtifactType.fromString(null), ArtifactType.note);
    });
  });

  group('ChatArtifactModel con resumen del día', () {
    test('toMap/fromMap conserva tipo y metadata del resumen', () {
      final briefing = DailyBriefing(
        generatedAt: DateTime(2026, 11, 18, 10),
        period: BriefingPeriod.morning,
        bookName: 'Libro de prueba',
        diario: const BriefingDiario(status: BriefingStatus.ready, entriesToday: 2),
      );
      final art = ChatArtifactModel(
        id: 'art-resumen',
        sessionId: 's-1',
        messageId: 'm-1',
        type: ArtifactType.dailyBriefing,
        title: 'Resumen del día',
        content: '',
        metadata: briefing.toArtifactMetadata(),
        createdAt: DateTime(2026, 11, 18, 10),
      );

      final map = art.toMap();
      expect(map['type'], 'daily_briefing');

      final back = ChatArtifactModel.fromMap(map);
      expect(back.id, 'art-resumen');
      expect(back.messageId, 'm-1');
      expect(back.type, ArtifactType.dailyBriefing);
      final read = DailyBriefing.fromArtifactMetadata(back.metadata);
      expect(read.bookName, 'Libro de prueba');
      expect(read.diario.status, BriefingStatus.ready);
      expect(read.diario.entriesToday, 2);
      expect(read.generatedAt, DateTime(2026, 11, 18, 10));
    });
  });
}
