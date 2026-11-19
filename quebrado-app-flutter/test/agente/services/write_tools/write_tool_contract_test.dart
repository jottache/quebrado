import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/write_tool_contract.dart';

void main() {
  group('WriteContext.amountInUserText', () {
    test('encuentra el monto escrito por la persona en varios formatos', () {
      final ctx = WriteContext(userText: 'registra un gasto\n450');
      expect(ctx.amountInUserText(450), isTrue);
      expect(WriteContext(userText: 'fueron 1.200 Bs').amountInUserText(1200), isTrue);
      expect(WriteContext(userText: 'gasté 12,50 dólares').amountInUserText(12.5), isTrue);
      expect(WriteContext(userText: 'gasté 12.5 dólares').amountInUserText(12.5), isTrue);
      expect(WriteContext(userText: 'pagué 20.').amountInUserText(20), isTrue);
    });

    test('no acepta un monto que la persona no escribió', () {
      final ctx = WriteContext(userText: 'registra un cartón de huevos');
      expect(ctx.amountInUserText(450), isFalse);
      expect(WriteContext(userText: 'compré 45 huevos').amountInUserText(450), isFalse);
      expect(WriteContext(userText: '').amountInUserText(0), isFalse);
    });

    test('compara valores, no dígitos: 1,90 no vale por 19 ni 4.5 por 45', () {
      expect(WriteContext(userText: 'fueron 1,90').amountInUserText(19), isFalse);
      expect(WriteContext(userText: 'fueron 1,90').amountInUserText(1.9), isTrue);
      expect(WriteContext(userText: 'pagué 4.5').amountInUserText(45), isFalse);
      expect(WriteContext(userText: 'pagué 4.5').amountInUserText(4.5), isTrue);
      expect(WriteContext(userText: '12.50 dólares').amountInUserText(1250), isFalse);
    });

    test('acepta las dos lecturas de un número con separadores', () {
      final ctx = WriteContext(userText: 'Bs 1.200');
      expect(ctx.amountInUserText(1200), isTrue);
      expect(ctx.amountInUserText(1.2), isTrue);
      expect(WriteContext(userText: '1.200,50').amountInUserText(1200.5), isTrue);
      expect(WriteContext(userText: '1,200.50').amountInUserText(1200.5), isTrue);
      expect(WriteContext(userText: '12.345.678').amountInUserText(12345678), isTrue);
      // «12.34» no es agrupación de miles válida.
      expect(WriteContext(userText: '12.34').amountInUserText(1234), isFalse);
    });
  });

  group('WriteContext.termInUserText (S3-02)', () {
    test('ancla el nombre solo si la persona lo escribió', () {
      final ctx = WriteContext(userText: 'Ya pagué el Internet');
      expect(ctx.termInUserText('internet'), isTrue);
      expect(ctx.termInUserText('Intérnet'), isTrue);
      expect(ctx.termInUserText('alquiler'), isFalse);
      expect(WriteContext(userText: 'hola').termInUserText('paga el alquiler'),
          isFalse);
    });

    test('compara palabras enteras, no trozos de otra palabra', () {
      expect(WriteContext(userText: 'nos vemos la otra semana').termInUserText('Ana'),
          isFalse);
      expect(WriteContext(userText: 'mañana sin falta').termInUserText('Ana'), isFalse);
      expect(WriteContext(userText: 'mis gastos del mes').termInUserText('Gas'), isFalse);
      expect(WriteContext(userText: 'hablé con Ana hoy').termInUserText('ana'), isTrue);
      expect(WriteContext(userText: 'pagué el gas.').termInUserText('Gas'), isTrue);
      expect(WriteContext(userText: 'pagué internet cantv').termInUserText('Internet Cantv'),
          isTrue);
      expect(WriteContext(userText: 'cantv e internet').termInUserText('Internet Cantv'),
          isFalse);
    });

    test('términos vacíos o muy cortos no anclan', () {
      final ctx = WriteContext(userText: 'ya leí hoy');
      expect(ctx.termInUserText(null), isFalse);
      expect(ctx.termInUserText(''), isFalse);
      expect(ctx.termInUserText('le'), isFalse);
      expect(ctx.termInUserText('leí'), isTrue);
    });
  });

  group('WriteContext.forcedProposalReasons', () {
    test('lectura de texto libre y segunda escritura obligan a tarjeta', () {
      expect(WriteContext().forcedProposalReasons, isEmpty);
      expect(WriteContext(untrustedRead: true).forcedProposalReasons,
          ['read_untrusted_text']);
      expect(WriteContext(directWriteDone: true).forcedProposalReasons,
          ['multiple_writes']);
    });

    test('al confirmar la persona no se fuerza tarjeta', () {
      final ctx = WriteContext(untrustedRead: true, directWriteDone: true)
          .copyWith(confirmedByUser: true);
      expect(ctx.forcedProposalReasons, isEmpty);
      expect(ctx.untrustedRead, isTrue);
    });

    test('copyWith conserva texto y reloj', () {
      final fixed = DateTime(2026, 11, 18);
      final ctx = WriteContext(userText: 'hola', now: () => fixed)
          .copyWith(directWriteDone: true);
      expect(ctx.userText, 'hola');
      expect(ctx.now(), fixed);
      expect(ctx.directWriteDone, isTrue);
    });
  });

  test('SummaryPart ida y vuelta por JSON', () {
    const part = SummaryPart('Bs. 450.00', SummaryPartKind.amount);
    final back = SummaryPart.fromJson(part.toJson());
    expect(back.text, 'Bs. 450.00');
    expect(back.kind, SummaryPartKind.amount);
    expect(SummaryPart.fromJson({'text': 'x', 'kind': 'raro'}).kind,
        SummaryPartKind.text);
  });
}
