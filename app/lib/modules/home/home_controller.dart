import 'package:get/get.dart';

import '../../data/models/manga_model.dart';
import '../../data/repositories/manga_repository.dart';
import '../../services/cover_service.dart';

class HomeController extends GetxController {
  final _repo = Get.find<MangaRepository>();

  // ── State ──────────────────────────────────────
  final mangas = <MangaModel>[].obs;
  final isLoading = true.obs;
  final errorMessage = ''.obs;

  // ── Filters ────────────────────────────────────
  final searchQuery = ''.obs;
  final showOnlyPending = false.obs;

  // ── Computed filtered list ─────────────────────
  List<MangaModel> get filteredMangas {
    var result = mangas.toList();

    // Filter by search text
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      result = result
          .where((m) => m.titulo.toLowerCase().contains(query))
          .toList();
    }

    // Filter by pending volumes only
    if (showOnlyPending.value) {
      result = result.where((m) => !m.isComplete).toList();
    }

    return result;
  }

  @override
  void onInit() {
    super.onInit();
    fetchMangas();
  }

  Future<void> fetchMangas({bool forceRefresh = false}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final result = await _repo.getMangas(forceRefresh: forceRefresh);
      mangas.assignAll(result);
      
      // Clean up local covers that don't belong to any active manga
      if (Get.isRegistered<CoverService>()) {
        await Get.find<CoverService>().cleanOrphanCovers(
          result.map((m) => m.id).toList(),
        );
      }
    } catch (e) {
      errorMessage.value = 'Error al cargar la biblioteca: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshMangas() async {
    await fetchMangas(forceRefresh: true);
  }

  void updateSearch(String query) {
    searchQuery.value = query;
  }

  void togglePendingFilter() {
    showOnlyPending.toggle();
  }
}
