// Renders the ported liquid glass shaders off-screen so the port can be verified
// without a device: `ui.ImageFilter.shader` is Impeller-only, so the shaders are
// driven directly as paint shaders here.
//
// Run with GLASS_DUMP=1 to also write PNGs for manual inspection.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const int _width = 360;
const int _height = 240;
const double _radius = 56;

/// A backdrop with hard edges and saturated colours: displacement and tint show
/// up immediately on it.
Future<ui.Image> _backdrop() {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final rect = ui.Rect.fromLTWH(0, 0, _width.toDouble(), _height.toDouble());

  canvas.drawRect(
    rect,
    ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset.zero,
        ui.Offset(_width.toDouble(), _height.toDouble()),
        const [
          ui.Color(0xFF1034A6),
          ui.Color(0xFFE040FB),
          ui.Color(0xFFFFC400),
        ],
        const [0, 0.55, 1],
      ),
  );

  // High-contrast bars: they make refraction displacement obvious.
  final stripe = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  for (var i = 0; i < 12; i++) {
    if (i.isEven) {
      canvas.drawRect(
        ui.Rect.fromLTWH(i * 30.0, 0, 12, _height.toDouble()),
        stripe,
      );
    }
  }

  // A few discs of varying size for a less regular pattern.
  final disc = ui.Paint()..color = const ui.Color(0xCC000000);
  for (var i = 0; i < 5; i++) {
    canvas.drawCircle(ui.Offset(40.0 + i * 70, 40.0 + (i % 3) * 70), 18, disc);
  }

  return recorder.endRecording().toImage(_width, _height);
}

const ui.Rect _rect = ui.Rect.fromLTWH(4, 4, _width - 8, _height - 8);
final ui.RRect _rrect = ui.RRect.fromRectAndRadius(
  _rect,
  const ui.Radius.circular(_radius),
);

Future<ui.Image> _render(ui.FragmentShader shader) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(_rect, ui.Paint()..shader = shader);
  return recorder.endRecording().toImage(_width, _height);
}

Future<ui.Image> _renderFill(
  ui.FragmentShader shader, {
  required ui.BlendMode blendMode,
}) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawRect(
      ui.Offset.zero & ui.Size(_width.toDouble(), _height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF000000),
    )
    ..drawRect(
      _rect,
      ui.Paint()
        ..shader = shader
        ..blendMode = blendMode,
    );
  return recorder.endRecording().toImage(_width, _height);
}

Future<ui.Image> _renderRim(
  ui.FragmentShader shader, {
  required ui.BlendMode blendMode,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawRect(
      ui.Offset.zero & ui.Size(_width.toDouble(), _height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF000000),
    );
  final paint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 2
    ..shader = shader
    ..blendMode = blendMode
    ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 0.5);
  canvas
    ..save()
    ..clipRRect(_rrect)
    ..drawRRect(_rrect, paint)
    ..restore();
  return recorder.endRecording().toImage(_width, _height);
}

/// Uniform set shared by the refraction tests.
void _refractionUniforms(
  ui.FragmentShader shader,
  ui.Image backdrop, {
  required double height,
  required double amount,
  required double depth,
  required double dispersion,
}) {
  shader
    ..setImageSampler(0, backdrop)
    ..setFloat(0, _width.toDouble())
    ..setFloat(1, _height.toDouble())
    ..setFloat(2, _width.toDouble())
    ..setFloat(3, _height.toDouble())
    ..setFloat(4, _radius)
    ..setFloat(5, _radius)
    ..setFloat(6, _radius)
    ..setFloat(7, _radius)
    ..setFloat(8, height)
    ..setFloat(9, amount)
    ..setFloat(10, depth)
    ..setFloat(11, dispersion);
}

Future<ui.FragmentShader> _rimShader({required bool ambient}) async {
  final program = await ui.FragmentProgram.fromAsset(
    'assets/shaders/liquid_glass_highlight.frag',
  );
  return program.fragmentShader()
    ..setFloat(0, _radius)
    ..setFloat(1, _radius)
    ..setFloat(2, _radius)
    ..setFloat(3, _radius)
    ..setFloat(4, 1) // r
    ..setFloat(5, 1) // g
    ..setFloat(6, 1) // b
    ..setFloat(7, 1) // a
    ..setFloat(8, _width.toDouble())
    ..setFloat(9, _height.toDouble())
    ..setFloat(10, math.pi / 4) // light at 45 degrees
    ..setFloat(11, 1) // falloff
    ..setFloat(12, ambient ? 1 : 0);
}

Future<void> _dump(String name, ui.Image image) async {
  if (Platform.environment['GLASS_DUMP'] != '1') {
    return;
  }
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory('glass_out')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
}

Future<List<int>> _pixel(ui.Image image, int x, int y) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final offset = (y * image.width + x) * 4;
  return data!.buffer.asUint8List(offset, 4);
}

/// Maximum red channel inside a rectangle, used to find the rim band.
Future<int> _maxRed(
  ui.Image image,
  int left,
  int top,
  int right,
  int bottom,
) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();
  var best = 0;
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      final red = bytes[(y * image.width + x) * 4];
      if (red > best) {
        best = red;
      }
    }
  }
  return best;
}

