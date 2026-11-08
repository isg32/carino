import 'package:flutter/widgets.dart';
import 'package:path_drawing/path_drawing.dart';

import '../widgets/v_ink.dart';

/// Cariño's line icons (Veronica's set), drawn on a 24 × 24 grid.
enum VIcon {
  home('M4 11l8-7l8 7v8a1 1 0 0 1-1 1h-4v-6h-6v6H5a1 1 0 0 1-1-1z'),
  library('M5 4v16M10 4v16M14.5 4.5l4.5 15'),
  wave('M4 10v4M8 7v10M12 4v16M16 8v8M20 11v2'),
  playing('M6 10v4M12 6v12M18 9v6'),
  play('M8 5v14l11-7z'),
  pause('M8 5v14M16 5v14'),
  previous('M18 6v12l-9-6zM6 6v12'),
  next('M6 6v12l9-6zM18 6v12'),
  shuffle(
    'M4 7h3c5 0 5 10 10 10h3M4 17h3c1.6 0 2.7-1 3.6-2.3'
    'M13.4 9.3C14.3 8 15.4 7 17 7h3M17 4l3 3l-3 3M17 14l3 3l-3 3',
  ),
  loop(
    'M17 2l4 4l-4 4M3 11V9a3 3 0 0 1 3-3h15M7 22l-4-4l4-4'
    'M21 13v2a3 3 0 0 1-3 3H3M11 10.5l1.5-1v5',
  ),
  loopAll(
    'M17 2l4 4l-4 4M3 11V9a3 3 0 0 1 3-3h15M7 22l-4-4l4-4'
    'M21 13v2a3 3 0 0 1-3 3H3',
  ),
  repeatCount('M12 4a8 8 0 1 0 8 8M20 4v4h-4M10 10.5l1.5-1v5'),
  timer('M12 5a8 8 0 1 0 0 16a8 8 0 1 0 0-16M12 9v4l3 2M10 2h4'),
  queue('M4 6h16M4 12h16M4 18h10'),
  playNext('M4 6h12M4 12h12M4 18h7M17 15v6M14 18h6'),
  pin('M5 3h14v18l-7-5l-7 5z'),
  cached('M12 4v11M7 10l5 5l5-5M5 20h14'),
  notCached('M12 4a8 8 0 1 0 0 16a8 8 0 1 0 0-16'),
  sync('M20 11a8 8 0 0 0-14.6-4.5M4 4v3h3M4 13a8 8 0 0 0 14.6 4.5M20 20v-3h-3'),
  external(
    'M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7'
    'a1 1 0 0 1 1-1h5',
  ),
  trash('M5 7h14M9 7V4h6v3M7 7l1 13h8l1-13'),
  drag('M5 9h14M5 15h14'),
  down('M6 9l6 6l6-6'),
  offline(
    'M2 8.5a15 15 0 0 1 20 0M5.5 12a10 10 0 0 1 13 0M9 15.5a5 5 0 0 1 6 0'
    'M12 19h.01M3 3l18 18',
  ),
  spinner('M12 3a9 9 0 1 0 9 9'),
  gear(
    'M12 9a3 3 0 1 0 0 6a3 3 0 1 0 0-6M12 2v3M12 19v3M2 12h3M19 12h3'
    'M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1',
  ),
  apps('M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z'),
  widgets('M3.5 3.5h17v9h-17zM3.5 15.5h7.5v5H3.5zM13 15.5h7.5v5H13z'),
  list('M4 6h16M4 12h16M4 18h16'),
  info('M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0M12 11v5.5M12 7.5h.01'),
  hide(
    'M3 12s3.5-6 9-6s9 6 9 6s-3.5 6-9 6s-9-6-9-6zM9.5 12a2.5 2.5 0 1 0 5 0'
    'a2.5 2.5 0 1 0-5 0M4 4l16 16',
  ),
  edit('M4 20h4L19 9l-4-4L4 16zM13.5 6.5l4 4'),
  wifi(
    'M2.5 9a14 14 0 0 1 19 0M5.5 12.5a9.5 9.5 0 0 1 13 0M8.5 16a5 5 0 0 1 7 0M12 19.5h.01',
  ),
  bluetooth('M7 7l10 10l-5 4V3l5 4L7 17'),
  torch('M8 3h8v4l-2 3v11h-4V10L8 7z'),
  moon('M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z'),
  clock('M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0M12 7v5l3.5 2'),
  calendar('M4 5.5h16v15H4zM4 10h16M8.5 3v4M15.5 3v4'),
  battery('M3 8h15v8H3zM20.5 10.5v3'),
  cloud('M7 18a4 4 0 0 1-.5-8A5.5 5.5 0 0 1 17 9a4.5 4.5 0 0 1 .5 9z'),
  image(
    'M3.5 4.5h17v15h-17zM3.5 16l5-5l4 4l2.5-2.5l5.5 5.5M14.5 8.5a1.5 1.5 0 1 0 3 0'
    'a1.5 1.5 0 1 0-3 0',
  ),
  copy('M8 8h12v12H8zM4 16V4h12'),
  lock('M5.5 10.5h13v10h-13zM8.5 10.5V7a3.5 3.5 0 0 1 7 0v3.5'),
  bell(
    'M6 9a6 6 0 0 1 12 0c0 6 2.5 8 2.5 8h-17S6 15 6 9zM10 20.5a2 2 0 0 0 4 0',
  ),
  person('M8 8a4 4 0 1 0 8 0a4 4 0 1 0-8 0M4.5 20.5a7.5 7.5 0 0 1 15 0'),
  globe(
    'M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0M3 12h18M12 3c2.5 2.5 3.5 5.5 3.5 9'
    's-1 6.5-3.5 9c-2.5-2.5-3.5-5.5-3.5-9S9.5 5.5 12 3',
  ),
  internet('M6 20V14M10 20V10M14 20V7M18 20V4'),
  volume(
    'M4 9.5h4l5-4.5v14l-5-4.5H4zM16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12',
  ),
  camera(
    'M3.5 7.5h4L9 5h6l1.5 2.5h4v12h-17zM8.5 13a3.5 3.5 0 1 0 7 0a3.5 3.5 0 1 0-7 0',
  ),
  alarm(
    'M12 6a7.5 7.5 0 1 0 0 15a7.5 7.5 0 1 0 0-15M12 10v4l2.5 1.5M4 5l3-2.5M20 5l-3-2.5',
  ),
  up('M12 19V5M6 11l6-6l6 6'),
  downArrow('M12 5v14M6 13l6 6l6-6'),
  swipeUp('M6 15l6-6l6 6'),
  home2('M3.5 10.5L12 3.5l8.5 7v10h-6v-6h-5v6h-6z'),
  music(
    'M9 18V5.5l11-2V16M6 18a3 3 0 1 0 6 0a3 3 0 1 0-6 0M14 16a3 3 0 1 0 6 0'
    'a3 3 0 1 0-6 0',
  ),
  plus('M12 5v14M5 12h14'),
  minus('M5 12h14'),
  chevron('M9 6l6 6l-6 6'),
  back('M15 6l-6 6l6 6'),
  check('M5 12l5 5l9-10'),
  search('M11 4a7 7 0 1 0 0 14a7 7 0 1 0 0-14M16 16l5 5'),
  close('M6 6l12 12M18 6L6 18');

  const VIcon(this.svgPath);

  final String svgPath;

  static final Map<VIcon, Path> _cache = {};

  Path get path => _cache.putIfAbsent(this, () => parseSvgPathData(svgPath));
}

/// Draws a [VIcon] in the current ink colour.
///
/// [strokeWidth] is in grid units, like the SVG `stroke-width` in the design
/// (1.5 idle, 2 inside a selected pill).
class VIconView extends StatelessWidget {
  const VIconView(
    this.icon, {
    super.key,
    this.size = 20,
    this.strokeWidth = 1.5,
    this.color,
  });

  final VIcon icon;
  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _IconPainter(
          path: icon.path,
          color: color ?? VInk.of(context),
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter({
    required this.path,
    required this.color,
    required this.strokeWidth,
  });

  final Path path;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.path != path || old.color != color || old.strokeWidth != strokeWidth;
}
