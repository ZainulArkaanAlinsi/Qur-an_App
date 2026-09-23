import 'package:flutter/widgets.dart';

/// Pengurai subset perintah path SVG yang dipakai ikon desain.
///
/// Mockup menyimpan ikonnya sebagai path SVG. Menggambarnya ulang dengan ikon
/// bawaan Flutter hanya menghasilkan bentuk yang "mirip", jadi path-nya dipakai
/// apa adanya. Proyek ini tidak memuat pustaka SVG, dan yang dibutuhkan hanya
/// perintah di bawah ini.
///
/// Didukung: M m L l H h V v C c S s Q q T t A a Z z. Perintah lain
/// dilaporkan sebagai [FormatException], bukan diam-diam digambar salah.
Path parseSvgPath(String d) {
  final cursor = _Cursor(d);
  final path = Path();
  var current = Offset.zero;
  var start = Offset.zero;
  // Titik kendali terakhir, untuk S/s dan T/t yang mencerminkannya.
  Offset? lastCubicControl;
  Offset? lastQuadControl;
  String? command;

  while (true) {
    cursor.skipSeparators();
    if (cursor.atEnd) break;
    final next = cursor.peekCommand();
    if (next != null) {
      command = next;
      cursor.advance();
    } else if (command == null) {
      throw FormatException('Path tidak diawali perintah', d, cursor.index);
    } else if (command == 'M') {
      command = 'L'; // Angka lanjutan sesudah M dibaca sebagai lineto.
    } else if (command == 'm') {
      command = 'l';
    }

    final relative = command == command.toLowerCase();
    switch (command.toUpperCase()) {
      case 'M':
        final point = cursor.point(current, relative);
        path.moveTo(point.dx, point.dy);
        current = point;
        start = point;
        lastCubicControl = null;
        lastQuadControl = null;
      case 'L':
        final point = cursor.point(current, relative);
        path.lineTo(point.dx, point.dy);
        current = point;
        lastCubicControl = null;
        lastQuadControl = null;
      case 'H':
        final x = cursor.number() + (relative ? current.dx : 0);
        current = Offset(x, current.dy);
        path.lineTo(current.dx, current.dy);
        lastCubicControl = null;
        lastQuadControl = null;
      case 'V':
        final y = cursor.number() + (relative ? current.dy : 0);
        current = Offset(current.dx, y);
        path.lineTo(current.dx, current.dy);
        lastCubicControl = null;
        lastQuadControl = null;
      case 'C':
        final c1 = cursor.point(current, relative);
        final c2 = cursor.point(current, relative);
        final end = cursor.point(current, relative);
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        current = end;
        lastCubicControl = c2;
        lastQuadControl = null;
      case 'S':
        final c1 = lastCubicControl == null
            ? current
            : current * 2 - lastCubicControl;
        final c2 = cursor.point(current, relative);
        final end = cursor.point(current, relative);
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        current = end;
        lastCubicControl = c2;
        lastQuadControl = null;
      case 'Q':
        final control = cursor.point(current, relative);
        final end = cursor.point(current, relative);
        path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
        current = end;
        lastQuadControl = control;
        lastCubicControl = null;
      case 'T':
        final control = lastQuadControl == null
            ? current
            : current * 2 - lastQuadControl;
        final end = cursor.point(current, relative);
        path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
        current = end;
        lastQuadControl = control;
        lastCubicControl = null;
      case 'A':
        final rx = cursor.number();
        final ry = cursor.number();
        final rotation = cursor.number();
        final largeArc = cursor.flag();
        final sweep = cursor.flag();
        final end = cursor.point(current, relative);
        path.arcToPoint(
          end,
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: largeArc,
          clockwise: sweep,
        );
        current = end;
        lastCubicControl = null;
        lastQuadControl = null;
      case 'Z':
        path.close();
        current = start;
        lastCubicControl = null;
        lastQuadControl = null;
      default:
        throw FormatException(
          'Perintah path "$command" tidak didukung',
          d,
          cursor.index,
        );
    }
  }
  return path;
}

class _Cursor {
  _Cursor(this.source);

  final String source;
  int index = 0;

  static final _letter = RegExp(r'[A-Za-z]');
  static final _digit = RegExp(r'[0-9]');

  bool get atEnd => index >= source.length;

  void advance() => index++;

  void skipSeparators() {
    while (!atEnd) {
      final c = source[index];
      if (c == ' ' || c == ',' || c == '\n' || c == '\t' || c == '\r') {
        index++;
      } else {
        break;
      }
    }
  }

  /// Huruf perintah pada posisi sekarang, atau null bila berupa angka.
  String? peekCommand() {
    final c = source[index];
    return _letter.hasMatch(c) ? c : null;
  }

  double number() {
    skipSeparators();
    final start = index;
    if (!atEnd && (source[index] == '-' || source[index] == '+')) index++;
    var seenDot = false;
    while (!atEnd) {
      final c = source[index];
      if (_digit.hasMatch(c)) {
        index++;
      } else if (c == '.' && !seenDot) {
        seenDot = true;
        index++;
      } else if ((c == 'e' || c == 'E') && index > start) {
        index++;
        if (!atEnd && (source[index] == '-' || source[index] == '+')) index++;
      } else {
        break;
      }
    }
    final value = double.tryParse(source.substring(start, index));
    if (value == null) {
      throw FormatException('Angka tidak valid pada path', source, start);
    }
    return value;
  }

  /// Flag busur hanya satu digit, dan boleh menempel dengan angka sesudahnya.
  bool flag() {
    skipSeparators();
    final c = source[index];
    if (c != '0' && c != '1') {
      throw FormatException('Flag busur harus 0 atau 1', source, index);
    }
    index++;
    return c == '1';
  }

  Offset point(Offset current, bool relative) {
    final x = number();
    final y = number();
    return relative ? Offset(current.dx + x, current.dy + y) : Offset(x, y);
  }
}

/// Ikon garis yang digambar dari path SVG mockup pada viewBox 24×24.
class LineIcon extends StatelessWidget {
  const LineIcon(
    this.paths, {
    super.key,
    required this.color,
    this.size = 24,
    this.strokeWidth = 2,
    this.filled = false,
    this.semanticsLabel,
  });

  /// Satu ikon bisa terdiri dari beberapa path, seperti di mockup.
  final List<String> paths;
  final Color color;
  final double size;
  final double strokeWidth;

  /// Ikon isi (mis. tombol putar) memakai fill, bukan stroke.
  final bool filled;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final icon = CustomPaint(
      size: Size.square(size),
      painter: _LineIconPainter(
        paths: [for (final d in paths) parseSvgPath(d)],
        color: color,
        strokeWidth: strokeWidth,
        filled: filled,
      ),
    );
    return semanticsLabel == null
        ? icon
        : Semantics(label: semanticsLabel, child: icon);
  }
}

class _LineIconPainter extends CustomPainter {
  _LineIconPainter({
    required this.paths,
    required this.color,
    required this.strokeWidth,
    required this.filled,
  });

  final List<Path> paths;
  final Color color;
  final double strokeWidth;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    if (filled) {
      paint.style = PaintingStyle.fill;
    } else {
      paint
        ..style = PaintingStyle.stroke
        // Lebar garis ikut diskalakan supaya ikon kecil tidak jadi tebal.
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }
    canvas.save();
    canvas.scale(scale);
    for (final path in paths) {
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LineIconPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.filled != filled ||
      old.paths.length != paths.length;
}
