/// Double confirmation dialog for destructive actions (CU-07).
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';

class ConfirmationDialog {
  ConfirmationDialog._();

  /// Show a double confirmation dialog for deleting a manga.
  /// Returns true if the user confirms deletion, false otherwise.
  static Future<bool> showDeleteConfirmation({
    required String mangaTitle,
  }) async {
    // ── First dialog ─────────────────────────────────
    final firstResult = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('¿Eliminar manga?'),
        content: RichText(
          text: TextSpan(
            style: Get.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
            children: [
              const TextSpan(
                text: '¿Estás seguro de que deseas eliminar ',
              ),
              TextSpan(
                text: mangaTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const TextSpan(
                text:
                    ' de la biblioteca compartida? Esta acción afectará a todos los usuarios.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Sí, quiero eliminarlo'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    if (firstResult != true) return false;

    // ── Second dialog (more emphatic) ────────────────
    final secondResult = await Get.dialog<bool>(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
            SizedBox(width: 8),
            Text('Confirmación final'),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: Get.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
            children: [
              const TextSpan(
                text: 'Esta acción ',
              ),
              const TextSpan(
                text: 'no se puede deshacer',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
              const TextSpan(
                text: '. Se eliminará el manga ',
              ),
              TextSpan(
                text: mangaTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const TextSpan(
                text:
                    ' y todo el registro de tomos adquiridos para todos los usuarios. ¿Confirmas?',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('No, conservar manga'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Sí, eliminar definitivamente'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    return secondResult == true;
  }
}
