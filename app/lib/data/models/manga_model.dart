/// Manga data model.
/// Supports JSON serialization (API) and SQLite map conversion (local cache).
library;

class MangaModel {
  final String id;
  final String titulo;
  final int cantidadTomos;
  final List<int> tomosAdquiridos;
  final bool isTemporary; // true if created offline with temp ID

  const MangaModel({
    required this.id,
    required this.titulo,
    required this.cantidadTomos,
    this.tomosAdquiridos = const [],
    this.isTemporary = false,
  });

  /// Create from API JSON response.
  factory MangaModel.fromJson(Map<String, dynamic> json) {
    return MangaModel(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      cantidadTomos: json['cantidad_tomos'] as int,
      tomosAdquiridos: (json['tomos_adquiridos'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }

  /// Convert to JSON for API requests.
  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'cantidad_tomos': cantidadTomos,
    };
  }

  /// Create from local SQLite row.
  factory MangaModel.fromDb(Map<String, dynamic> map, List<int> tomos) {
    return MangaModel(
      id: map['id'] as String,
      titulo: map['titulo'] as String,
      cantidadTomos: map['cantidad_tomos'] as int,
      tomosAdquiridos: tomos,
      isTemporary: (map['is_temporary'] as int?) == 1,
    );
  }

  /// Convert to SQLite map (without tomos — those are separate table).
  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'titulo': titulo,
      'cantidad_tomos': cantidadTomos,
      'is_temporary': isTemporary ? 1 : 0,
    };
  }

  /// Create a copy with modified fields.
  MangaModel copyWith({
    String? id,
    String? titulo,
    int? cantidadTomos,
    List<int>? tomosAdquiridos,
    bool? isTemporary,
  }) {
    return MangaModel(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      cantidadTomos: cantidadTomos ?? this.cantidadTomos,
      tomosAdquiridos: tomosAdquiridos ?? this.tomosAdquiridos,
      isTemporary: isTemporary ?? this.isTemporary,
    );
  }

  /// Progress ratio (0.0 to 1.0).
  double get progress =>
      cantidadTomos > 0 ? tomosAdquiridos.length / cantidadTomos : 0.0;

  /// Number of missing volumes.
  int get tomosFaltantes => cantidadTomos - tomosAdquiridos.length;

  /// Whether all volumes are acquired.
  bool get isComplete => tomosAdquiridos.length >= cantidadTomos;

  @override
  String toString() =>
      'MangaModel(id: $id, titulo: $titulo, tomos: ${tomosAdquiridos.length}/$cantidadTomos)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MangaModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
