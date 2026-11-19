/// Regla «resuelto o dudoso» (C17) como funciones puras
/// (`docs/design/ortiz-registra.md` §3).
///
/// No depende de AppState ni de ningún ViewModel: los ejecutores le pasan
/// las listas ya filtradas (por tipo, por libro activo, solo activos…).
library;

import '../../../quebrado/models/currency_type.dart';

// ---------------------------------------------------------------------------
// Normalización
// ---------------------------------------------------------------------------

const Map<String, String> _accents = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ç': 'c',
};

final RegExp _spaces = RegExp(r'\s+');
final RegExp _trailingPunctuation = RegExp(r'[\s.,;:!?¡¿…"»«)\]]+$');

/// Normaliza un nombre para comparar: `trim`, minúsculas, sin acentos
/// (la ñ se conserva), espacios repetidos a uno y sin puntuación final.
/// «Coincidencia exacta» = `norm(a) == norm(b)`.
String norm(String s) {
  final lower = s.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_accents[ch] ?? ch);
  }
  return buffer
      .toString()
      .replaceAll(_spaces, ' ')
      .replaceFirst(_trailingPunctuation, '')
      .trim();
}

// ---------------------------------------------------------------------------
// Moneda
// ---------------------------------------------------------------------------

const Map<String, CurrencyType> _currencyByParam = {
  'usd': CurrencyType.usd,
  'ves': CurrencyType.bsBCV,
  'bs': CurrencyType.bsBCV,
  'bolivares': CurrencyType.bsBCV,
  'eur': CurrencyType.eur,
};

/// Mapa explícito del parámetro `currency` (`usd`/`ves`/`eur`, y también
/// «bs», «bolívares», «bolivares» como `ves`) a [CurrencyType].
/// Devuelve `null` si no es una moneda válida (→ `missing: [currency]`).
/// No usa `CurrencyType.fromString`, que con `'ves'` devuelve usd.
CurrencyType? currencyFromParam(String? raw) {
  if (raw == null) return null;
  return _currencyByParam[norm(raw)];
}

/// Inverso de [currencyFromParam]: `usd`, `ves` o `eur`.
String currencyParam(CurrencyType currency) => switch (currency) {
      CurrencyType.usd => 'usd',
      CurrencyType.bsBCV => 'ves',
      CurrencyType.eur => 'eur',
    };

// ---------------------------------------------------------------------------
// Tipos de entrada y salida
// ---------------------------------------------------------------------------

/// Elemento que se puede resolver por nombre (categoría, hábito, pago,
/// contacto…). `label` es lo que se muestra en `options` (p. ej.
/// «Padre › Hija»); si falta, se usa `name`.
class ResolverItem {
  final String id;
  final String name;
  final String? label;

  const ResolverItem({required this.id, required this.name, this.label});

  String get displayName => label ?? name;

  @override
  String toString() => 'ResolverItem($id, $name)';
}

/// Cuenta del libro activo con su moneda.
class ResolverAccount extends ResolverItem {
  final CurrencyType currency;

  const ResolverAccount({
    required super.id,
    required super.name,
    required this.currency,
    super.label,
  });
}

enum ResolutionStatus {
  /// Resuelto sin dudas.
  resolved,

  /// Resuelto con dudas (tarjeta). `value` puede venir o no.
  proposal,

  /// Hay que preguntar o elegir: `candidates` son las opciones.
  missing,

  /// No existe nada parecido: `candidates` son todos los existentes.
  notFound,
}

/// Motivos (`reasons`) que devuelve el resolutor.
abstract final class ResolverReason {
  static const categoryAmbiguous = 'category_ambiguous';
  static const categoryNotFound = 'category_not_found';
  static const accountContainsMatch = 'account_contains_match';
  static const accountCurrencyMismatch = 'account_currency_mismatch';
  static const singleAccountNoDefault = 'single_account_no_default';
  static const noAccountInCurrency = 'no_account_in_currency';
  static const notFound = 'not_found';
}

class Resolution<T extends ResolverItem> {
  final ResolutionStatus status;

