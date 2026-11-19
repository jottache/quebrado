/// Respuesta única de las herramientas de escritura de Ortiz
/// (`docs/design/ortiz-registra.md` §2.1).
///
/// Cuatro estados y nada más. Al combinar varias partes gana el peor:
/// `error > missing > proposal > saved`.
library;

/// Estados posibles, ordenados de menor a mayor gravedad.
enum WriteToolStatus {
  saved,
  proposal,
  missing,
  error;

  /// Valor que viaja al modelo en `status`.
  String get code => name;

  /// Gravedad para «peor estado gana» (mayor = peor).
  int get severity => index;

  /// El peor de dos estados.
  WriteToolStatus worst(WriteToolStatus other) =>
      other.severity > severity ? other : this;
}

class WriteToolResult {
  final WriteToolStatus status;

  /// Herramienta o acción que produjo el resultado (p. ej. `registerTransaction`).
  final String action;

  // saved
  final String? recordId;
  final String? summary;
  final String? route;
  final String? undoId;

  // proposal
  final List<String> reasons;

  // missing (y proposal, para que la tarjeta ofrezca opciones)
  final List<String> missing;
  final Map<String, dynamic> resolved;
  final Map<String, List<String>> options;

  // error
  final String? message;

  const WriteToolResult._({
    required this.status,
    required this.action,
    this.recordId,
    this.summary,
    this.route,
    this.undoId,
    this.reasons = const [],
    this.missing = const [],
    this.resolved = const {},
    this.options = const {},
    this.message,
  });

  /// Todo resuelto sin dudas y guardado. `undoId` es nulo cuando no hubo
  /// cambio que deshacer (p. ej. «Ya estaba marcado»).
  factory WriteToolResult.saved({
    required String action,
    required String recordId,
    required String summary,
    String? route,
    String? undoId,
  }) =>
      WriteToolResult._(
        status: WriteToolStatus.saved,
        action: action,
        recordId: recordId,
        summary: summary,
        route: route,
        undoId: undoId,
      );

  /// Algo se resolvió con dudas: la persona confirma en una tarjeta.
  factory WriteToolResult.proposal({
    required String action,
    required List<String> reasons,
    String? summary,
    Map<String, dynamic> resolved = const {},
    Map<String, List<String>> options = const {},
  }) =>
      WriteToolResult._(
        status: WriteToolStatus.proposal,
        action: action,
        reasons: List.unmodifiable(reasons),
        summary: summary,
        resolved: Map.unmodifiable(resolved),
        options: Map.unmodifiable(options),
      );

  /// Falta algún dato obligatorio o hay que elegir entre opciones.
  /// `reasons` es opcional: avisos para Ortiz (p. ej. `no_account_in_currency`).
  factory WriteToolResult.missing({
    required String action,
    required List<String> missing,
    Map<String, dynamic> resolved = const {},
    Map<String, List<String>> options = const {},
    List<String> reasons = const [],
  }) =>
      WriteToolResult._(
        status: WriteToolStatus.missing,
        action: action,
        reasons: List.unmodifiable(reasons),
        missing: List.unmodifiable(missing),
        resolved: Map.unmodifiable(resolved),
        options: Map.unmodifiable(options),
      );

  /// Falló el guardado o no hay a qué aplicarlo.
  factory WriteToolResult.error({
    required String action,
    required String message,
  }) =>
      WriteToolResult._(
        status: WriteToolStatus.error,
        action: action,
        message: message,
      );

  bool get isSaved => status == WriteToolStatus.saved;
  bool get isProposal => status == WriteToolStatus.proposal;
  bool get isMissing => status == WriteToolStatus.missing;
  bool get isError => status == WriteToolStatus.error;

  /// Combina varias partes con «peor estado gana».
  ///
  /// - `status`: el más grave de todas las partes.
  /// - `reasons` y `missing`: unión sin repetidos, en orden de aparición.
  /// - `resolved` y `options`: unión de claves (la última parte gana si se repite).
  /// - `message`: los mensajes de las partes `error`, unidos por « ».
  /// - `summary`, `recordId`, `route`, `undoId`: los de la primera parte que los tenga.
  /// - `action`: el de la primera parte.
  ///
  /// Lanza [ArgumentError] si no recibe ninguna parte.
  static WriteToolResult combine(Iterable<WriteToolResult> parts) {
    final list = parts.toList();
    if (list.isEmpty) {
      throw ArgumentError.value(parts, 'parts', 'Se necesita al menos una parte');
    }
    var status = list.first.status;
    final reasons = <String>[];
    final missing = <String>[];
    final resolved = <String, dynamic>{};
    final options = <String, List<String>>{};
    final messages = <String>[];
    for (final part in list) {
      status = status.worst(part.status);
      for (final r in part.reasons) {
        if (!reasons.contains(r)) reasons.add(r);
      }
      for (final m in part.missing) {
        if (!missing.contains(m)) missing.add(m);
      }
      resolved.addAll(part.resolved);
      options.addAll(part.options);
      if (part.isError && part.message != null && part.message!.isNotEmpty) {
        messages.add(part.message!);
      }
    }
    T? firstOf<T>(T? Function(WriteToolResult) pick) {
      for (final part in list) {
        final value = pick(part);
        if (value != null) return value;
      }
      return null;
    }

    return WriteToolResult._(
      status: status,
      action: list.first.action,
      recordId: firstOf((p) => p.recordId),
      summary: firstOf((p) => p.summary),
      route: firstOf((p) => p.route),
      undoId: firstOf((p) => p.undoId),
      reasons: List.unmodifiable(reasons),
      missing: List.unmodifiable(missing),
      resolved: Map.unmodifiable(resolved),
      options: Map.unmodifiable(options),
      message: messages.isEmpty ? null : messages.join(' '),
    );
  }

  /// Mapa que se devuelve al modelo como `resultData`. Solo lleva los campos
  /// del estado (§2.1); omite los nulos y las colecciones vacías opcionales.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'status': status.code,
      'action': action,
    };
    void put(String key, Object? value) {
      if (value != null) json[key] = value;
    }

    switch (status) {
      case WriteToolStatus.saved:
        put('recordId', recordId);
        put('summary', summary);
        put('route', route);
        put('undoId', undoId);
      case WriteToolStatus.proposal:
        json['reasons'] = List<String>.from(reasons);
        put('summary', summary);
        if (resolved.isNotEmpty) json['resolved'] = Map<String, dynamic>.from(resolved);
        if (options.isNotEmpty) json['options'] = _optionsJson();
      case WriteToolStatus.missing:
        json['missing'] = List<String>.from(missing);
        json['resolved'] = Map<String, dynamic>.from(resolved);
        if (options.isNotEmpty) json['options'] = _optionsJson();
        if (reasons.isNotEmpty) json['reasons'] = List<String>.from(reasons);
      case WriteToolStatus.error:
        put('message', message);
    }
    return json;
  }

  Map<String, List<String>> _optionsJson() => {
        for (final e in options.entries) e.key: List<String>.from(e.value),
      };

  @override
  String toString() => 'WriteToolResult(${toJson()})';
}
