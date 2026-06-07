/// Route definitions with GetX bindings.
library;

import 'package:get/get.dart';

import '../modules/home/home_binding.dart';
import '../modules/home/home_view.dart';
import '../modules/manga_detail/manga_detail_binding.dart';
import '../modules/manga_detail/manga_detail_view.dart';
import '../modules/manga_form/manga_form_binding.dart';
import '../modules/manga_form/manga_form_view.dart';
import '../modules/onboarding/onboarding_binding.dart';
import '../modules/onboarding/onboarding_view.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static final pages = <GetPage>[
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingView(),
      binding: OnboardingBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.mangaDetail,
      page: () => const MangaDetailView(),
      binding: MangaDetailBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.mangaForm,
      page: () => const MangaFormView(),
      binding: MangaFormBinding(),
      transition: Transition.downToUp,
    ),
  ];
}
