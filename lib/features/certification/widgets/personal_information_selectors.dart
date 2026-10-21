import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../identity_design.dart';
import '../personal_information_models.dart';
import 'certification_single_select_sheet.dart';

Future<PersonalInformationOption?> showPersonalInformationOptionSheet({
  required BuildContext context,
  required String title,
  required List<PersonalInformationOption> options,
  String? selectedValue,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<PersonalInformationOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.identitySheetBarrier,
    builder: (_) => CertificationSingleSelectSheet(
      title: title,
      options: options,
      selectedValue: selectedValue,
    ),
  );
}

Future<String?> showPersonalInformationAddressSheet({
  required BuildContext context,
  required List<PersonalAddressNode> nodes,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.identitySheetBarrier,
    builder: (_) => _AddressSheet(nodes: nodes),
  );
}

class _AddressSheet extends StatefulWidget {
  const _AddressSheet({required this.nodes});

  final List<PersonalAddressNode> nodes;

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  final List<PersonalAddressNode> _parents = <PersonalAddressNode>[];
  PersonalAddressNode? _selected;

  List<PersonalAddressNode> get _options =>
      _parents.isEmpty ? widget.nodes : _parents.last.children;

  @override
  Widget build(BuildContext context) {
    final metrics = IdentityMetrics(
      screenWidth: MediaQuery.sizeOf(context).width,
      safeTop: MediaQuery.paddingOf(context).top,
    );
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Container(
        key: const Key('personal-address-sheet'),
        width: double.infinity,
        height: metrics.size(521),
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
                key: const Key('personal-address-back'),
                behavior: HitTestBehavior.opaque,
                onTap: _back,
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
              height: metrics.size(320),
              child: _options.isEmpty
                  ? Center(
                      child: Text(
                        'No options available',
                        style: TextStyle(
                          color: AppColors.personalInformationHint,
                          fontSize: metrics.size(16),
                        ),
                      ),
                    )
                  : ListView.separated(
                      key: ValueKey<int>(_parents.length),
                      padding: EdgeInsets.zero,
                      clipBehavior: Clip.none,
                      itemCount: _options.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(height: metrics.size(20)),
                      itemBuilder: (context, index) {
                        final node = _options[index];
                        return _AddressOption(
                          node: node,
                          metrics: metrics,
                          selected: node.id == _selected?.id,
                          onTap: () => setState(() => _selected = node),
                        );
                      },
                    ),
            ),
            Positioned(
              left: metrics.size(78),
              top: metrics.size(415),
              child: IdentitySubmitButton(
                key: const Key('personal-address-submit'),
                metrics: metrics,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _back() {
    if (_parents.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _selected = _parents.removeLast();
    });
  }

  void _submit() {
    final selected = _selected;
    if (selected == null) return;
    if (selected.children.isNotEmpty) {
      setState(() {
        _parents.add(selected);
        _selected = null;
      });
      return;
    }
    Navigator.of(context).pop(
      <String>[..._parents.map((node) => node.label), selected.label].join('-'),
    );
  }
}

class _AddressOption extends StatelessWidget {
  const _AddressOption({
    required this.node,
    required this.metrics,
    required this.selected,
    required this.onTap,
  });

  final PersonalAddressNode node;
  final IdentityMetrics metrics;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey<String>('personal-address-${node.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: metrics.size(327),
            height: metrics.size(48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.homeCardSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(metrics.size(8)),
              border: Border.all(
                color: AppColors.identityCardBorder,
                width: metrics.size(1),
              ),
            ),
            child: Text(
              node.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? AppColors.identityTitle
                    : AppColors.personalInformationLabel,
                fontSize: metrics.size(16),
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                height: 20 / 16,
              ),
            ),
          ),
          if (selected)
            Positioned(
              right: metrics.size(1),
              top: -metrics.size(5),
              width: metrics.size(10),
              height: metrics.size(10),
              child: const DecoratedBox(
                decoration: BoxDecoration(
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
