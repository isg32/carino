import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/v_ink.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../common/app_icon.dart';

/// Side padding of a Home row for a column count, so the favourites grid and
/// the dock line up column for column.
double homeRowPadding(int columns) => switch (columns) {
  <= 3 => 64,
  4 => 36,
  _ => 22,
};

const double homeIconSize = 56;

/// What a Home slot does when long-pressed outside edit mode.
typedef SlotMenu = void Function(BuildContext context, AppEntry app, Rect rect);

/// One row of Home slots (a favourites row or the dock). Slots are numbered
/// across favourites then dock, so they can be swapped by dragging.
class HomeRow extends ConsumerWidget {
  const HomeRow({
    super.key,
    required this.keys,
    required this.firstSlot,
    required this.layout,
    required this.editing,
    required this.labels,
    this.onMenu,
    this.onPickEmpty,
  });

  final List<String?> keys;
  final int firstSlot;
  final HomeLayout layout;
  final bool editing;
  final bool labels;
  final SlotMenu? onMenu;
  final void Function(int slot)? onPickEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(appIndexProvider);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: homeRowPadding(layout.columns)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < keys.length; i++)
            _Slot(
              slot: firstSlot + i,
              app: keys[i] == null ? null : apps[keys[i]],
              layout: layout,
              editing: editing,
              label: labels,
              onMenu: onMenu,
              onPickEmpty: onPickEmpty,
            ),
        ],
      ),
    );
  }
}

class _Slot extends ConsumerWidget {
  const _Slot({
    required this.slot,
    required this.app,
    required this.layout,
    required this.editing,
    required this.label,
    this.onMenu,
    this.onPickEmpty,
  });

  final int slot;
  final AppEntry? app;
  final HomeLayout layout;
  final bool editing;
  final bool label;
  final SlotMenu? onMenu;
  final void Function(int slot)? onPickEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = this.app;
    final labelGap = label ? 24.0 : 0.0;

    if (!editing) {
      if (app == null) {
        return SizedBox(width: homeIconSize, height: homeIconSize + labelGap);
      }
      return AppTile(
        app: app,
        style: layout.icons,
        blur: layout.iconBlur,
        label: label,
        onLongPress: onMenu == null ? null : (c, r) => onMenu!(c, app, r),
      );
    }

    final notifier = ref.read(layoutsProvider.notifier);
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != slot,
      onAcceptWithDetails: (d) {
        HapticFeedback.selectionClick();
        notifier.swapSlots(d.data, slot);
      },
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        if (app == null) {
          return EmptySlot(
            highlight: hovering,
            onTap: () => onPickEmpty?.call(slot),
          );
        }
        final tile = _EditTile(
          app: app,
          layout: layout,
          label: label,
          onRemove: () => notifier.removeFromHome(app.key),
        );
        return LongPressDraggable<int>(
          data: slot,
          delay: const Duration(milliseconds: 160),
          onDragStarted: HapticFeedback.mediumImpact,
          feedback: Transform.rotate(
            angle: -0.1,
            child: AppGlyph(app: app, size: 64, lifted: true),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: tile),
          child: Opacity(opacity: hovering ? 0.5 : 1, child: tile),
        );
      },
    );
  }
}

class _EditTile extends StatelessWidget {
  const _EditTile({
    required this.app,
    required this.layout,
    required this.label,
    required this.onRemove,
  });

  final AppEntry app;
  final HomeLayout layout;
  final bool label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
          child: AppTile(app: app, style: layout.icons, label: label),
        ),
        Positioned(
          top: -6,
          left: -6,
          child: _RemoveBadge(onTap: onRemove, label: 'Remove ${app.label}'),
        ),
      ],
    );
  }
}

class _RemoveBadge extends StatelessWidget {
  const _RemoveBadge({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: VInk.of(context),
            shape: BoxShape.circle,
          ),
          child: Container(
            width: 10,
            height: 2,
            color: VInk.surfaceOf(context),
          ),
        ),
      ),
    );
  }
}
