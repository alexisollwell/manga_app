/// Pending action model for offline sync queue.
/// Stores actions performed while offline to be synced when reconnected.
library;

enum PendingActionType {
  createManga,
  updateManga,
  deleteManga,
  markTomo,
  unmarkTomo,
}

class PendingAction {
  final int? dbId; // SQLite auto-increment ID
  final PendingActionType type;
  final String mangaId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const PendingAction({
    this.dbId,
    required this.type,
    required this.mangaId,
    required this.payload,
    required this.createdAt,
  });

  /// Create from SQLite row.
  factory PendingAction.fromDb(Map<String, dynamic> map) {
    return PendingAction(
      dbId: map['id'] as int?,
      type: PendingActionType.values[map['type'] as int],
      mangaId: map['manga_id'] as String,
      payload: _decodePayload(map['payload'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Convert to SQLite map.
  Map<String, dynamic> toDb() {
    return {
      'type': type.index,
      'manga_id': mangaId,
      'payload': _encodePayload(payload),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Simple key=value encoding for payload.
  static String _encodePayload(Map<String, dynamic> payload) {
    return payload.entries.map((e) => '${e.key}=${e.value}').join('|');
  }

  /// Decode key=value payload.
  static Map<String, dynamic> _decodePayload(String encoded) {
    if (encoded.isEmpty) return {};
    final map = <String, dynamic>{};
    for (final part in encoded.split('|')) {
      final kv = part.split('=');
      if (kv.length == 2) {
        // Try to parse as int
        map[kv[0]] = int.tryParse(kv[1]) ?? kv[1];
      }
    }
    return map;
  }

  // ── Factory constructors for each action type ────

  factory PendingAction.createManga({
    required String tempId,
    required String titulo,
    required int cantidadTomos,
  }) {
    return PendingAction(
      type: PendingActionType.createManga,
      mangaId: tempId,
      payload: {'titulo': titulo, 'cantidad_tomos': cantidadTomos},
      createdAt: DateTime.now(),
    );
  }

  factory PendingAction.updateManga({
    required String mangaId,
    String? titulo,
    int? cantidadTomos,
  }) {
    final payload = <String, dynamic>{};
    if (titulo != null) payload['titulo'] = titulo;
    if (cantidadTomos != null) payload['cantidad_tomos'] = cantidadTomos;
    return PendingAction(
      type: PendingActionType.updateManga,
      mangaId: mangaId,
      payload: payload,
      createdAt: DateTime.now(),
    );
  }

  factory PendingAction.deleteManga({required String mangaId}) {
    return PendingAction(
      type: PendingActionType.deleteManga,
      mangaId: mangaId,
      payload: {},
      createdAt: DateTime.now(),
    );
  }

  factory PendingAction.markTomo({
    required String mangaId,
    required int numeroTomo,
    required String usuarioId,
  }) {
    return PendingAction(
      type: PendingActionType.markTomo,
      mangaId: mangaId,
      payload: {'numero_tomo': numeroTomo, 'usuario_id': usuarioId},
      createdAt: DateTime.now(),
    );
  }

  factory PendingAction.unmarkTomo({
    required String mangaId,
    required int numeroTomo,
  }) {
    return PendingAction(
      type: PendingActionType.unmarkTomo,
      mangaId: mangaId,
      payload: {'numero_tomo': numeroTomo},
      createdAt: DateTime.now(),
    );
  }

  @override
  String toString() =>
      'PendingAction(type: $type, manga: $mangaId, payload: $payload)';
}
