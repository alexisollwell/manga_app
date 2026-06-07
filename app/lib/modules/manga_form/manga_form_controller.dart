import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/manga_model.dart';
import '../../data/repositories/manga_repository.dart';
import '../../services/cover_service.dart';

class MangaFormController extends GetxController {
  final _repo = Get.find<MangaRepository>();
  final _coverService = Get.find<CoverService>();

  final formKey = GlobalKey<FormState>();
  final tituloController = TextEditingController();
  final tomosController = TextEditingController();

  final isLoading = false.obs;
  final isEditMode = false.obs;
  final selectedImage = Rxn<File>();
  final errorMessage = ''.obs;

  String? _editMangaId;
  MangaModel? _originalManga;

  @override
  void onInit() {
    super.onInit();

    // Check if edit mode
    final args = Get.arguments;
    if (args is Map<String, dynamic> && args['mode'] == 'edit') {
      isEditMode.value = true;
      _editMangaId = args['mangaId'] as String;
      _loadMangaForEdit();
    }
  }

  Future<void> _loadMangaForEdit() async {
    if (_editMangaId == null) return;
    isLoading.value = true;

    try {
      final manga = await _repo.getMangaById(_editMangaId!);
      if (manga != null) {
        _originalManga = manga;
        tituloController.text = manga.titulo;
        tomosController.text = manga.cantidadTomos.toString();

        // Check for existing cover
        if (_coverService.hasCover(manga.id)) {
          selectedImage.value = File(_coverService.coverPath(manga.id));
        }
      }
    } catch (e) {
      errorMessage.value = 'Error al cargar el manga';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked != null) {
      selectedImage.value = File(picked.path);
    }
  }

  Future<void> removeImage() async {
    selectedImage.value = null;
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final titulo = tituloController.text.trim();
      final cantidadTomos = int.parse(tomosController.text.trim());

      MangaModel result;

      if (isEditMode.value && _editMangaId != null) {
        // ── Edit Mode ──────────────────────
        result = await _repo.updateManga(
          id: _editMangaId!,
          titulo: titulo != _originalManga?.titulo ? titulo : null,
          cantidadTomos: cantidadTomos != _originalManga?.cantidadTomos
              ? cantidadTomos
              : null,
        );
      } else {
        // ── Create Mode ────────────────────
        result = await _repo.createManga(
          titulo: titulo,
          cantidadTomos: cantidadTomos,
        );
      }

      // Save cover locally if selected
      if (selectedImage.value != null) {
        // Don't re-copy if it's the existing cover path
        final existingPath = _coverService.coverPath(result.id);
        if (selectedImage.value!.path != existingPath) {
          await _coverService.saveCover(result.id, selectedImage.value!);
        }
      }

      Get.back(result: result);
      Get.snackbar(
        'Listo',
        isEditMode.value
            ? 'Manga actualizado correctamente'
            : 'Manga agregado correctamente',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      Get.snackbar('Error', e.message, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      errorMessage.value = 'Error inesperado: $e';
      Get.snackbar('Error', errorMessage.value,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  /// Validate tomos count for edit mode (can't decrease).
  String? validateTomos(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La cantidad de tomos es obligatoria';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Ingresa un número válido';
    if (parsed < 1) return 'La cantidad debe ser al menos 1';

    if (isEditMode.value && _originalManga != null) {
      if (parsed < _originalManga!.cantidadTomos) {
        return 'No puede ser menor a ${_originalManga!.cantidadTomos}';
      }
    }

    return null;
  }

  @override
  void onClose() {
    tituloController.dispose();
    tomosController.dispose();
    super.onClose();
  }
}
