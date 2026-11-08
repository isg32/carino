import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/v_icons.dart';
import '../../core/widgets/v_buttons.dart';
import '../../core/widgets/v_glass.dart';
import '../../core/widgets/v_list.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../common/popup.dart';
import '../common/wallpaper.dart';

/// Long-press a layout card: rename, use, duplicate, delete.
Future<void> showLayoutMenu(BuildContext context, HomeLayout layout) =>
    showBlurPopup<void>(context, (_) => _LayoutMenu(layout), sheet: true);

class _LayoutMenu extends ConsumerStatefulWidget {
  const _LayoutMenu(this.layout);

  final HomeLayout layout;

  @override
  ConsumerState<_LayoutMenu> createState() => _LayoutMenuState();
}

class _LayoutMenuState extends ConsumerState<_LayoutMenu> {
  late final _name = TextEditingController(text: widget.layout.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  HomeLayout get _named {
    final name = _name.text.trim();
    return widget.layout.copyWith(
      name: name.isEmpty ? widget.layout.name : name,
    );
  }

  void _save() {
    ref.read(layoutsProvider.notifier).updateLayout(_named);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${widget.layout.name}?',
      body: 'This layout, its wallpaper choice and its apps on Home are removed. Your apps stay installed.',
      action: 'Delete layout',
    );
    if (!ok || !mounted) return;
    ref.read(layoutsProvider.notifier).delete(widget.layout.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(layoutsProvider);
    final index = state.layouts.indexWhere((l) => l.id == widget.layout.id);
    final n = ref.read(layoutsProvider.notifier);
    return CarinoSheet(
      eyebrow: 'Layout ${index + 1} of ${state.layouts.length}',
      title: widget.layout.name,
      trailing: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 34,
          height: 56,
          child: WallpaperView(wallpaper: widget.layout.wallpaper),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const VEyebrow('Name'),
          const SizedBox(height: 8),
          VTextField(controller: _name, onSubmitted: (_) => _save()),
          const SizedBox(height: 16),
          VListSection(
            children: [
              VListRow(
                title: 'Use this layout',
                leading: const VIconView(VIcon.check, size: 18),
                chevron: false,
                onTap: () {
                  n.updateLayout(_named);
                  n.setActive(widget.layout.id);
                  Navigator.of(context).pop();
                },
              ),
              VListRow(
                title: 'Duplicate',
                leading: const VIconView(VIcon.copy, size: 18),
                chevron: false,
                onTap: () {
                  n.add(from: _named);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (state.layouts.length > 1) ...[
                Expanded(
                  child: VButton.ghost('Delete layout', onPressed: _delete),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(child: VButton.primary('Save', onPressed: _save)),
            ],
          ),
        ],
      ),
    );
  }
}