  /// Elemento elegido (en `resolved` siempre; en `proposal` si hay uno).
  final T? value;

  /// Motivos de `proposal`/`notFound`, o avisos de `missing`.
  final List<String> reasons;

  /// Opciones para elegir (missing), las más parecidas (categoría no
  /// encontrada), las coincidencias (categoría ambigua) o los existentes
  /// (notFound).
  final List<T> candidates;

  const Resolution._(
    this.status, {
    this.value,
    this.reasons = const [],
    this.candidates = const [],
  });

  bool get isResolved => status == ResolutionStatus.resolved;

  /// Nombres para `options` en la respuesta al modelo.
  List<String> get options => candidates.map((c) => c.displayName).toList();

  @override
  String toString() =>
      'Resolution($status, value: $value, reasons: $reasons, options: $options)';
}

// ---------------------------------------------------------------------------
// Similitud (para «las 3 categorías más parecidas»)
// ---------------------------------------------------------------------------

/// Similitud determinista entre 0 y 1 sobre `norm`: media de la proporción
/// de palabras compartidas y de la similitud por distancia de edición.
double nameSimilarity(String a, String b) {
  final na = norm(a);
  final nb = norm(b);
  if (na.isEmpty && nb.isEmpty) return 1;
  if (na.isEmpty || nb.isEmpty) return 0;
  final ta = na.split(' ').toSet();
  final tb = nb.split(' ').toSet();
  final shared = ta.intersection(tb).length;
  final tokenScore = shared / (ta.length > tb.length ? ta.length : tb.length);
  final maxLen = na.length > nb.length ? na.length : nb.length;
  final editScore = 1 - _levenshtein(na, nb) / maxLen;
  return (tokenScore + editScore) / 2;
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    current[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final deletion = previous[j] + 1;
      final insertion = current[j - 1] + 1;
      final substitution = previous[j - 1] + cost;
      var best = deletion < insertion ? deletion : insertion;
      if (substitution < best) best = substitution;
      current[j] = best;
    }
    previous = current;
  }
  return previous[b.length];
}

/// Los [limit] elementos más parecidos a [term], de mayor a menor
/// similitud; en empate, el orden original de [items].
List<T> mostSimilar<T extends ResolverItem>(
  String term,
  List<T> items, {
  int limit = 3,
}) {
  final scored = [
    for (var i = 0; i < items.length; i++)
      (index: i, item: items[i], score: nameSimilarity(term, items[i].name)),
  ];
  scored.sort((x, y) {
    final byScore = y.score.compareTo(x.score);
    return byScore != 0 ? byScore : x.index.compareTo(y.index);
  });
  return scored.take(limit).map((s) => s.item).toList();
}

List<T> _exactMatches<T extends ResolverItem>(String term, List<T> items) {
  final t = norm(term);
  return items.where((i) => norm(i.name) == t).toList();
}

// ---------------------------------------------------------------------------
// Categoría (§3.3)
// ---------------------------------------------------------------------------

/// Resuelve la categoría pedida entre [categories], que el ejecutor pasa ya
/// filtradas por tipo (sin «Cambio de Divisa», con subcategorías).
///
/// - 1 coincidencia exacta → `resolved`.
/// - 2 o más → `proposal` (`category_ambiguous`), `candidates` = coincidencias.
/// - 0 → `proposal` (`category_not_found`), `candidates` = las 3 más parecidas.
Resolution<T> resolveCategory<T extends ResolverItem>(
  String name,
  List<T> categories,
) {
  final exact = _exactMatches(name, categories);
  if (exact.length == 1) {
    return Resolution._(ResolutionStatus.resolved, value: exact.first);
  }
  if (exact.length > 1) {
    return Resolution._(
      ResolutionStatus.proposal,
      reasons: const [ResolverReason.categoryAmbiguous],
      candidates: exact,
    );
  }
  return Resolution._(
    ResolutionStatus.proposal,
    reasons: const [ResolverReason.categoryNotFound],
    candidates: mostSimilar(name, categories),
  );
}

