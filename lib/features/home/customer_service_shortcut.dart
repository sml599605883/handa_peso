import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// 首页与借款进度页共用的客服入口。
class CustomerServiceShortcut extends StatelessWidget {
  const CustomerServiceShortcut({
    required this.onTap,
    this.buttonKey,
    super.key,
  });

  static const double size = 32;

  final VoidCallback onTap;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Customer Service',
      child: GestureDetector(
        key: buttonKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(5),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Image(
            image: AssetImage('assets/mine_service_customer_service.png'),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
