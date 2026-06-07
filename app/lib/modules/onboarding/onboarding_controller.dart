import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../../services/user_service.dart';

class OnboardingController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final isLoading = false.obs;

  final userService = Get.find<UserService>();

  Future<void> saveAlias() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    await userService.saveAlias(nameController.text);
    isLoading.value = false;

    Get.offAllNamed(AppRoutes.home);
  }

  @override
  void onClose() {
    nameController.dispose();
    super.onClose();
  }
}
