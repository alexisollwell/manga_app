import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/connectivity_banner.dart';
import '../../core/widgets/error_widget.dart';
import '../../core/widgets/loading_widget.dart';
import '../../data/models/manga_model.dart';
import '../../routes/app_routes.dart';
import '../../services/cover_service.dart';
import '../../services/user_service.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ConnectivityBanner(),
          Expanded(
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context),
                _buildSearchBar(),
                _buildFilterChips(),
                _buildMangaGrid(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.toNamed(AppRoutes.mangaForm),
        child: const Icon(Icons.add_rounded, size: 28),
      )
          .animate()
          .scale(
            begin: const Offset(0, 0),
            end: const Offset(1, 1),
            delay: 300.ms,
            duration: 400.ms,
            curve: Curves.elasticOut,
          ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final userService = Get.find<UserService>();
    return SliverAppBar(
      floating: true,
      expandedHeight: 100,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(() => Text(
                  'Hola, ${userService.alias.value} 👋',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                )),
            const Text(
              'MangaLib',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: controller.refreshMangas,
          tooltip: 'Actualizar',
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: TextField(
          onChanged: controller.updateSearch,
          decoration: InputDecoration(
            hintText: 'Buscar manga...',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint),
            suffixIcon: Obx(() => controller.searchQuery.value.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textHint),
                    onPressed: () {
                      controller.updateSearch('');
                      FocusScope.of(Get.context!).unfocus();
                    },
                  )
                : const SizedBox.shrink()),
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Obx(() => Row(
              children: [
                FilterChip(
                  label: const Text('Solo pendientes'),
                  selected: controller.showOnlyPending.value,
                  onSelected: (_) => controller.togglePendingFilter(),
                  selectedColor: AppColors.primary.withAlpha(60),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: controller.showOnlyPending.value
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: controller.showOnlyPending.value
                        ? AppColors.primary
                        : AppColors.surfaceLight,
                  ),
                ),
                const SizedBox(width: 8),
                Obx(() => Text(
                      '${controller.filteredMangas.length} mangas',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 13,
                      ),
                    )),
              ],
            )),
      ),
    );
  }

  Widget _buildMangaGrid() {
    return Obx(() {
      if (controller.isLoading.value && controller.mangas.isEmpty) {
        return const SliverFillRemaining(
          child: LoadingWidget(message: 'Cargando biblioteca...'),
        );
      }

      if (controller.errorMessage.value.isNotEmpty && controller.mangas.isEmpty) {
        return SliverFillRemaining(
          child: AppErrorWidget(
            message: controller.errorMessage.value,
            onRetry: controller.refreshMangas,
          ),
        );
      }

      final filtered = controller.filteredMangas;

      if (filtered.isEmpty) {
        return SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  controller.mangas.isEmpty
                      ? Icons.library_books_outlined
                      : Icons.search_off_rounded,
                  size: 64,
                  color: AppColors.textHint.withAlpha(100),
                ),
                const SizedBox(height: 16),
                Text(
                  controller.mangas.isEmpty
                      ? 'La biblioteca está vacía.\n¡Agrega tu primer manga!'
                      : 'No se encontraron mangas\ncon los filtros actuales',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final manga = filtered[index];
              return _MangaCard(manga: manga)
                  .animate()
                  .fadeIn(
                    delay: Duration(milliseconds: 50 * index),
                    duration: 400.ms,
                  )
                  .slideY(
                    begin: 0.1,
                    end: 0,
                    delay: Duration(milliseconds: 50 * index),
                    duration: 400.ms,
                  );
            },
            childCount: filtered.length,
          ),
        ),
      );
    });
  }
}

class _MangaCard extends StatelessWidget {
  const _MangaCard({required this.manga});

  final MangaModel manga;

  @override
  Widget build(BuildContext context) {
    final coverService = Get.find<CoverService>();
    final hasCover = coverService.hasCover(manga.id);
    final coverPath = coverService.coverPath(manga.id);

    return GestureDetector(
      onTap: () => Get.toNamed(
        AppRoutes.mangaDetail,
        arguments: manga.id,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: AppColors.cardGradient,
          border: Border.all(
            color: AppColors.surfaceLight.withAlpha(100),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cover Image ──────────────────────
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: hasCover
                    ? Image.file(
                        File(coverPath),
                        fit: BoxFit.cover,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withAlpha(40),
                              AppColors.accentDark.withAlpha(30),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.auto_stories_rounded,
                            size: 48,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
              ),
            ),

            // ── Info Section ─────────────────────
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),

                    // Progress text
                    Text(
                      '${manga.tomosAdquiridos.length}/${manga.cantidadTomos} tomos',
                      style: TextStyle(
                        fontSize: 12,
                        color: manga.isComplete
                            ? AppColors.success
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: manga.progress,
                        minHeight: 4,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          manga.isComplete
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
