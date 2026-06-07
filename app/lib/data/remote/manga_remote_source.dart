/// Remote data source using GetConnect for HTTP communication with the API.
library;

import 'package:get/get.dart';

import '../../core/constants/api_constants.dart';
import '../models/manga_model.dart';

class MangaRemoteSource extends GetConnect {
  @override
  void onInit() {
    httpClient.baseUrl = ApiConstants.apiUrl;
    httpClient.defaultContentType = 'application/json';
    httpClient.timeout = ApiConstants.connectTimeout;

    // Log requests in debug mode
    httpClient.addRequestModifier<dynamic>((request) {
      // ignore: avoid_print
      print('[API] ${request.method} ${request.url}');
      return request;
    });

    super.onInit();
  }

  // ──────────────────────────────────────────────
  // Manga CRUD
  // ──────────────────────────────────────────────

  /// GET /mangas — Fetch all mangas
  Future<List<MangaModel>> getMangas() async {
    final response = await get(ApiConstants.mangas);
    _handleError(response);
    final list = response.body as List<dynamic>;
    return list.map((e) => MangaModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /mangas/{id} — Fetch manga detail
  Future<MangaModel> getMangaById(String id) async {
    final response = await get(ApiConstants.mangaById(id));
    _handleError(response);
    return MangaModel.fromJson(response.body as Map<String, dynamic>);
  }

  /// POST /mangas — Create a new manga
  Future<MangaModel> createManga({
    required String titulo,
    required int cantidadTomos,
  }) async {
    final response = await post(ApiConstants.mangas, {
      'titulo': titulo,
      'cantidad_tomos': cantidadTomos,
    });
    _handleError(response);
    return MangaModel.fromJson(response.body as Map<String, dynamic>);
  }

  /// PUT /mangas/{id} — Update manga
  Future<MangaModel> updateManga({
    required String id,
    String? titulo,
    int? cantidadTomos,
  }) async {
    final body = <String, dynamic>{};
    if (titulo != null) body['titulo'] = titulo;
    if (cantidadTomos != null) body['cantidad_tomos'] = cantidadTomos;

    final response = await put(ApiConstants.mangaById(id), body);
    _handleError(response);
    return MangaModel.fromJson(response.body as Map<String, dynamic>);
  }

  /// DELETE /mangas/{id} — Delete manga
  Future<void> deleteManga(String id) async {
    final response = await delete(ApiConstants.mangaById(id));
    _handleError(response);
  }

  // ──────────────────────────────────────────────
  // Tomo Operations
  // ──────────────────────────────────────────────

  /// POST /mangas/{id}/tomos/{num}/adquirir — Mark tomo
  Future<void> marcarTomo({
    required String mangaId,
    required int numeroTomo,
    required String usuarioId,
  }) async {
    final response = await post(
      ApiConstants.marcarTomo(mangaId, numeroTomo),
      {'usuario_id': usuarioId},
    );
    _handleError(response);
  }

  /// DELETE /mangas/{id}/tomos/{num}/adquirir — Unmark tomo
  Future<void> desmarcarTomo({
    required String mangaId,
    required int numeroTomo,
  }) async {
    final response = await delete(
      ApiConstants.marcarTomo(mangaId, numeroTomo),
    );
    _handleError(response);
  }

  // ──────────────────────────────────────────────
  // Error Handling
  // ──────────────────────────────────────────────

  void _handleError(Response response) {
    if (response.hasError) {
      final statusCode = response.statusCode ?? 0;
      String message = 'Error de conexión';

      if (response.body is Map<String, dynamic>) {
        final detail = response.body['detail'];
        if (detail is String) {
          message = detail;
        } else if (detail is Map) {
          message = detail['message'] as String? ?? message;
        }
      }

      throw ApiException(statusCode: statusCode, message: message);
    }
  }
}

/// Custom exception for API errors.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  bool get isConflict => statusCode == 409;
  bool get isNotFound => statusCode == 404;
  bool get isValidationError => statusCode == 422;
  bool get isNetworkError => statusCode == 0;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