double _distance(List<int> a, List<int> b) {
  var sum = 0.0;
  for (var i = 0; i < 3; i++) {
    final d = (a[i] - b[i]).toDouble();
    sum += d * d;
  }
  return math.sqrt(sum);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ui.Image backdrop;

  setUpAll(() async {
    backdrop = await _backdrop();
  });

  tearDownAll(() => backdrop.dispose());

  test('refraction keeps the centre of the glass undistorted', () async {
    final program = await ui.FragmentProgram.fromAsset(
      'assets/shaders/liquid_glass_refraction.frag',
    );
    final shader = program.fragmentShader();
    _refractionUniforms(
      shader,
      backdrop,
      height: 40,
      amount: -30,
      depth: 1,
      dispersion: 0,
    );

    final out = await _render(shader);
    await _dump('refraction_nodispersion', out);

    final centre = await _pixel(out, _width ~/ 2, _height ~/ 2);
    final centreRef = await _pixel(backdrop, _width ~/ 2, _height ~/ 2);
    expect(
      _distance(centre, centreRef),
      lessThan(6),
      reason: 'the middle of the glass must show the backdrop unchanged',
    );

    out.dispose();
  });

  test('refraction bends the backdrop inside the lens band', () async {
    final program = await ui.FragmentProgram.fromAsset(
      'assets/shaders/liquid_glass_refraction.frag',
    );
    final shader = program.fragmentShader();
    _refractionUniforms(
      shader,
      backdrop,
      height: 40,
      amount: -40,
      depth: 0,
      dispersion: 0,
    );

    final out = await _render(shader);
    await _dump('refraction_edge', out);

    // Just inside the left edge, where the lens is active.
    final lensed = await _pixel(out, 8, _height ~/ 2);
    final plain = await _pixel(backdrop, 8, _height ~/ 2);
    expect(
      _distance(lensed, plain),
      greaterThan(12),
      reason: 'the lens band must displace backdrop pixels',
    );

    out.dispose();
  });

  test('dispersion separates colour channels in the lens band', () async {
    final program = await ui.FragmentProgram.fromAsset(
      'assets/shaders/liquid_glass_refraction.frag',
    );
    final shader = program.fragmentShader();
    _refractionUniforms(
      shader,
      backdrop,
      height: 48,
      amount: -44,
      depth: 1,
      dispersion: 1,
    );

    final out = await _render(shader);
    await _dump('refraction_dispersion', out);

    var maxSpread = 0;
    for (var y = 40; y < 200; y += 7) {
      for (var x = 6; x < 40; x += 3) {
        final p = await _pixel(out, x, y);
        final spread = math.max((p[0] - p[1]).abs(), (p[1] - p[2]).abs());
        if (spread > maxSpread) {
          maxSpread = spread;
        }
      }
    }
    expect(
      maxSpread,
      greaterThan(4),
      reason: 'chromatic aberration must separate colour channels',
    );

    out.dispose();
  });

  test('directional rim intensity peaks on the corners', () async {
    final shader = await _rimShader(ambient: false);
    final out = await _renderFill(shader, blendMode: ui.BlendMode.plus);
    await _dump('rim_directional_fill', out);

    // 45 degrees: corner normals align with the light, straight edges do not
    // (|cos 45| = 0.707), so corners saturate and edges do not.
    final corner = await _pixel(out, 20, 20);
    final topEdge = await _pixel(out, _width ~/ 2, 6);
    expect(
      corner[0],
      greaterThan(200),
      reason: 'the corner facing the light must be the brightest point',
    );
    expect(
      topEdge[0],
      inInclusiveRange(140, 205),
      reason: 'a straight edge is lit at |cos 45| of full intensity',
    );

    out.dispose();
  });

  test('ambient rim only lights the side facing the light', () async {
    final shader = await _rimShader(ambient: true);
    final out = await _renderFill(shader, blendMode: ui.BlendMode.srcOver);
    await _dump('rim_ambient_fill', out);

    // Screen-space y grows downward, so 45 degrees points down-right.
    final topLeft = await _pixel(out, 20, 20);
    final bottomRight = await _pixel(out, _width - 21, _height - 21);
    expect(
      topLeft[0],
      lessThan(40),
      reason: 'the side away from the light stays dark',
    );
    expect(
      bottomRight[0],
      greaterThan(200),
      reason: 'the side facing the light is lit',
    );

    out.dispose();
  });

  test('the rim is drawn as a ring and leaves the surface untouched', () async {
    final shader = await _rimShader(ambient: false);
    final out = await _renderRim(shader, blendMode: ui.BlendMode.plus);
    await _dump('rim_stroke', out);

    final centre = await _pixel(out, _width ~/ 2, _height ~/ 2);
    expect(
      centre[0],
      lessThan(30),
      reason: 'the rim must not wash the whole surface',
    );
    final ring = await _maxRed(out, _width ~/ 2, 0, _width ~/ 2 + 6, 8);
    expect(
      ring,
      greaterThan(120),
      reason: 'the stroked ring must still be visible',
    );

    out.dispose();
  });
}
