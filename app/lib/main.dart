import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'core/theme/app_theme.dart';
import 'data/local/manga_local_source.dart';
import 'data/remote/manga_remote_source.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';
import 'services/connectivity_service.dart';
import 'services/cover_service.dart';
import 'services/sync_service.dart';
import 'services/user_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  // Initialize local storage
  await GetStorage.init();

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // ── Initialize Global Services ─────────────────
  // These persist across the entire app lifecycle

  // Connectivity monitoring
  final connectivityService = await Get.putAsync<ConnectivityService>(() async {
    final service = ConnectivityService();
    service.onInit();
    return service;
  }, permanent: true);

  // User alias
  final userService = Get.put(UserService(), permanent: true);
  userService.onInit();

  // Cover management
  final coverService = Get.put(CoverService(), permanent: true);
  coverService.onInit();

  // Data sources (permanent for sync service)
  final remoteSource = Get.put(MangaRemoteSource(), permanent: true);
  remoteSource.onInit();
  final localSource = Get.put(MangaLocalSource(), permanent: true);

  // Sync service
  Get.put(
    SyncService(
      remote: remoteSource,
      local: localSource,
      connectivity: connectivityService,
    ),
    permanent: true,
  );

  // Determine initial route
  final initialRoute = userService.hasAlias
      ? AppRoutes.home
      : AppRoutes.onboarding;

  runApp(MangaLibApp(initialRoute: initialRoute));
}

class MangaLibApp extends StatelessWidget {
  const MangaLibApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Mangas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: initialRoute,
      getPages: AppPages.pages,
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
