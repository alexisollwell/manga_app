/// API constants for connecting to the manga library server.
library;

class ApiConstants {
  ApiConstants._();

  /// Base URL of the manga API server.
  /// Configurable via --dart-define-from-file=.env
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.100:8050',
  );

  /// API prefix
  static const String apiPrefix = '/api';

  /// Full API base URL
  static String get apiUrl => '$baseUrl$apiPrefix';

  /// Endpoints
  static const String mangas = '/mangas';

  static String mangaById(String id) => '/mangas/$id';

  static String marcarTomo(String mangaId, int numTomo) =>
      '/mangas/$mangaId/tomos/$numTomo/adquirir';

  /// Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
