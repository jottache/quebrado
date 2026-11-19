/// Contrato común de los ejecutores de escritura de Ortiz (spec 03,
/// `docs/design/ortiz-registra.md` §2–§4 y §7).
///
/// Cada dominio (finanzas, ánimo, hábitos, notas, diario, recordatorios)
/// implementa [WriteToolHandler]. `SuiteRagService` despacha por nombre de
/// herramienta, `AgenteState` guarda [WriteOutcome.undoPayload] para Deshacer
/// y vuelve a llamar a [WriteToolHandler.execute] con `confirmedByUser` al
/// confirmar una tarjeta. El modelo solo ve [WriteToolResult.toJson].
library;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'ortiz_resolver.dart' show wordsOf;
import 'write_tool_result.dart';

/// Tipo de cada trozo del resumen (U2.1): los montos se pintan en mono.
enum SummaryPartKind { text, amount, amountSecondary }

/// Trozo del resumen de un registro, ya formateado por el ejecutor.
class SummaryPart {
  final String text;
  final SummaryPartKind kind;

  const SummaryPart(this.text, [this.kind = SummaryPartKind.text]);

  Map<String, dynamic> toJson() => {'text': text, 'kind': kind.name};

  factory SummaryPart.fromJson(Map<String, dynamic> json) => SummaryPart(
        json['text'] as String? ?? '',
        SummaryPartKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => SummaryPartKind.text,
        ),
      );
}

/// Lo que sabe el ejecutor del turno en curso (CA-10, §7).
class WriteContext {
  /// Texto de los mensajes de la persona en esta conversación (para anclar
  /// montos: un monto solo se guarda directo si aparece aquí).
  final String userText;

  /// En este turno ya se leyó texto libre (diario, notas, contactos…):
  /// toda escritura baja a `proposal` con el motivo `read_untrusted_text`.
  final bool untrustedRead;

  /// La persona confirmó la tarjeta: las dudas de tipo `proposal` ya están
  /// aceptadas y se guarda (los `missing` siguen siendo `missing`).
  final bool confirmedByUser;

  /// Reloj inyectable para tests.
  final DateTime Function() now;

