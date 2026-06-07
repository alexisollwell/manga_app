import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/connectivity_banner.dart';
import '../../core/widgets/error_widget.dart';
import '../../core/widgets/loading_widget.dart';
import '../../services/cover_service.dart';
import 'manga_detail_controller.dart';

class MangaDetailView extends GetView<MangaDetailController> {
  const MangaDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ConnectivityBanner(),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value &&
                  controller.manga.value == null) {
                return const LoadingWidget(message: 'Cargando manga...');
              }

              if (controller.errorMessage.value.isNotEmpty &&
                  controller.manga.value == null) {
                return AppErrorWidget(
                  message: controller.errorMessage.value,
                  onRetry: controller.loadManga,
                );
              }

              final manga = controller.manga.value;
              if (manga == null) {
                return const AppErrorWidget(message: 'Manga no encontrado');
              }

              return CustomScrollView(
                slivers: [
                  _buildCoverAppBar(context, manga.titulo),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Title & Actions ──────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  manga.titulo,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.displayMedium,
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                  color: AppColors.textSecondary,
                                ),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    controller.goToEdit();
                                  } else if (value == 'delete') {
                                    controller.deleteManga();
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_rounded, size: 20),
                                        SizedBox(width: 8),
                                        Text('Editar manga'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_rounded,
                                          size: 20,
                                          color: AppColors.danger,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Eliminar manga',
                                          style: TextStyle(
                                            color: AppColors.danger,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // ── Progress Summary ─────────
                          _buildProgressSummary(
                            context,
                            manga.tomosAdquiridos.length,
                            manga.cantidadTomos,
                          ),

                          const SizedBox(height: 24),

                          // ── Legend ────────────────────
                          Row(
                            children: [
                              _legendDot(AppColors.success, 'Adquirido'),
                              const SizedBox(width: 16),
                              _legendDot(AppColors.pending, 'Pendiente'),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ── Tomo Grid ────────────────
                          _buildTomoGrid(
                            manga.cantidadTomos,
                            manga.tomosAdquiridos,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverAppBar(BuildContext context, String titulo) {
    final coverService = Get.find<CoverService>();
    final mangaId = controller.mangaId;
    final hasCover = coverService.hasCover(mangaId);

    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.surface,
      flexibleSpace: FlexibleSpaceBar(
        background: hasCover
            ? Image.file(
                File(coverService.coverPath(mangaId)),
                fit: BoxFit.cover,
                colorBlendMode: BlendMode.darken,
                color: Colors.black.withAlpha(80),
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withAlpha(60),
                      AppColors.background,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: 80,
                    color: AppColors.textHint,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProgressSummary(BuildContext context, int acquired, int total) {
    final progress = total > 0 ? acquired / total : 0.0;
    final isComplete = acquired >= total;

    return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isComplete
                  ? AppColors.success.withAlpha(80)
                  : AppColors.surfaceLight,
            ),
          ),
          child: Row(
            children: [
              // Circular progress
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 5.5,
                        backgroundColor: AppColors.pending.withAlpha(80),
                        valueColor: AlwaysStoppedAnimation(
                          isComplete ? AppColors.success : AppColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isComplete ? '¡Colección completa!' : 'Progreso',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isComplete
                            ? AppColors.success
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$acquired de $total tomos adquiridos',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: -0.05, end: 0, duration: 400.ms);
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTomoGrid(int totalTomos, List<int> adquiridos) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: totalTomos,
      itemBuilder: (context, index) {
        final numero = index + 1;
        final isAcquired = adquiridos.contains(numero);

        return _TomoButton(
          numero: numero,
          isAcquired: isAcquired,
          onTap: () => controller.toggleTomo(numero),
        );
      },
    );
  }
}

class _TomoButton extends StatelessWidget {
  const _TomoButton({
    required this.numero,
    required this.isAcquired,
    required this.onTap,
  });

  final int numero;
  final bool isAcquired;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isAcquired
              ? AppColors.success.withAlpha(40)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAcquired
                ? AppColors.success
                : AppColors.pending.withAlpha(80),
            width: isAcquired ? 2 : 1,
          ),
          boxShadow: isAcquired
              ? [
                  BoxShadow(
                    color: AppColors.success.withAlpha(30),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$numero',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isAcquired
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
              ),
              if (isAcquired)
                const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: AppColors.success,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
