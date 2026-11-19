import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_contract.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_result.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/animo_state.dart';
import 'package:quebrado_app_flutter/diario/viewmodels/diario_state.dart';
import 'package:quebrado_app_flutter/diario/models/diario_contact.dart';
import 'package:quebrado_app_flutter/habitos/viewmodels/habitos_state.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/recordatorios/viewmodels/reminders_state.dart';

/// Llamada registrada por [FakeWriteHandler].
class WriteCall {
  final String toolName;
  final Map<String, dynamic> args;
  final WriteContext ctx;
  WriteCall(this.toolName, this.args, this.ctx);
}

/// Ejecutor de escritura falso. Por defecto imita la regla del contrato:
/// motivos forzados del contexto o monto no escrito por la persona →
/// `proposal`; si no, `saved` con un `undoPayload`.
class FakeWriteHandler implements WriteToolHandler {
  @override
  final Set<String> toolNames;
  final List<WriteCall> calls = [];
  final List<String> undone = [];
  Object? undoError;
  WriteOutcome Function(String toolName, Map<String, dynamic> args, WriteContext ctx)? onExecute;

  FakeWriteHandler(this.toolNames, {this.onExecute});

  @override
  Future<WriteOutcome> execute(String toolName, Map<String, dynamic> args, WriteContext ctx) async {
    calls.add(WriteCall(toolName, args, ctx));
    final custom = onExecute;
    if (custom != null) return custom(toolName, args, ctx);
    final reasons = [...ctx.forcedProposalReasons];
    final amount = args['amount'];
    if (amount is num && !ctx.confirmedByUser && !ctx.amountInUserText(amount)) {
      reasons.add('amount_not_in_user_text');
    }
    if (reasons.isNotEmpty && !ctx.confirmedByUser) {
      return WriteOutcome(
        WriteToolResult.proposal(action: toolName, reasons: reasons, summary: 'Resumen propuesto'),
        summaryTitle: 'Título propuesto',
        summaryParts: const [SummaryPart('Bs. 450.00', SummaryPartKind.amount)],
        commitArgs: Map<String, dynamic>.from(args),
      );
    }
    return WriteOutcome(
      WriteToolResult.saved(
        action: toolName,
        recordId: 'rec-${calls.length}',
        summary: 'Resumen guardado',
        route: '/ruta/rec-${calls.length}',
      ),
      summaryTitle: 'Título guardado',
      summaryParts: const [SummaryPart('Comida')],
      undoPayload: {'recordId': 'rec-${calls.length}', 'contactId': 'c-${calls.length}'},
      profileId: 'libro-1',
    );
  }

  @override
  Future<void> undo(String toolName, Map<String, dynamic> undoPayload) async {
    final error = undoError;
    if (error != null) throw error;
    undone.add(undoPayload['recordId'] as String);
  }
}

class FakeAppState extends Fake implements AppState {}

class FakeHabitosState extends Fake implements HabitosState {}

class FakeRemindersState extends Fake implements RemindersState {}

class FakeDiarioState extends Fake implements DiarioState {
  @override
  List<DiarioContact> get contacts => const [];
}

class FakeAnimoState extends Fake implements AnimoState {
  final List<String> removedContacts = [];

  @override
  void removeLogsForContact(String contactId) => removedContacts.add(contactId);
}
