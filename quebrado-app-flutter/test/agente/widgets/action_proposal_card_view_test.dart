// Registro de Ortiz en el chat (spec 03, docs/design/ortiz-registra.md U2):
// resultado «Listo, registrado.» con Deshacer/Ver, «Deshecho.», ayuda tras
// recargar, tarjeta con motivos y opciones, «Ver todas» y errores.
//
// AgenteState falso (sin Supabase, SQLite ni Gemini): la tarjeta solo pinta
// la metadata; datos inventados.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quebrado_app_flutter/agente/models/chat_artifact_model.dart';
import 'package:quebrado_app_flutter/agente/models/undo_result.dart';
import 'package:quebrado_app_flutter/agente/viewmodels/agente_state.dart';
import 'package:quebrado_app_flutter/agente/widgets/action_proposal_card_view.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

import '../../helpers/pump_app.dart';

/// AgenteState mínimo: guarda el artefacto y registra las llamadas.
class _FakeAgente extends ChangeNotifier implements AgenteState {
  _FakeAgente(this.artifact);

  ChatArtifactModel artifact;
  bool undoable = true;
  UndoResult undoReply = const UndoResult.done();
  final undoCalls = <String>[];
  final confirmCalls = <Map<String, dynamic>>[];

  void setMetadata(Map<String, dynamic> metadata) {
    artifact = artifact.copyWith(metadata: metadata);
    notifyListeners();
  }

  @override
  bool canUndo(String artifactId) => undoable && artifactId == artifact.id;

  @override
  Future<UndoResult> undoAction(String undoId) async {
    undoCalls.add(undoId);
    if (undoReply.ok) {
      undoable = false;
      setMetadata({...artifact.metadata, 'status': 'undone'});
    }
    return undoReply;
  }

  @override
  Future<void> confirmProposal(String artifactId, {Map<String, dynamic> choices = const {}}) async {
    confirmCalls.add(Map.of(choices));
  }

