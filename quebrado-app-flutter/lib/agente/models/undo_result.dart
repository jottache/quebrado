/// Resultado de deshacer un registro de Ortiz (spec 03, §4).
///
/// [ok] dice si se deshizo; [message] es el texto para la persona: «Deshecho»
/// o el motivo en español por el que no se pudo. Nunca lleva el detalle
/// técnico del error.
class UndoResult {
  /// Texto de un deshacer correcto.
  static const String doneMessage = 'Deshecho';

  final bool ok;
  final String message;

  /// No se deshizo, pero no es un fallo: falta algo que la persona puede
  /// hacer (p. ej. «Cambia al libro X para deshacerlo»). Se pinta en
  /// `muted`, no en `bad` (U2.3).
  final bool isNotice;

  const UndoResult.done()
      : ok = true,
        isNotice = false,
        message = doneMessage;

  const UndoResult.failed(this.message)
      : ok = false,
        isNotice = false;

  const UndoResult.notice(this.message)
      : ok = false,
        isNotice = true;

  @override
  bool operator ==(Object other) =>
      other is UndoResult &&
      other.ok == ok &&
      other.isNotice == isNotice &&
      other.message == message;

  @override
  int get hashCode => Object.hash(ok, isNotice, message);

  @override
  String toString() =>
      'UndoResult(ok: $ok, isNotice: $isNotice, message: $message)';
}
