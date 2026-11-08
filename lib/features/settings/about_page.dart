import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../../core/theme/v_text.dart';
import '../../core/widgets/v_ink.dart';
import '../../core/widgets/v_list.dart';
import '../../core/widgets/v_page.dart';
import '../../core/widgets/v_surface.dart';
import '../../platform/launcher.dart';

/// The version shown in About (keep in step with pubspec.yaml).
const String carinoVersion = '1.0.0';

const _source = 'https://github.com/isg32/carino';

/// About Cariño: the mark, what it is, the licences and who made it (as in
/// Veronica's and Idris's About). Reached from Customise and from Settings.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key, this.backLabel = 'Settings'});

  final String backLabel;

  static const _licences = [
    ('Cariño', 'GPL-3.0'),
    ('Doto', 'OFL'),
    ('Inter', 'OFL'),
    ('Flutter', 'BSD-3'),
    ('flutter_riverpod', 'MIT'),
    ('shared_preferences', 'BSD-3'),
    ('intl', 'BSD-3'),
    ('path_drawing', 'MIT'),
  ];

  @override
  Widget build(BuildContext context) {
    return VDetailPage(
      backLabel: backLabel,
      title: 'About',
      children: [
        const _AppMark(),
        VListSection(
          header: const VEyebrow('Developer'),
          children: [
            VListRow(
              leading: ClipOval(
                child: Image.asset(
                  'assets/images/developer.jpg',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
              title: 'Sapan Gajjar',
              subtitle: "You've probably guessed who made this app",
              chevron: false,
            ),
            for (final (title, handle, url) in const [
              ('GitHub', 'isg32', 'https://github.com/isg32'),
              (
                'LinkedIn',
                'sapangajjar101105',
                'https://www.linkedin.com/in/sapangajjar101105/',
              ),
            ])
              VListRow(
                title: title,
                value: handle,
                onTap: () => Launcher.openUrl(url),
              ),
          ],
        ),
        VListSection(
          header: const VEyebrow('Open source'),
          children: [
            VListRow(
              title: 'Source code',
              value: 'GitHub',
              onTap: () => Launcher.openUrl(_source),
            ),
            VListRow(
              title: 'Report a problem',
              onTap: () => Launcher.openUrl('$_source/issues'),
            ),
          ],
        ),
        VListSection(
          header: const VEyebrow('Licences'),
          children: [
            for (final (name, licence) in _licences)
              VListRow(title: name, value: licence),
            VListRow(
              title: 'Every licence in full',
              onTap: () => showLicensePage(context),
            ),
          ],
        ),
        const VFootnote(
          "'No One noticed' & 'Sienna' are my favourites, but 'Cariño' suits as the name!"
          "Listen to The Marias, it'll change or ruin your life.",
        ),
      ],
    );
  }
}

/// The app's mark, big, with the name in Doto, the version and a line.
class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Container(
            width: 150,
            height: 150,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: VInk.of(context)),
            ),
            child: Image.asset(
              'assets/icon/mark.png',
              color: VInk.of(context),
              colorBlendMode: BlendMode.srcIn,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 18),
          Text('Cariño', style: VText.doto(40, height: 1)),
          const SizedBox(height: 8),
          Text('Version $carinoVersion', style: VText.inter(13, weight: 300)),
          const SizedBox(height: 4),
          Text(
            'A quiet home screen: black and white, with your wallpaper as the only colour.',
            textAlign: TextAlign.center,
            style: VText.secondary,
          ),
        ],
      ),
    );
  }
}

/// Licences for the bundled fonts and packages.
void showLicensePage(BuildContext context) {
  Navigator.of(context)
      .push(CupertinoPageRoute<void>(builder: (_) => const _Licences()));
}

class _Licences extends StatelessWidget {
  const _Licences();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LicenseEntry>>(
      future: LicenseRegistry.licenses.toList(),
      builder: (context, snap) {
        final entries = snap.data ?? const [];
        return VDetailPage(
          backLabel: 'About',
          title: 'Licences',
          children: [
            const VFootnote(
              'Doto and Inter: SIL Open Font License. Cariño: GPL-3.0.',
            ),
            for (final e in entries.take(60))
              VCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.packages.join(', '), style: VText.rowTitle),
                    const SizedBox(height: 6),
                    Text(
                      e.paragraphs.map((p) => p.text).take(3).join('\n\n'),
                      style: VText.footnote,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
