import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/widgets/confirmation_dialog.dart';
import '../../data/models/manga_model.dart';
import '../../data/repositories/manga_repository.dart';
import '../../routes/app_routes.dart';
import '../../services/cover_service.dart';
import '../../services/user_service.dart';
import '../home/home_controller.dart';

class MangaDetailController extends GetxController {
  final _repo = Get.find<MangaRepository>();
  final _userService = Get.find<UserService>();
  final _coverService = Get.find<CoverService>();

  final manga = Rxn<MangaModel>();
  final isLoading = true.obs;
  final errorMessage = ''.obs;

  String get mangaId => Get.arguments as String;

  @override
  void onInit() {
    super.onInit();
    loadManga();

    // Automatically update HomeController when manga changes
    ever(manga, (MangaModel? val) {
      if (val != null && Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().updateMangaInList(val);
      }
    });
  }

  Future<void> loadManga() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final result = await _repo.getMangaById(mangaId);
      manga.value = result;
    } catch (e) {
      errorMessage.value = 'Error al cargar el manga: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// CU-03: Toggle tomo acquired state (optimistic update).
  Future<void> toggleTomo(int numeroTomo) async {
    final current = manga.value;
    if (current == null) return;

    final isAcquired = current.tomosAdquiridos.contains(numeroTomo);

    // Optimistic UI update
    final newTomos = List<int>.from(current.tomosAdquiridos);
    if (isAcquired) {
      newTomos.remove(numeroTomo);
    } else {
      newTomos.add(numeroTomo);
      newTomos.sort();
    }
    manga.value = current.copyWith(tomosAdquiridos: newTomos);

    try {
      if (isAcquired) {
        await _repo.desmarcarTomo(
          mangaId: current.id,
          numeroTomo: numeroTomo,
        );
      } else {
        await _repo.marcarTomo(
          mangaId: current.id,
          numeroTomo: numeroTomo,
          usuarioId: _userService.alias.value,
        );
      }
    } catch (e) {
      // Rollback UI on error
      manga.value = current;
      Get.snackbar(
        'Error',
        'No se pudo sincronizar. Intenta de nuevo.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// CU-07: Delete manga with double confirmation.
  Future<void> deleteManga() async {
    final current = manga.value;
    if (current == null) return;

    final confirmed = await ConfirmationDialog.showDeleteConfirmation(
      mangaTitle: current.titulo,
    );

    if (!confirmed) return;

    try {
      await _repo.deleteManga(current.id);

      // Ask about local cover
      if (_coverService.hasCover(current.id)) {
        final deleteCover = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Portada local'),
            content: const Text(
              '¿Deseas eliminar también la portada guardada en este dispositivo?',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Sí, eliminar'),
              ),
            ],
          ),
        );
        if (deleteCover == true) {
          await _coverService.deleteCover(current.id);
        }
      }

      Get.snackbar('Listo', 'Manga eliminado correctamente',
          snackPosition: SnackPosition.BOTTOM);
      Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      Get.snackbar('Error', 'No se pudo eliminar el manga',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> goToEdit() async {
    final result = await Get.toNamed(AppRoutes.mangaForm, arguments: {
      'mangaId': mangaId,
      'mode': 'edit',
    });
    if (result is MangaModel) {
      manga.value = result;
    }
  }
}
