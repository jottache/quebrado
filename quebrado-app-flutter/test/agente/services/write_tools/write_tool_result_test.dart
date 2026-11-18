import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_result.dart';

void main() {
  group('WriteToolResult.toJson', () {
    test('saved lleva recordId, summary, route y undoId', () {
      final json = WriteToolResult.saved(
        action: 'registerTransaction',
        recordId: 'tx-1',
        summary: 'Gasto de 20,00 USD en Gasolina',
        route: '/quebrado/transactions/tx-1',
        undoId: 'u-1',
      ).toJson();

      expect(json, {
        'status': 'saved',
        'action': 'registerTransaction',
        'recordId': 'tx-1',
        'summary': 'Gasto de 20,00 USD en Gasolina',
        'route': '/quebrado/transactions/tx-1',
        'undoId': 'u-1',
      });
    });

    test('saved sin undoId lo omite (ya estaba marcado)', () {
      final json = WriteToolResult.saved(
        action: 'markHabitDone',
        recordId: 'h-1',
        summary: 'Ya estaba marcado',
      ).toJson();

      expect(json.containsKey('undoId'), isFalse);
      expect(json.containsKey('route'), isFalse);
      expect(json['status'], 'saved');
    });

    test('proposal lleva reasons, summary y las opciones para elegir', () {
      final json = WriteToolResult.proposal(
        action: 'registerTransaction',
        reasons: ['category_not_found'],
        summary: 'Gasto de 5 USD',
        options: {
          'category': ['Comida', 'Transporte', 'Salud'],
        },
      ).toJson();

      expect(json['status'], 'proposal');
      expect(json['reasons'], ['category_not_found']);
      expect(json['summary'], 'Gasto de 5 USD');
      expect(json['options'], {
        'category': ['Comida', 'Transporte', 'Salud'],
      });
      expect(json.containsKey('recordId'), isFalse);
      expect(json.containsKey('missing'), isFalse);
    });

    test('missing lleva missing, resolved y options', () {
      final json = WriteToolResult.missing(
        action: 'registerTransaction',
        missing: ['account'],
        resolved: {'category': 'Comida'},
        options: {
          'account': ['Banesco Bs', 'Mercantil Bs'],
        },
      ).toJson();

      expect(json, {
        'status': 'missing',
        'action': 'registerTransaction',
        'missing': ['account'],
        'resolved': {'category': 'Comida'},
        'options': {
          'account': ['Banesco Bs', 'Mercantil Bs'],
        },
      });
    });

    test('error solo lleva el mensaje', () {
      final json = WriteToolResult.error(
        action: 'undoLastAction',
        message: 'No hay nada que deshacer en esta conversación',
      ).toJson();

      expect(json, {
        'status': 'error',
        'action': 'undoLastAction',
        'message': 'No hay nada que deshacer en esta conversación',
      });
    });
  });

  group('WriteToolStatus.worst', () {
    test('ordena error > missing > proposal > saved', () {
      expect(WriteToolStatus.saved.worst(WriteToolStatus.proposal),
          WriteToolStatus.proposal);
      expect(WriteToolStatus.proposal.worst(WriteToolStatus.missing),
          WriteToolStatus.missing);
      expect(WriteToolStatus.missing.worst(WriteToolStatus.error),
          WriteToolStatus.error);
      expect(WriteToolStatus.error.worst(WriteToolStatus.saved),
          WriteToolStatus.error);
      expect(WriteToolStatus.missing.worst(WriteToolStatus.proposal),
          WriteToolStatus.missing);
    });
  });

  group('WriteToolResult.combine', () {
    test('missing gana a proposal y se juntan motivos, faltantes y opciones', () {
      final combined = WriteToolResult.combine([
        WriteToolResult.proposal(
          action: 'registerTransaction',
          reasons: ['category_not_found'],
          options: {
            'category': ['Comida', 'Salud', 'Hogar'],
          },
        ),
        WriteToolResult.missing(
          action: 'registerTransaction',
          missing: ['amount'],
          resolved: {'currency': 'usd'},
        ),
        WriteToolResult.missing(
          action: 'registerTransaction',
          missing: ['account', 'amount'],
          options: {
            'account': ['Zelle', 'Efectivo USD'],
          },
        ),
      ]);

      expect(combined.status, WriteToolStatus.missing);
      expect(combined.action, 'registerTransaction');
      expect(combined.missing, ['amount', 'account']);
      expect(combined.reasons, ['category_not_found']);
      expect(combined.resolved, {'currency': 'usd'});
      expect(combined.options.keys, ['category', 'account']);
    });

    test('error gana a todo y conserva su mensaje', () {
      final combined = WriteToolResult.combine([
        WriteToolResult.missing(action: 'markHabitDone', missing: ['date']),
        WriteToolResult.error(
          action: 'markHabitDone',
          message: 'No encontré el hábito «Correr».',
        ),
        WriteToolResult.proposal(
            action: 'markHabitDone', reasons: ['future_date']),
      ]);

      expect(combined.status, WriteToolStatus.error);
      expect(combined.message, 'No encontré el hábito «Correr».');
      expect(combined.toJson().keys, ['status', 'action', 'message']);
    });

    test('proposal gana a saved', () {
      final combined = WriteToolResult.combine([
        WriteToolResult.saved(
            action: 'logMood', recordId: 'm-1', summary: 'Ánimo: Bien'),
        WriteToolResult.proposal(action: 'logMood', reasons: ['future_date']),
      ]);

      expect(combined.status, WriteToolStatus.proposal);
      expect(combined.summary, 'Ánimo: Bien');
      expect(combined.reasons, ['future_date']);
    });

    test('rechaza una lista vacía', () {
      expect(() => WriteToolResult.combine(const []), throwsArgumentError);
    });
  });
}
