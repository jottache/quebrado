/// Registro en memoria de una escritura hecha por Ortiz, para Deshacer
/// (spec 03, `docs/design/ortiz-registra.md` §4, PA-02).
///
/// Vive solo mientras la app está abierta: no se persiste. Tras recargar, el
/// mensaje guardado muestra Deshacer desactivado.
class AgentActionRecord {
  /// Identificador del deshacer (uuid v4); va también en la metadata del
  /// artefacto (`undoId`).
  final String undoId;

  /// Conversación donde se hizo: solo se deshace desde ella.
  final String sessionId;

  /// Artefacto (mensaje de resultado) con el botón Deshacer.
  final String artifactId;

  /// Herramienta que hizo la escritura (`WriteToolNames.*`).
  final String toolName;

  /// Libro donde se registró (solo Finanzas).
  final String? profileId;

  /// Ids creados y copias previas; lo interpreta el ejecutor en `undo`.
  final Map<String, dynamic> undoPayload;

  final DateTime createdAt;

  /// Ya se deshizo.
  bool undone;

  AgentActionRecord({
    required this.undoId,
    required this.sessionId,
    required this.artifactId,
    required this.toolName,
    required this.undoPayload,
    this.profileId,
    DateTime? createdAt,
    this.undone = false,
  }) : createdAt = createdAt ?? DateTime.now();
}
