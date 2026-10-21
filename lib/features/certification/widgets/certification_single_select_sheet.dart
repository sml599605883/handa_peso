import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../identity_design.dart';
import '../personal_information_models.dart';

/// 认证流程共用的单选底部弹层（设计稿 03-05）。
///
/// 选项行把服务端下发的 `headway` logo 作为可选内容；URL 为空时不创建 logo
/// 节点和间距，文案直接从行内边距开始，避免留下空白占位。
class CertificationSingleSelectSheet extends StatefulWidget {
  const CertificationSingleSelectSheet({
    required this.options,
    this.title = '',
    this.selectedValue,
    super.key,
  });

  final List<PersonalInformationOption> options;
  final String title;
  final String? selectedValue;

  @override
  State<CertificationSingleSelectSheet> createState() =>
      _CertificationSingleSelectSheetState();
}

class _CertificationSingleSelectSheetState
    extends State<CertificationSingleSelectSheet> {
  late PersonalInformationOption? _selected = _findSelected(
    widget.options,
    widget.selectedValue,
  );

  static PersonalInformationOption? _findSelected(
    List<PersonalInformationOption> options,
    String? value,
  ) {
    for (final option in options) {
      if (option.value == value || option.label == value) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final metrics = IdentityMetrics(
      screenWidth: MediaQuery.sizeOf(context).width,
      safeTop: MediaQuery.paddingOf(context).top,
    );
    return Semantics(
      label: widget.title.isEmpty ? 'Single select' : widget.title,
      child: Container(
        key: const Key('certification-single-select-sheet'),
        width: double.infinity,
        height: metrics.size(385),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(metrics.size(24)),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: AppColors.identitySheetShadow,
              offset: Offset(0, -1),
              blurRadius: 8,
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: metrics.size(24),
              top: metrics.size(14),
              width: metrics.size(24),
              height: metrics.size(24),
              child: GestureDetector(
                key: const Key('certification-single-select-back'),
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Transform.rotate(
                  angle: math.pi,
                  child: Image.asset(
                    IdentityAssets.fieldChevron,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              left: metrics.size(24),
              top: metrics.size(71),
              width: metrics.size(327),
              height: metrics.size(184),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                clipBehavior: Clip.none,
                itemCount: widget.options.length,
                separatorBuilder: (_, _) => SizedBox(height: metrics.size(20)),
                itemBuilder: (context, index) {
                  final option = widget.options[index];
                  return CertificationSingleSelectOptionRow(
                    option: option,
                    metrics: metrics,
                    selected: option == _selected,
                    onTap: () => setState(() => _selected = option),
                  );
                },
              ),
            ),
            Positioned(
              left: metrics.size(78),
              top: metrics.size(279),
              child: IdentitySubmitButton(
                key: const Key('certification-single-select-submit'),
                metrics: metrics,
                label: 'Submit',
                onPressed: () => Navigator.of(context).pop(_selected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单选弹层中的一行；独立出来便于后续绑卡等认证页复用同一套视觉。
class CertificationSingleSelectOptionRow extends StatelessWidget {
  const CertificationSingleSelectOptionRow({
    required this.option,
    required this.metrics,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final PersonalInformationOption option;
  final IdentityMetrics metrics;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final logoUrl = option.logoUrl.trim();
    return GestureDetector(
      key: ValueKey<String>('certification-option-${option.value}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: metrics.size(327),
            height: metrics.size(48),
            padding: EdgeInsets.symmetric(horizontal: metrics.size(13)),
            decoration: BoxDecoration(
              color: selected ? AppColors.homeCardSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(metrics.size(8)),
              border: Border.all(
                color: AppColors.identityCardBorder,
                width: metrics.size(1),
              ),
            ),
            child: Row(
              children: <Widget>[
                if (logoUrl.isNotEmpty) ...<Widget>[
                  _OptionLogo(
                    optionKey: option.value,
                    url: logoUrl,
                    metrics: metrics,
                  ),
                  SizedBox(width: metrics.size(12)),
                ],
                Expanded(
                  child: Text(
                    option.label,
                    key: ValueKey<String>(
                      'certification-option-label-${option.value}',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? AppColors.identityTitle
                          : AppColors.identitySheetUnselectedText,
                      fontSize: metrics.size(16),
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.normal,
                      height: 20 / 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Positioned(
              right: metrics.size(1),
              top: -metrics.size(5),
              width: metrics.size(10),
              height: metrics.size(10),
              child: DecoratedBox(
                key: ValueKey<String>(
                  'certification-option-selected-${option.value}',
                ),
                decoration: const BoxDecoration(
                  color: AppColors.identitySheetMarker,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OptionLogo extends StatelessWidget {
  const _OptionLogo({
    required this.optionKey,
    required this.url,
    required this.metrics,
  });

  final String optionKey;
  final String url;
  final IdentityMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: ValueKey<String>('certification-option-logo-$optionKey'),
      borderRadius: BorderRadius.circular(metrics.size(4)),
      child: Image.network(
        url,
        width: metrics.size(32),
        height: metrics.size(32),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}
