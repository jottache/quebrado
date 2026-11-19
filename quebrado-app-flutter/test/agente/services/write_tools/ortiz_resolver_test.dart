import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/services/write_tools/ortiz_resolver.dart';
import 'package:quebrado_app_flutter/quebrado/models/currency_type.dart';

ResolverItem _item(String id, String name, {String? label}) =>
    ResolverItem(id: id, name: name, label: label);

ResolverAccount _acc(String id, String name, CurrencyType currency) =>
    ResolverAccount(id: id, name: name, currency: currency);

void main() {
  group('norm', () {
    test('quita espacios, mayúsculas, acentos y puntuación final', () {
      expect(norm('  Café   Público.  '), 'cafe publico');
      expect(norm('ÉXITO!!'), 'exito');
      expect(norm('Pingüino?'), 'pinguino');
    });

    test('conserva la ñ', () {
      expect(norm('Señora PEÑA'), 'señora peña');
    });

    test('no quita la puntuación interior', () {
      expect(norm('Padre › Hija'), 'padre › hija');
      expect(norm('Bs. BCV'), 'bs. bcv');
    });
  });

  group('currencyFromParam', () {
    test('usd, ves y eur con mapa explícito', () {
      expect(currencyFromParam('usd'), CurrencyType.usd);
      expect(currencyFromParam('ves'), CurrencyType.bsBCV);
      expect(currencyFromParam('EUR'), CurrencyType.eur);
    });

    test('bs, bolívares y bolivares son ves', () {
      expect(currencyFromParam('bs'), CurrencyType.bsBCV);
      expect(currencyFromParam('Bs.'), CurrencyType.bsBCV);
      expect(currencyFromParam('bolívares'), CurrencyType.bsBCV);
      expect(currencyFromParam('bolivares'), CurrencyType.bsBCV);
    });

    test('devuelve null si no es una moneda válida', () {
      expect(currencyFromParam('yen'), isNull);
      expect(currencyFromParam(''), isNull);
      expect(currencyFromParam(null), isNull);
    });

    test('currencyParam es el inverso', () {
      for (final c in CurrencyType.values) {
        expect(currencyFromParam(currencyParam(c)), c);
      }
    });
  });

  group('resolveCategory', () {
    final categories = [
      _item('c1', 'Comida'),
      _item('c2', 'Transporte'),
      _item('c3', 'Gasolina y peajes', label: 'Transporte › Gasolina y peajes'),
      _item('c4', 'Salud'),
      _item('c5', 'Hogar'),
    ];

    test('una coincidencia exacta queda resuelta', () {
      final r = resolveCategory('comída', categories);
      expect(r.status, ResolutionStatus.resolved);
      expect(r.value?.id, 'c1');
    });

    test('dos coincidencias exactas son ambiguas', () {
      final r = resolveCategory('Comida', [
        ...categories,
        _item('c6', 'Comida', label: 'Hogar › Comida'),
      ]);
      expect(r.status, ResolutionStatus.proposal);
      expect(r.reasons, ['category_ambiguous']);
      expect(r.options, ['Comida', 'Hogar › Comida']);
      expect(r.value, isNull);
    });

    test('sin coincidencia propone las 3 más parecidas', () {
      final r = resolveCategory('gasolina', categories);
      expect(r.status, ResolutionStatus.proposal);
      expect(r.reasons, ['category_not_found']);
      expect(r.candidates, hasLength(3));
      expect(r.options.first, 'Transporte › Gasolina y peajes');
    });

    test('las más parecidas son deterministas y respetan el orden en empate',
        () {
      final a = resolveCategory('xyz', categories).options;
      final b = resolveCategory('xyz', categories).options;
      expect(a, b);
      expect(
        mostSimilar('zz', [_item('1', 'aa'), _item('2', 'bb'), _item('3', 'cc')])
            .map((i) => i.id),
        ['1', '2', '3'],
      );
    });

    test('con menos de 3 categorías devuelve todas', () {
      final r = resolveCategory('ropa', [_item('c1', 'Comida')]);
      expect(r.options, ['Comida']);
    });
  });

  group('nameSimilarity', () {
    test('las palabras compartidas pesan más que nombres sin relación', () {
      expect(nameSimilarity('pago movil', 'Pago móvil Banesco'),
          greaterThan(nameSimilarity('pago movil', 'Hogar')));
      expect(nameSimilarity('Salud', 'salud'), 1);
    });
  });

  group('resolveAccount', () {
    final accounts = [
      _acc('a1', 'Banesco Bs', CurrencyType.bsBCV),
      _acc('a2', 'Mercantil Bs', CurrencyType.bsBCV),
      _acc('a3', 'Zelle', CurrencyType.usd),
      _acc('a4', 'Revolut', CurrencyType.eur),
    ];

    test('nombre exacto de la misma moneda queda resuelta', () {
      final r = resolveAccount(
          requestedName: 'zelle', currency: CurrencyType.usd, accounts: accounts);
      expect(r.status, ResolutionStatus.resolved);
      expect(r.value?.id, 'a3');
    });

    test('nombre exacto de otra moneda es propuesta por moneda distinta', () {
      final r = resolveAccount(
          requestedName: 'Zelle',
          currency: CurrencyType.bsBCV,
          accounts: accounts);
      expect(r.status, ResolutionStatus.proposal);
      expect(r.reasons, ['account_currency_mismatch']);
      expect(r.value?.id, 'a3');
    });

    test('una sola que contiene el nombre es propuesta', () {
      final r = resolveAccount(
          requestedName: 'banesco',
          currency: CurrencyType.bsBCV,
          accounts: accounts);
      expect(r.status, ResolutionStatus.proposal);
      expect(r.reasons, ['account_contains_match']);
      expect(r.value?.id, 'a1');
    });

    test('contiene el nombre pero en otra moneda suma los dos motivos', () {
      final r = resolveAccount(
          requestedName: 'banesco',
          currency: CurrencyType.usd,
          accounts: accounts);
      expect(r.reasons,
          ['account_contains_match', 'account_currency_mismatch']);
    });

    test('varias que contienen el nombre piden elegir entre las de la moneda',
        () {
      final r = resolveAccount(
          requestedName: 'bs', currency: CurrencyType.bsBCV, accounts: accounts);
      expect(r.status, ResolutionStatus.missing);
      expect(r.options, ['Banesco Bs', 'Mercantil Bs']);
    });

    test('nombre desconocido pide elegir entre las de la moneda', () {
      final r = resolveAccount(
          requestedName: 'Provincial',
          currency: CurrencyType.usd,
          accounts: accounts);
      expect(r.status, ResolutionStatus.missing);
      expect(r.options, ['Zelle']);
    });

    test('sin nombre usa la predeterminada válida', () {
      final r = resolveAccount(
          currency: CurrencyType.bsBCV,
          accounts: accounts,
          defaultAccountId: 'a2');
      expect(r.status, ResolutionStatus.resolved);
      expect(r.value?.id, 'a2');
    });

    test('una predeterminada de otra moneda no vale', () {
      final r = resolveAccount(
          currency: CurrencyType.bsBCV,
          accounts: accounts,
          defaultAccountId: 'a3');
      expect(r.status, ResolutionStatus.missing);
      expect(r.options, ['Banesco Bs', 'Mercantil Bs']);
    });

    test('sin predeterminada y una sola cuenta en la moneda es tarjeta (PA-04)',
        () {
      final r = resolveAccount(currency: CurrencyType.usd, accounts: accounts);
      expect(r.status, ResolutionStatus.proposal);
      expect(r.reasons, ['single_account_no_default']);
      expect(r.value?.id, 'a3');
    });

    test('sin predeterminada y varias cuentas pide elegir (CA-03)', () {
      final r =
          resolveAccount(currency: CurrencyType.bsBCV, accounts: accounts);
      expect(r.status, ResolutionStatus.missing);
      expect(r.reasons, isEmpty);
      expect(r.options, ['Banesco Bs', 'Mercantil Bs']);
    });

    test('sin cuentas en la moneda ofrece todas con aviso', () {
      final r = resolveAccount(
          currency: CurrencyType.eur,
          accounts: accounts.where((a) => a.id != 'a4').toList());
      expect(r.status, ResolutionStatus.missing);
      expect(r.reasons, ['no_account_in_currency']);
      expect(r.options, ['Banesco Bs', 'Mercantil Bs', 'Zelle']);
    });

    test('nombre en blanco se trata como ausente', () {
      final r = resolveAccount(
          requestedName: '  ',
          currency: CurrencyType.usd,
          accounts: accounts,
          defaultAccountId: 'a3');
      expect(r.status, ResolutionStatus.resolved);
    });
  });

  group('resolveByName', () {
    final payments = [
      _item('p1', 'Internet Cantv'),
      _item('p2', 'Alquiler'),
      _item('p3', 'Seguro del carro'),
      _item('p4', 'Seguro médico'),
    ];

    test('coincidencia exacta queda resuelta', () {
      final r = resolveByName('alquiler', payments);
      expect(r.status, ResolutionStatus.resolved);
      expect(r.value?.id, 'p2');
    });

    test('una sola que contiene el término queda resuelta (CA-06)', () {
      final r = resolveByName('internet', payments);
      expect(r.status, ResolutionStatus.resolved);
      expect(r.value?.id, 'p1');
    });

    test('un término que contiene el nombre queda resuelto', () {
      final r = resolveByName('el alquiler de noviembre', payments);
      expect(r.status, ResolutionStatus.resolved);
      expect(r.value?.id, 'p2');
    });

    test('varias parciales piden elegir', () {
      final r = resolveByName('seguro', payments);
      expect(r.status, ResolutionStatus.missing);
      expect(r.options, ['Seguro del carro', 'Seguro médico']);
    });

    test('varias exactas piden elegir', () {
      final r = resolveByName('Leer', [_item('h1', 'Leer'), _item('h2', 'leer')]);
      expect(r.status, ResolutionStatus.missing);
      expect(r.candidates.map((c) => c.id), ['h1', 'h2']);
    });

    test('sin coincidencias es not_found con los existentes', () {
      final r = resolveByName('gimnasio', payments);
      expect(r.status, ResolutionStatus.notFound);
      expect(r.reasons, ['not_found']);
      expect(r.candidates, hasLength(4));
    });

    test('término vacío pide el dato', () {
      expect(resolveByName(' ', payments).status, ResolutionStatus.missing);
    });
  });

  group('resolveDate', () {
    DateTime now() => DateTime(2026, 11, 18, 23, 30);

    test('sin fecha usa hoy a medianoche', () {
      final r = resolveDate(null, now: now);
      expect(r.date, DateTime(2026, 11, 18));
      expect(r.usedToday, isTrue);
      expect(r.isFuture, isFalse);
      expect(resolveDate('  ', now: now).usedToday, isTrue);
    });

    test('fecha válida pasada se respeta', () {
      final r = resolveDate('2026-11-17', now: now);
      expect(r.date, DateTime(2026, 11, 17));
      expect(r.usedToday, isFalse);
      expect(r.isFuture, isFalse);
      expect(r.isInvalid, isFalse);
    });

    test('hoy explícito no es futuro', () {
      expect(resolveDate('2026-11-18', now: now).isFuture, isFalse);
    });

    test('mañana es futura', () {
      final r = resolveDate('2026-11-19', now: now);
      expect(r.isFuture, isTrue);
      expect(r.date, DateTime(2026, 11, 19));
    });

    test('fechas imposibles u otros formatos son inválidas', () {
      for (final raw in ['2026-02-30', 'ayer', '18/11/2026', '2026-13-01']) {
        final r = resolveDate(raw, now: now);
        expect(r.isInvalid, isTrue, reason: raw);
        expect(r.date, isNull, reason: raw);
      }
    });
  });

  group('nameWordInText (S3-02)', () {
    test('ancla por una palabra de 4+ letras escrita como palabra', () {
      expect(nameWordInText('Internet Cantv', 'ya pagué el Internet'), isTrue);
      expect(nameWordInText('Alquiler', 'hola'), isFalse);
      expect(nameWordInText('Pago del gas', 'del gas'), isFalse, reason: 'palabras cortas no anclan');
      expect(nameWordInText(null, 'hola'), isFalse);
    });

    test('con verbForms acepta el infinitivo conjugado, no palabras con la misma raíz', () {
      expect(nameWordInText('Leer', 'ya leí hoy', verbForms: true), isTrue);
      expect(nameWordInText('Correr', 'corrí 5 km', verbForms: true), isTrue);
      expect(nameWordInText('Leer', 'ya leí hoy'), isFalse, reason: 'sin verbForms');
      expect(nameWordInText('Leer', 'les dije que compré leche', verbForms: true), isFalse);
      // Solo la forma exacta raíz+e/i: palabras comunes con la misma raíz no anclan.
      expect(nameWordInText('Nadar', 'nadé 20 minutos', verbForms: true), isTrue);
      expect(nameWordInText('Nadar', 'no hice nada', verbForms: true), isFalse);
      expect(nameWordInText('Comer sano', '¿cómo voy?', verbForms: true), isFalse);
      expect(nameWordInText('Correr', 'revisa mi correo', verbForms: true), isFalse);
      expect(nameWordInText('Caminar', 'voy camino a casa', verbForms: true), isFalse);
      expect(nameWordInText('Ahorrar', 'mi ahorro del mes', verbForms: true), isFalse);
      expect(nameWordInText('Estudiar', 'estoy en el estudio', verbForms: true), isFalse);
      expect(nameWordInText('Caminar', 'hoy caminé', verbForms: true), isTrue);
    });
  });
}
