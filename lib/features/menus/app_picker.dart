import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/v_icons.dart';
import '../../core/theme/v_text.dart';
import '../../core/widgets/v_buttons.dart';
import '../../core/widgets/v_ink.dart';
import '../../core/widgets/v_surface.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../common/app_icon.dart';
import '../common/popup.dart';

/// Picks an app for an empty Home slot.
Future<AppEntry?> pickApp(BuildContext context) =>
    showBlurPopup<AppEntry>(context, (_) => const _AppPicker(), sheet: true);

class _AppPicker extends ConsumerStatefulWidget {
  const _AppPicker();

  @override
  ConsumerState<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends ConsumerState<_AppPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(visibleAppsProvider);
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? apps
        : [
            for (final a in apps)
              if (a.label.toLowerCase().contains(q)) a,
          ];
    final ink = VInk.of(context);
    return CarinoSheet(
      title: 'Add to Home',
      scroll: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VOutlined(
            radius: 22,
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const VIconView(VIcon.search, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CupertinoTextField(
                      padding: EdgeInsets.zero,
                      decoration: null,
                      cursorColor: ink,
                      placeholder: 'Find an app',
                      placeholderStyle: VText.inter(
                        14,
                        weight: 300,
                      ).copyWith(color: ink.withValues(alpha: 0.7)),
                      style: VText.inter(14).copyWith(color: ink),
                      onChanged: (v) => setState(() => _q = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: list.length,
              separatorBuilder: (_, _) => const VDivider(),
              itemBuilder: (context, i) => VTappable(
                onTap: () => Navigator.of(context).pop(list[i]),
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      const SizedBox(width: 6),
                      AppGlyph(app: list[i], size: 34),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          list[i].label,
                          style: VText.rowTitle,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