  WriteContext({
    this.userText = '',
    this.untrustedRead = false,
    this.confirmedByUser = false,
    this.writeLimitReached = false,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  /// En este mensaje ya se guardaron directo [SuiteRagService.maxDirectWritesPerMessage]
  /// registros: el siguiente baja a `proposal` con `too_many_writes`.
  final bool writeLimitReached;

  /// Motivos que obligan a tarjeta aunque todo se haya resuelto. Varios
  /// registros en un mismo mensaje se guardan todos directo (decisión de la
  /// persona, 2026-11-19), hasta un tope alto de seguridad.
  List<String> get forcedProposalReasons {
    if (confirmedByUser) return const [];
    return [
      if (untrustedRead) 'read_untrusted_text',
      if (writeLimitReached) 'too_many_writes',
    ];
  }

  /// `true` si [amount] aparece escrito por la persona («450», «450,5»,
  /// «1.200», «1,200.50»…). Compara **valores** (no dígitos sueltos: «1,90»
  /// no vale por 19) y acepta cada lectura posible de «.» y «,» en lo que
  /// escribió la persona (decimal o separador de miles).
  bool amountInUserText(num amount) {
    if (amount <= 0) return false;
    for (final m in RegExp(r'\d[\d.,]*').allMatches(userText)) {
      final raw = m.group(0)!.replaceAll(RegExp(r'[.,]+$'), '');
      for (final value in readingsOf(raw)) {
        if ((value - amount).abs() < 0.005) return true;
      }
    }
    return false;
  }

  /// `true` si la persona nombró [term] en la conversación (S3-02): el
  /// pago, hábito o contacto sobre el que se actúa debe salir de lo que ella
  /// escribió, no de nombres del contexto ni de datos leídos. Compara con
  /// [norm] (sin acentos ni mayúsculas) y **por palabras enteras**: las
  /// palabras del término deben aparecer seguidas en lo que escribió la
  /// persona («internet» en «ya pagué el internet»; «Ana» no ancla en
  /// «semana»). Términos de menos de 3 letras no anclan.
  bool termInUserText(String? term) {
    if (term == null) return false;
    final t = wordsOf(term);
    if (t.join(' ').length < 3) return false;
    final words = wordsOf(userText);
    for (var i = 0; i + t.length <= words.length; i++) {
      var match = true;
      for (var j = 0; j < t.length; j++) {
        if (words[i + j] != t[j]) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }

  /// Lecturas numéricas posibles de un número escrito a mano.
  @visibleForTesting
  static Set<double> readingsOf(String raw) {
    final readings = <double>{};
    void add(String s) {
      final v = double.tryParse(s);
      if (v != null) readings.add(v);
    }

    final hasDot = raw.contains('.');
    final hasComma = raw.contains(',');
    if (!hasDot && !hasComma) {
      add(raw);
    } else if (hasDot && hasComma) {
      // El último separador es el decimal; el otro, de miles.
      final decimalSep = raw.lastIndexOf('.') > raw.lastIndexOf(',') ? '.' : ',';
      final thousandsSep = decimalSep == '.' ? ',' : '.';
      add(raw.replaceAll(thousandsSep, '').replaceAll(decimalSep, '.'));
    } else {
      final sep = hasDot ? '.' : ',';
      // Lectura decimal: solo si hay un único separador.
      if (sep.allMatches(raw).length == 1) add(raw.replaceAll(sep, '.'));
      // Lectura de miles: solo con agrupación válida (1.200, 12.345.678).
      if (RegExp('^\\d{1,3}(\\$sep\\d{3})+\$').hasMatch(raw)) {
        add(raw.replaceAll(sep, ''));
      }
    }
    return readings;
  }

  WriteContext copyWith({
    bool? untrustedRead,
    bool? confirmedByUser,
  }) =>
      WriteContext(
        userText: userText,
        untrustedRead: untrustedRead ?? this.untrustedRead,
        writeLimitReached: writeLimitReached,
        confirmedByUser: confirmedByUser ?? this.confirmedByUser,
        now: now,
      );
}

/// Resultado completo de un ejecutor: lo que ve el modelo ([result]) y lo
/// que necesita la app (resumen por trozos, datos para Deshacer y para
/// confirmar la tarjeta).
class WriteOutcome {
  final WriteToolResult result;

  /// Resumen por trozos (U2.1) en `saved` y `proposal`.
  final String? summaryTitle;
  final List<SummaryPart> summaryParts;

  /// Solo en `saved` con algo que deshacer: ids creados y copias previas.
  /// Lo interpreta el mismo handler en [WriteToolHandler.undo].
  final Map<String, dynamic>? undoPayload;

  /// Solo en `proposal`: argumentos ya resueltos con los que se vuelve a
  /// llamar a [WriteToolHandler.execute] al confirmar (más lo que elija la
  /// persona en la tarjeta, p. ej. `categoryName`).
  final Map<String, dynamic>? commitArgs;

  /// Libro donde se registró (solo finanzas): Deshacer exige el mismo libro.
  final String? profileId;

  /// Solo en `proposal`: la lista completa por clave de `options` para
  /// «Ver todas» de la tarjeta (p. ej. todas las categorías del tipo). Va
  /// solo a la tarjeta, no al modelo.
  final Map<String, List<String>> allOptions;

  const WriteOutcome(
    this.result, {
    this.summaryTitle,
    this.summaryParts = const [],
    this.undoPayload,
    this.commitArgs,
    this.profileId,
    this.allOptions = const {},
  });
}

/// Ejecutor de las herramientas de escritura de un dominio.
abstract class WriteToolHandler {
  /// Nombres de herramienta (`WriteToolNames.*`) que atiende.
  Set<String> get toolNames;

  /// Resuelve los argumentos del modelo (§3) y guarda si todo está claro,
  /// respetando [WriteContext.forcedProposalReasons]. Nunca lanza: los
  /// fallos de guardado salen como `error` («No pude registrarlo: …»),
  /// y si el guardado era compuesto deshace lo que alcanzó a escribir.
  Future<WriteOutcome> execute(
    String toolName,
    Map<String, dynamic> args,
    WriteContext ctx,
  );

  /// Deshace un registro hecho por [execute] a partir de su
  /// [WriteOutcome.undoPayload]. Lanza si no se pudo (el llamador lo dice).
  Future<void> undo(String toolName, Map<String, dynamic> undoPayload);
}
