import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/bootstrap/app_bootstrap.dart';

/// Entry gate: restores the persisted session and routes to login or the shell.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSession());
  }

  Future<void> _restoreSession() async {
    final dependencies = Get.find<AppDependencies>();
    final sessionId = await dependencies.sessionStore.sessionId();
    if (!mounted) return;
    if (sessionId.isEmpty) {
      await Get.offAllNamed<void>(AppRoutes.login);
    } else {
      await Get.offAllNamed<void>(AppRoutes.main);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Handa Peso',
              style: TextStyle(
                color: AppColors.textOnPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(
                color: AppColors.textOnPrimary,
                strokeWidth: 2.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