  @override
  Future<void> rejectProposal(String artifactId) async {
    setMetadata({...artifact.metadata, 'status': 'cancelled'});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _savedMetadata({String? undoId = 'u1', String? route = '/destino', String action = 'registerTransaction'}) => {
      'status': 'saved',
      'action': action,
      'recordId': 'tx_1',
      'summary': 'Compra de prueba · Bs. 450.00 · ≈ \$1.90 · Comida · Cuenta Prueba · hoy',
      'summaryTitle': 'Compra de prueba',
      'summaryParts': [
        {'text': 'Bs. 450.00', 'kind': 'amount'},
        {'text': '≈ \$1.90', 'kind': 'amountSecondary'},
        {'text': 'Comida', 'kind': 'text'},
        {'text': 'Cuenta Prueba', 'kind': 'text'},
        {'text': 'hoy', 'kind': 'text'},
      ],
      'route': route,
      'undoId': undoId,
    };

Map<String, dynamic> _pendingMetadata({
  List<String>? options,
  List<String>? allCategories,
  String? lastError,
}) =>
    {
      'status': 'pending',
      'action': 'registerTransaction',
      'reasons': ['category_not_found'],
      'summary': 'Compra de prueba · \$10.00 · Cuenta Prueba · hoy',
      'summaryTitle': 'Compra de prueba',
      'summaryParts': [
        {'text': '\$10.00', 'kind': 'amount'},
        {'text': 'Cuenta Prueba', 'kind': 'text'},
        {'text': 'hoy', 'kind': 'text'},
      ],
      'resolved': {'accountName': 'Cuenta Prueba'},
      'options': {'categoryName': options ?? ['Comida', 'Transporte']},
      'allOptions': ?(allCategories == null ? null : {'categoryName': allCategories}),
      'commitArgs': {
        'concept': 'Compra de prueba',
        'amount': 10.0,
        'type': 'expense',
        'currency': 'usd',
        'categoryName': 'Comidita',
        'accountName': 'Cuenta Prueba',
        'date': '2026-11-18',
      },
      'lastError': ?lastError,
    };

ChatArtifactModel _artifact(Map<String, dynamic> metadata) => ChatArtifactModel(
      id: 'art_1',
      sessionId: 's1',
      type: ArtifactType.actionProposal,
      title: 'Compra de prueba',
      content: metadata['summary']?.toString() ?? '',
      metadata: metadata,
    );

Widget _host() => Consumer<AgenteState>(
      builder: (context, agente, _) => SingleChildScrollView(
        child: ActionProposalCardView(artifact: (agente as _FakeAgente).artifact),
      ),
    );

/// Como el chat: campo de texto con [chatFocus] y el mensaje dentro de
/// [ChatInputFocus].
Widget _chatHost(FocusNode chatFocus) => Column(
      children: [
        Expanded(child: ChatInputFocus(focusNode: chatFocus, child: _host())),
        TextField(focusNode: chatFocus),
      ],
    );

Future<_FakeAgente> _pump(
  WidgetTester tester,
  Map<String, dynamic> metadata, {
  WindowClass window = WindowClass.compact,
  Widget? host,
}) async {
  final agente = _FakeAgente(_artifact(metadata));
  await pumpApp(
    tester,
    host ?? _host(),
    providers: [
      ChangeNotifierProvider<AgenteState>.value(value: agente),
    ],
    window: window,
  );
  return agente;
}

Finder _button(String text) => find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );

bool _enabled(WidgetTester tester, String text) =>
    tester.widget<ButtonStyleButton>(_button(text)).onPressed != null;

void main() {
  for (final window in [WindowClass.compact, WindowClass.medium, WindowClass.expanded]) {
    testWidgets('saved muestra «Listo, registrado.», el resumen y Deshacer/Ver en ${window.name}', (tester) async {
      await _pump(tester, _savedMetadata(), window: window);

      expect(find.text('Listo, registrado.'), findsOneWidget);
      expect(find.byType(OrtizSuccessMark), findsOneWidget);
      expect(find.text('Compra de prueba'), findsOneWidget);
      expect(find.textContaining('Bs. 450.00', findRichText: true), findsOneWidget);
      expect(find.textContaining('Comida', findRichText: true), findsOneWidget);
      expect(_enabled(tester, 'Deshacer'), isTrue);
      expect(_enabled(tester, 'Ver'), isTrue);
      // No es una tarjeta: sin pastilla de estado ni Confirmar.
      expect(find.text('Confirmar'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pending con opciones: Confirmar se activa al elegir y pasa choices en ${window.name}', (tester) async {
      final agente = await _pump(tester, _pendingMetadata(), window: window);

      expect(find.text('No encontré la categoría «Comidita». Elige una:'), findsOneWidget);
      expect(find.text('Elige una categoría para confirmar.'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Comida')).selected, isFalse);
      expect(_enabled(tester, 'Confirmar'), isFalse);

      await tester.tap(find.text('Transporte'));
      await tester.pumpAndSettle();
      expect(_enabled(tester, 'Confirmar'), isTrue);
      expect(find.text('Elige una categoría para confirmar.'), findsNothing);
      expect(find.textContaining('Transporte', findRichText: true), findsWidgets);

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(agente.confirmCalls, [
        {'categoryName': 'Transporte'},
      ]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Deshacer llama a undoAction y pasa a «Deshecho.» sin Ver', (tester) async {
    final agente = await _pump(tester, _savedMetadata());

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(agente.undoCalls, ['u1']);
    expect(find.text('Deshecho.'), findsOneWidget);
    expect(find.text('Listo, registrado.'), findsNothing);
    expect(find.text('Ver'), findsNothing);
    expect(_enabled(tester, 'Deshacer'), isFalse);
    final title = tester.widget<Text>(find.text('Compra de prueba'));
    expect(title.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('si deshacer falla muestra el motivo en bad y Deshacer sigue activo', (tester) async {
    final agente = await _pump(tester, _savedMetadata());
    agente.undoReply = const UndoResult.failed('No pude deshacerlo: falló el guardado.');

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    final note = tester.widget<Text>(find.text('No pude deshacerlo: falló el guardado.'));
    expect(note.style?.color, OrtizTokens.dark.bad);
    expect(_enabled(tester, 'Deshacer'), isTrue);
  });

  testWidgets('el color del motivo sale de ok, no del texto', (tester) async {
    final agente = await _pump(tester, _savedMetadata());
    agente.undoReply = const UndoResult.failed('El registro ya no existe.');

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    final note = tester.widget<Text>(find.text('El registro ya no existe.'));
    expect(note.style?.color, OrtizTokens.dark.bad);
  });

  testWidgets('un aviso (otro libro) va en muted, no en bad (U2.3)', (tester) async {
    final agente = await _pump(tester, _savedMetadata());
    agente.undoReply = const UndoResult.notice('Cambia al libro Casa para deshacerlo.');

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    final note = tester.widget<Text>(find.text('Cambia al libro Casa para deshacerlo.'));
    expect(note.style?.color, OrtizTokens.dark.muted);
  });

  testWidgets('tras deshacer bien el foco vuelve al campo del chat', (tester) async {
    final chatFocus = FocusNode(debugLabel: 'campo del chat');
    addTearDown(chatFocus.dispose);
    await _pump(tester, _savedMetadata(), host: _chatHost(chatFocus));
    expect(chatFocus.hasFocus, isFalse);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(find.text('Deshecho.'), findsOneWidget);
    expect(chatFocus.hasFocus, isTrue);
  });

  testWidgets('si deshacer falla el foco se queda en Deshacer', (tester) async {
    final chatFocus = FocusNode(debugLabel: 'campo del chat');
    addTearDown(chatFocus.dispose);
    final agente = await _pump(tester, _savedMetadata(), host: _chatHost(chatFocus));
    agente.undoReply = const UndoResult.failed('No pude deshacerlo: falló el guardado.');

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(chatFocus.hasFocus, isFalse);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Deshacer');
  });

  testWidgets('con reducir movimiento la tarjeta pasa al resultado sin animar', (tester) async {
    final agente = await _pump(
      tester,
      _pendingMetadata(),
      host: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: _host(),
        ),
      ),
    );
    expect(find.text('Confirmar'), findsOneWidget);

    agente.setMetadata(_savedMetadata());
    await tester.pump();

    expect(find.text('Listo, registrado.'), findsOneWidget);
    expect(find.text('Confirmar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tras recargar (canUndo=false) Deshacer queda desactivado con la ayuda', (tester) async {
    final agente = _FakeAgente(_artifact(_savedMetadata()))..undoable = false;
    await pumpApp(tester, _host(), providers: [ChangeNotifierProvider<AgenteState>.value(value: agente)]);

    expect(_enabled(tester, 'Deshacer'), isFalse);
    expect(find.text('Ya no se puede deshacer desde aquí; bórralo desde la app.'), findsOneWidget);
    expect(_enabled(tester, 'Ver'), isTrue);
  });

  testWidgets('hábito ya marcado: «Ya estaba marcado.» sin Deshacer', (tester) async {
    await _pump(tester, _savedMetadata(undoId: null, action: 'markHabitDone'));

    expect(find.text('Ya estaba marcado.'), findsOneWidget);
    expect(find.text('Deshacer'), findsNothing);
    expect(find.text('Ver'), findsOneWidget);
  });

  testWidgets('Ver navega a la ruta con el router de la suite', (tester) async {
    final agente = _FakeAgente(_artifact(_savedMetadata()));
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: _host())),
      GoRoute(path: '/destino', builder: (_, _) => const Scaffold(body: Text('pantalla destino'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AgenteState>.value(
      value: agente,
      child: MaterialApp.router(theme: testAppTheme(), routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();
    expect(find.text('pantalla destino'), findsOneWidget);
  });

  testWidgets('«Ver todas» despliega la lista completa de la metadata y se puede elegir', (tester) async {
    final agente = await _pump(
      tester,
      _pendingMetadata(
        options: ['Comida'],
        allCategories: ['Comida', 'Transporte', 'Mascotas › Veterinario'],
      ),
    );

    expect(find.text('Transporte'), findsNothing);
    await tester.tap(find.text('Ver todas'));
    await tester.pumpAndSettle();

    expect(find.text('Ver todas'), findsNothing);
    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Transporte'), findsOneWidget);
    expect(find.text('Mascotas › Veterinario'), findsOneWidget);

    await tester.tap(find.text('Mascotas › Veterinario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(agente.confirmCalls.single, {'categoryName': 'Mascotas › Veterinario'});
  });

  testWidgets('sin allOptions en la metadata no ofrece «Ver todas»', (tester) async {
    await _pump(tester, _pendingMetadata(options: ['Comida']));
    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Ver todas'), findsNothing);
  });

  testWidgets('si allOptions no trae nada nuevo no ofrece «Ver todas»', (tester) async {
    await _pump(tester, _pendingMetadata(options: ['Comida'], allCategories: ['Comida']));
    expect(find.text('Ver todas'), findsNothing);
  });

  testWidgets('lastError en la tarjeta muestra el mensaje tal cual con icono de error', (tester) async {
    await _pump(tester, _pendingMetadata(lastError: 'No pude registrarlo: falló el guardado. No se guardó nada.'));

    expect(find.text('No pude registrarlo: falló el guardado. No se guardó nada.'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded));
    expect(icon.color, OrtizTokens.dark.bad);
  });

  testWidgets('status error se pinta como mensaje de Ortiz sin botones', (tester) async {
    await _pump(tester, {
      'status': 'error',
      'action': 'registerTransaction',
      'message': 'No pude registrarlo: no hay conexión con la base de datos. No se guardó nada.',
    });

    expect(find.text('No pude registrarlo: no hay conexión con la base de datos. No se guardó nada.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.text('Deshacer'), findsNothing);
    expect(find.text('Confirmar'), findsNothing);
  });

  test('proposalReasonText arma los textos de U2.4 con los datos de la tarjeta', () {
    final m = _pendingMetadata();
    expect(proposalReasonText('single_account_no_default', m).$1, 'Usé Cuenta Prueba, tu única cuenta en dólares.');
    expect(proposalReasonText('single_account_no_default', m).$2, 'Puedes fijarla como predeterminada en Ajustes.');
    expect(proposalReasonText('future_date', m).$1, 'La fecha es 18/11/2026, en el futuro.');
    expect(proposalReasonText('amount_not_in_user_text', m).$1, r'El monto $10.00 no salió de tu mensaje. Revísalo.');
    final mismatch = {
      ...m,
      'resolved': {'accountName': 'Cuenta Prueba', 'accountCurrency': 'ves'},
    };
    expect(
      proposalReasonText('account_currency_mismatch', mismatch).$1,
      'Cuenta Prueba es una cuenta en bolívares, no en dólares.',
    );
    // Sin la moneda de la cuenta en la metadata: versión genérica.
    expect(
      proposalReasonText('account_currency_mismatch', m).$1,
      'Cuenta Prueba no es una cuenta en dólares.',
    );
  });

  test('other_book nombra el libro de la tarjeta y avisa que no cambia el abierto', () {
    final m = _pendingMetadata();
    final conLibro = {
      ...m,
      'resolved': {'bookName': 'Libro B'},
    };
    expect(proposalReasonText('other_book', conLibro).$1, 'Es del libro Libro B, no del que tienes abierto.');
    expect(proposalReasonText('other_book', conLibro).$2, 'Se guarda allí sin cambiar el libro abierto.');
    final soloArgs = {
      ...m,
      'resolved': const <String, dynamic>{},
      'commitArgs': {'profileName': 'Libro C'},
    };
    expect(proposalReasonText('other_book', soloArgs).$1, 'Es del libro Libro C, no del que tienes abierto.');
  });

  test('account_contains_match dice lo entendido solo si lo pedido difiere', () {
    final m = _pendingMetadata();
    Map<String, dynamic> withAsked(String? asked) => {
          ...m,
          'resolved': {'accountName': 'Cuenta Prueba', 'requestedAccountName': ?asked},
        };
    expect(proposalReasonText('account_contains_match', withAsked('prueba')).$1, 'Entendí «prueba» como Cuenta Prueba.');
    const fallback = 'Usé Cuenta Prueba, la más parecida al nombre que dijiste.';
    expect(proposalReasonText('account_contains_match', withAsked('cuenta prueba')).$1, fallback);
    expect(proposalReasonText('account_contains_match', withAsked(null)).$1, fallback);
  });

  test('name_not_in_user_text nombra lo resuelto o cae a la versión genérica', () {
    final habit = {
      'action': 'markHabitDone',
      'resolved': {'habit': 'Leer'},
      'commitArgs': {'habitName': 'lectura'},
    };
    expect(proposalReasonText('name_not_in_user_text', habit).$1, 'No mencionaste «Leer»; confírmalo para registrarlo.');
    final contact = {
      'action': 'registerDiarioEntry',
      'commitArgs': {'contactName': 'Ana Prueba'},
    };
    expect(proposalReasonText('name_not_in_user_text', contact).$1, 'No mencionaste «Ana Prueba»; confírmalo para registrarlo.');
    expect(
      proposalReasonText('name_not_in_user_text', const {'action': 'payRecurringPayment'}).$1,
      'No mencionaste ese nombre; confírmalo para registrarlo.',
    );
  });
}