// ---------------------------------------------------------------------------
// Cuenta (§3.4, con PA-04 = tarjeta)
// ---------------------------------------------------------------------------

/// Resuelve la cuenta para [currency] entre las [accounts] del libro activo.
///
/// Con [requestedName]:
/// - 1 exacta de la misma moneda → `resolved`; de otra moneda → `proposal`
///   (`account_currency_mismatch`).
/// - 0 exactas y 1 sola cuyo nombre contiene el pedido → `proposal`
///   (`account_contains_match`, más `account_currency_mismatch` si aplica).
/// - Resto → `missing` con las cuentas de esa moneda (todas si no hay).
///
/// Sin [requestedName]:
/// - [defaultAccountId] existente y de esa moneda → `resolved`.
/// - 0 cuentas en la moneda → `missing` con todas (`no_account_in_currency`).
/// - 1 cuenta → `proposal` (`single_account_no_default`, PA-04).
/// - 2 o más → `missing` con las de esa moneda.
Resolution<ResolverAccount> resolveAccount({
  String? requestedName,
  required CurrencyType currency,
  required List<ResolverAccount> accounts,
  String? defaultAccountId,
}) {
  final inCurrency = accounts.where((a) => a.currency == currency).toList();

  Resolution<ResolverAccount> askToChoose() {
    if (inCurrency.isEmpty) {
      return Resolution._(
        ResolutionStatus.missing,
        reasons: const [ResolverReason.noAccountInCurrency],
        candidates: List.of(accounts),
      );
    }
    return Resolution._(ResolutionStatus.missing, candidates: inCurrency);
  }

  final requested = requestedName == null ? '' : norm(requestedName);
  if (requested.isNotEmpty) {
    final exact = _exactMatches(requested, accounts);
    if (exact.length == 1) {
      final account = exact.first;
      if (account.currency == currency) {
        return Resolution._(ResolutionStatus.resolved, value: account);
      }
      return Resolution._(
        ResolutionStatus.proposal,
        value: account,
        reasons: const [ResolverReason.accountCurrencyMismatch],
      );
    }
    if (exact.isEmpty) {
      final containing =
          accounts.where((a) => norm(a.name).contains(requested)).toList();
      if (containing.length == 1) {
        final account = containing.first;
        return Resolution._(
          ResolutionStatus.proposal,
          value: account,
          reasons: [
            ResolverReason.accountContainsMatch,
            if (account.currency != currency)
              ResolverReason.accountCurrencyMismatch,
          ],
        );
      }
    }
    return askToChoose();
  }

  if (defaultAccountId != null) {
    for (final account in inCurrency) {
      if (account.id == defaultAccountId) {
        return Resolution._(ResolutionStatus.resolved, value: account);
      }
    }
  }
  if (inCurrency.length == 1) {
    return Resolution._(
      ResolutionStatus.proposal,
      value: inCurrency.first,
      reasons: const [ResolverReason.singleAccountNoDefault],
    );
  }
  return askToChoose();
}

// ---------------------------------------------------------------------------
// Hábito / pago recurrente / contacto (§3.5)
// ---------------------------------------------------------------------------

/// Resuelve por nombre entre [items] (ya filtrados: activos, del libro…).
///
/// - 1 coincidencia exacta → `resolved`.
/// - 2 o más exactas → `missing` con esas.
/// - 0 exactas: 1 sola cuyo nombre contiene el término o está contenido en
///   él → `resolved` (CA-06: «internet» → «Internet Cantv»); 2 o más →
///   `missing` con esas.
/// - Nada → `notFound` (`not_found`) con todos los existentes.
///
/// Un término vacío devuelve `missing` con todos los existentes.
Resolution<T> resolveByName<T extends ResolverItem>(String term, List<T> items) {
  final t = norm(term);
  if (t.isEmpty) {
    return Resolution._(ResolutionStatus.missing, candidates: List.of(items));
  }
  final exact = _exactMatches(t, items);
  if (exact.length == 1) {
    return Resolution._(ResolutionStatus.resolved, value: exact.first);
  }
  if (exact.length > 1) {
    return Resolution._(ResolutionStatus.missing, candidates: exact);
  }
  final partial = items.where((i) {
    final n = norm(i.name);
    return n.isNotEmpty && (n.contains(t) || t.contains(n));
  }).toList();
  if (partial.length == 1) {
    return Resolution._(ResolutionStatus.resolved, value: partial.first);
  }
  if (partial.length > 1) {
    return Resolution._(ResolutionStatus.missing, candidates: partial);
  }
  return Resolution._(
    ResolutionStatus.notFound,
    reasons: const [ResolverReason.notFound],
    candidates: List.of(items),
  );
}

