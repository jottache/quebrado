import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_specs.dart';

void main() {
  final sdk = writeToolFunctionDeclarations();
  final rest = writeToolDeclarationsJson();

  test('contiene las 10 herramientas de escritura de §2.2', () {
    expect(writeToolSpecs.map((s) => s.name), [
      'registerTransaction',
      'payRecurringPayment',
      'registerDiarioEntry',
      'createContact',
      'createReminder',
      'createHabit',
      'logMood',
      'markHabitDone',
      'createNote',
      'undoLastAction',
    ]);
  });

  test('SDK y REST declaran los mismos nombres en el mismo orden', () {
    expect(rest.map((d) => d['name']).toList(), sdk.map((d) => d.name).toList());
  });

  test('SDK y REST declaran los mismos obligatorios', () {
    for (var i = 0; i < sdk.length; i++) {
      final sdkRequired = sdk[i].parameters?.requiredProperties ?? const [];
      final restRequired =
          (rest[i]['parameters'] as Map)['required'] as List? ?? const [];
      expect(restRequired, sdkRequired, reason: sdk[i].name);
    }
  });

  test('el JSON REST coincide con la serialización del SDK', () {
    for (var i = 0; i < sdk.length; i++) {
      expect(rest[i], sdk[i].toJson(), reason: sdk[i].name);
    }
  });

  test('los obligatorios son los de §2.2 (el monto no: si falta, el ejecutor pide missing)', () {
    Map<String, List<String>> required() => {
          for (final s in writeToolSpecs) s.name: s.requiredParams,
        };
    expect(required(), {
      'registerTransaction': [
        'concept',
        'type',
        'currency',
        'categoryName',
      ],
      'payRecurringPayment': ['paymentName'],
      'registerDiarioEntry': ['contentText'],
      'createContact': ['name'],
      'createReminder': ['title', 'dueAt'],
      'createHabit': ['title'],
      'logMood': ['level'],
      'markHabitDone': ['habitName'],
      'createNote': ['text'],
      'undoLastAction': <String>[],
    });
  });

  test('undoLastAction no declara obligatorios en ninguna forma', () {
    final spec = writeToolSpecByName('undoLastAction')!;
    expect(spec.requiredParams, isEmpty);
    final restDecl = rest.firstWhere((d) => d['name'] == 'undoLastAction');
    expect((restDecl['parameters'] as Map).containsKey('required'), isFalse);
  });

  test('los enums son los del contrato', () {
    List<String>? enumOf(String tool, String param) => writeToolSpecByName(tool)!
        .params
        .firstWhere((p) => p.name == param)
        .enumValues;

    expect(enumOf('registerTransaction', 'currency'), ['usd', 'ves', 'eur']);
    expect(enumOf('registerTransaction', 'type'), ['expense', 'income']);
    expect(enumOf('logMood', 'level'),
        ['muy_mal', 'mal', 'normal', 'bien', 'excelente']);
    expect(enumOf('createNote', 'kind'), ['nota', 'acuerdo']);
    expect(enumOf('createReminder', 'priority'),
        ['p1_urgent', 'p2_high', 'p3_medium', 'p4_low']);
  });

  test('la descripción de level incluye la tabla de palabras de §5', () {
    final level = writeToolSpecByName('logMood')!
        .params
        .firstWhere((p) => p.name == 'level');
    for (final word in ['fatal', 'bajoneado', 'más o menos', 'tranquilo', 'genial']) {
      expect(level.description, contains(word));
    }
  });

  test('createContact ya no declara la edad', () {
    final params =
        writeToolSpecByName('createContact')!.params.map((p) => p.name);
    expect(params, isNot(contains('age')));
  });

  test('registerTransaction acepta bookName opcional y payRecurringPayment no', () {
    List<String> params(String tool) =>
        writeToolSpecByName(tool)!.params.map((p) => p.name).toList();
    expect(params('registerTransaction'), contains('bookName'));
    expect(writeToolSpecByName('registerTransaction')!.requiredParams, isNot(contains('bookName')));
    expect(params('payRecurringPayment'), isNot(contains('bookName')));
  });

  test('writeToolSpecByName devuelve null si no existe', () {
    expect(writeToolSpecByName('proposeCreateTransaction'), isNull);
  });
}
