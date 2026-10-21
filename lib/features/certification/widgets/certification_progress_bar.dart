import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../identity_design.dart';

/// 认证流程通用的分段进度条（设计稿 03-03：四段 50x7、间距 8）。
class CertificationProgressBar extends StatelessWidget {
  const CertificationProgressBar({
    required this.metrics,
    this.segmentCount = 4,
    this.activeSegments = 1,
    super.key,
  });

  final IdentityMetrics metrics;
  final int segmentCount;
  final int activeSegments;

  @override
  Widget build(BuildContext context) {
    final total = segmentCount < 1 ? 1 : segmentCount;
    final active = activeSegments.clamp(0, total);
    return Row(
      key: const Key('certification-progress-bar'),
      children: <Widget>[
        for (var index = 0; index < total; index++) ...<Widget>[
          Expanded(
            child: Container(
              height: metrics.size(7),
              decoration: BoxDecoration(
                color: index < active
                    ? null
                    : AppColors.certificationProgressInactive,
                gradient: index < active
                    ? AppColors.certificationProgressActive
                    : null,
                borderRadius: BorderRadius.circular(metrics.size(4)),
              ),
            ),
          ),
          if (index != total - 1) SizedBox(width: metrics.size(8)),
        ],
      ],
    );
  }
}