final RegExp _wordSeparator = RegExp(r'[^a-z0-9ñ]+');

/// Palabras de [s] ya normalizadas con [norm].
List<String> wordsOf(String s) =>
    norm(s).split(_wordSeparator).where((w) => w.isNotEmpty).toList();

List<String> _wordsOf(String s) => wordsOf(s);

/// Ancla por palabras (S3-02), complemento de `WriteContext.termInUserText`
/// (que exige el nombre completo): `true` si alguna palabra de [name] de 4 o
/// más letras aparece como palabra en [text] («Internet Cantv» en «ya pagué
/// el internet»).
///
/// Con [verbForms], una palabra de [name] en infinitivo (-ar, -er, -ir)
/// vale también en la forma que se usa para contar que ya se hizo: la raíz
/// (el infinitivo sin la terminación, de 2 letras o más) + «e» o «i» como
/// palabra entera, que normalizada es el pretérito de 1.ª persona o el
/// presente de 3.ª («Leer» en «ya leí»/«lee», «Nadar» en «nadé», «Correr»
/// en «corrí»). No vale cualquier palabra que empiece igual: «nada», «como»,
/// «correo», «camino», «ahorro» o «leche» no anclan.
bool nameWordInText(String? name, String text, {bool verbForms = false}) {
  if (name == null) return false;
  final textWords = _wordsOf(text).toSet();
  for (final w in _wordsOf(name)) {
    if (w.length < 4) continue;
    if (textWords.contains(w)) return true;
    if (!verbForms || !RegExp(r'(ar|er|ir)$').hasMatch(w)) continue;
    final root = w.substring(0, w.length - 2);
    if (root.length < 2) continue;
    if (textWords.contains('${root}e') || textWords.contains('${root}i')) {
      return true;
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// Fecha (§3.8)
// ---------------------------------------------------------------------------

class DateResolution {
  /// Fecha (a medianoche local) o `null` si [isInvalid].
  final DateTime? date;

  /// No vino fecha y se usó hoy.
  final bool usedToday;

  /// Vino algo que no es `YYYY-MM-DD` válido (→ `missing: [date]`).
  final bool isInvalid;

  /// Es posterior a hoy (→ `proposal` con `future_date` donde aplique).
  final bool isFuture;

  const DateResolution._({
    this.date,
    this.usedToday = false,
    this.isInvalid = false,
    this.isFuture = false,
  });

  @override
  String toString() =>
      'DateResolution($date, usedToday: $usedToday, invalid: $isInvalid, future: $isFuture)';
}

final RegExp _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// `date` explícita `YYYY-MM-DD` válida → esa; ausente o vacía → hoy.
/// Una fecha imposible («2026-02-30») o en otro formato → `isInvalid`.
/// [now] se inyecta en tests.
DateResolution resolveDate(String? raw, {DateTime Function()? now}) {
  final current = (now ?? DateTime.now)();
  final today = DateTime(current.year, current.month, current.day);
  final text = raw?.trim() ?? '';
  if (text.isEmpty) {
    return DateResolution._(date: today, usedToday: true);
  }
  final match = _isoDate.firstMatch(text);
  if (match == null) return const DateResolution._(isInvalid: true);
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return const DateResolution._(isInvalid: true);
  }
  return DateResolution._(date: date, isFuture: date.isAfter(today));
}
