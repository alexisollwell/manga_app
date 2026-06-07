import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import 'manga_form_controller.dart';

class MangaFormView extends GetView<MangaFormController> {
  const MangaFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(
              controller.isEditMode.value ? 'Editar Manga' : 'Agregar Manga',
            )),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.isEditMode.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Cover Image Picker ───────────
                _buildCoverPicker(context),

                const SizedBox(height: 28),

                // ── Title Field ──────────────────
                Text(
                  'Título',
                  style: Theme.of(context).textTheme.titleMedium,
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 8),

                TextFormField(
                  controller: controller.tituloController,
                  validator: Validators.titulo,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'Ej: One Piece',
                    prefixIcon: Icon(Icons.book_rounded, color: AppColors.primary),
                  ),
                ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.05, end: 0, delay: 200.ms),

                const SizedBox(height: 24),

                // ── Volume Count Field ───────────
                Text(
                  'Cantidad de tomos',
                  style: Theme.of(context).textTheme.titleMedium,
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 8),

                TextFormField(
                  controller: controller.tomosController,
                  validator: controller.validateTomos,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'Ej: 100',
                    prefixIcon:
                        Icon(Icons.format_list_numbered_rounded, color: AppColors.primary),
                  ),
                ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.05, end: 0, delay: 400.ms),

                const SizedBox(height: 16),

                // ── Error Message ────────────────
                Obx(() => controller.errorMessage.value.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.danger.withAlpha(60),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.danger, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                controller.errorMessage.value,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink()),

                const SizedBox(height: 32),

                // ── Submit Button ────────────────
                Obx(() => SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed:
                            controller.isLoading.value ? null : controller.submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: controller.isLoading.value
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                controller.isEditMode.value
                                    ? 'Guardar cambios'
                                    : 'Agregar manga',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ))
                    .animate()
                    .fadeIn(delay: 500.ms)
                    .slideY(begin: 0.1, end: 0, delay: 500.ms),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCoverPicker(BuildContext context) {
    return Center(
      child: Obx(() {
        final image = controller.selectedImage.value;
        return GestureDetector(
          onTap: controller.pickImage,
          child: Stack(
            children: [
              Container(
                width: 160,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.surfaceLight,
                  border: Border.all(
                    color: AppColors.surfaceLight,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  image: image != null
                      ? DecorationImage(
                          image: FileImage(image),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: image == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_rounded,
                            size: 40,
                            color: AppColors.textHint,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Agregar portada',
                            style: TextStyle(
                              color: AppColors.textHint,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '(Opcional)',
                            style: TextStyle(
                              color: AppColors.textHint,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
              if (image != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: controller.removeImage,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    ).animate().fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: 400.ms,
        );
  }
}
