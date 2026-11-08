import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/v_palette.dart';
import '../../core/theme/v_text.dart';
import '../../core/widgets/v_ink.dart';
import '../../core/widgets/v_list.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../common/app_icon.dart';
import '../common/popup.dart';
import '../home/home_grid.dart';

/// The hidden apps, behind a passcode. Spread two fingers on Home to open.
const int passcodeLength = 4;

String _hash(String salt, String pin) =>
    sha256.convert(utf8.encode('$salt:$pin')).toString();

String _newSalt() {
  final r = Random.secure();
  return base64Url.encode([for (var i = 0; i < 16; i++) r.nextInt(256)]);
}

/// Asks for the passcode (or, if none is set yet, sets one). True when the
/// hidden apps may be shown.
Future<bool> unlockHidden(BuildContext context, WidgetRef ref) async {
  final ok = await Navigator.of(
    context,
  ).push<bool>(BlurPopupRoute<bool>(builder: (_) => const _PasscodeScreen()));
  return ok ?? false;
}

/// Spread on Home: passcode, then the hidden apps.
Future<void> openHiddenApps(BuildContext context, WidgetRef ref) async {
  if (!await unlockHidden(context, ref) || !context.mounted) return;
  await Navigator.of(context).push(
    BlurPopupRoute<void>(
      builder: (_) => const _HiddenFolder(),
      blur: 20,
      fromScale: 0.6,
    ),
  );
}

/// Settings › Hidden apps › Change passcode: verify, then set a new one.
Future<void> changePasscode(BuildContext context, WidgetRef ref) async {
  if (!await unlockHidden(context, ref) || !context.mounted) return;
  ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(clearPasscode: true));
  await unlockHidden(context, ref);
}

enum _Step { verify, choose, confirm }

class _PasscodeScreen extends ConsumerStatefulWidget {
  const _PasscodeScreen();

  @override
  ConsumerState<_PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends ConsumerState<_PasscodeScreen>
    with SingleTickerProviderStateMixin {
  late _Step _step = ref.read(settingsProvider).hasPasscode
      ? _Step.verify
      : _Step.choose;
  String _entry = '';
  String _chosen = '';
  String? _error;

  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _wrong(String message) {
    HapticFeedback.heavyImpact();
    _shake.forward(from: 0);
    setState(() {
      _entry = '';
      _error = message;
    });
  }

  void _digit(String d) {
    if (_entry.length >= passcodeLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entry += d;
      _error = null;
    });
    if (_entry.length == passcodeLength) _complete();
  }

  void _delete() {
    if (_entry.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  void _complete() {
    final settings = ref.read(settingsProvider);
    switch (_step) {
      case _Step.verify:
        if (_hash(settings.vaultSalt!, _entry) == settings.vaultHash) {
          Navigator.of(context).pop(true);
        } else {
          _wrong('Wrong passcode');
        }
      case _Step.choose:
        setState(() {
          _chosen = _entry;
          _entry = '';
          _step = _Step.confirm;
        });
      case _Step.confirm:
        if (_entry != _chosen) {
          setState(() => _step = _Step.choose);
          _wrong('Those didn’t match. Choose again.');
          return;
        }
        final salt = _newSalt();
        ref
            .read(settingsProvider.notifier)
            .update(
              (s) =>
                  s.copyWith(passcode: (hash: _hash(salt, _entry), salt: salt)),
            );
        Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = VInk.of(context);
    final (eyebrow, title) = switch (_step) {
      _Step.verify => ('Hidden apps', 'Enter passcode'),
      _Step.choose => ('Hidden apps', 'Choose a passcode'),
      _Step.confirm => ('Hidden apps', 'Enter it again'),
    };

    Widget key(String label, {VoidCallback? onTap, Widget? child}) => Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: child == null
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ink),
                )
              : null,
          child:
              child ??
              Text(label, style: VText.doto(30, weight: 800, height: 1)),
        ),
      ),
    );

    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return GestureDetector(
      onTap: () {},
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(eyebrow.toUpperCase(), style: VText.eyebrow),
              const SizedBox(height: 10),
              Text(title, style: VText.doto(32, weight: 800, height: 1)),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: _shake,
                builder: (context, child) => Transform.translate(
                  offset: Offset(
                    sin(_shake.value * pi * 6) * 12 * (1 - _shake.value),
                    0,
                  ),
                  child: child,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < passcodeLength; i++)
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.symmetric(horizontal: 9),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _entry.length ? ink : null,
                          border: Border.all(color: ink),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: Center(
                  child: Text(
                    _error ?? '',
                    style: VText.inter(13, weight: 500),
                  ),
                ),
              ),
              for (final row in rows) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final d in row) ...[
                      key(d, onTap: () => _digit(d)),
                      if (d != row.last) const SizedBox(width: 22),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  key(
                    'Cancel',
                    onTap: () => Navigator.of(context).pop(false),
                    child: Text('Cancel', style: VText.inter(14, weight: 500)),
                  ),
                  const SizedBox(width: 22),
                  key('0', onTap: () => _digit('0')),
                  const SizedBox(width: 22),
                  key(
                    'Delete',
                    onTap: _delete,
                    child: Text('Delete', style: VText.inter(14, weight: 500)),
                  ),
                ],
              ),
              if (_step != _Step.verify) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'You’ll enter this when you spread two fingers on Home to see your hidden apps.',
                    textAlign: TextAlign.center,
                    style: VText.secondary.copyWith(color: ink),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The hidden apps as a folder in the middle of the screen: a glass card
/// that grows out of the centre, with the apps in the layout's grid.
class _HiddenFolder extends ConsumerWidget {
  const _HiddenFolder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(settingsProvider.select((s) => s.hidden));
    final apps = [
      for (final a in ref.watch(appsProvider).value ?? const <AppEntry>[])
        if (hidden.contains(a.key)) a,
    ];
    final layout = ref.watch(activeLayoutProvider);
    final cols = layout.columns;
    final ink = VInk.of(context);
    final size = MediaQuery.sizeOf(context);

    final grid = apps.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: VFootnote(
              'Nothing hidden yet. Long-press an app and choose Hide.',
              center: true,
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r * cols < apps.length; r++) ...[
                if (r > 0) const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var c = 0; c < cols; c++)
                      r * cols + c < apps.length
                          ? AppTile(
                              app: apps[r * cols + c],
                              style: layout.icons,
                              onOpened: () => Navigator.of(context).maybePop(),
                            )
                          : const SizedBox(width: homeIconSize),
                  ],
                ),
              ],
            ],
          );

    return Center(
      child: GestureDetector(
        onTap: () {},
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: size.width - 40,
            maxHeight: size.height * 0.7,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                decoration: BoxDecoration(
                  color: VPalette.of(context).glassSheet,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: ink),
                ),
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${apps.length} HIDDEN', style: VText.eyebrow),
                    const SizedBox(height: 6),
                    Text(
                      'Hidden apps',
                      style: VText.doto(28, weight: 800, height: 1),
                    ),
                    const SizedBox(height: 22),
                    Flexible(child: SingleChildScrollView(child: grid)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
