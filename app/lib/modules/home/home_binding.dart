import 'package:get/get.dart';

import '../../data/local/manga_local_source.dart';
import '../../data/remote/manga_remote_source.dart';
import '../../data/repositories/manga_repository.dart';
import '../../services/connectivity_service.dart';
import 'home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // Data sources
    if (!Get.isRegistered<MangaRemoteSource>()) {
      Get.put(MangaRemoteSource());
    }
    if (!Get.isRegistered<MangaLocalSource>()) {
      Get.lazyPut<MangaLocalSource>(() => MangaLocalSource());
    }

    // Repository
    if (!Get.isRegistered<MangaRepository>()) {
      Get.lazyPut<MangaRepository>(
        () => MangaRepository(
          remote: Get.find<MangaRemoteSource>(),
          local: Get.find<MangaLocalSource>(),
          connectivity: Get.find<ConnectivityService>(),
        ),
      );
    }

    // Controller
    Get.lazyPut<HomeController>(() => HomeController());
  }
}
