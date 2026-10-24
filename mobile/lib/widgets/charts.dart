import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import 'ui.dart';

class ProgressBar extends StatelessWidget {
  const ProgressBar(this.pct, {super.key});
  final int pct;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: 8,
        color: TP.track,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: (pct.clamp(0, 100)) / 100,
          child: AnimatedContainer(duration: const Duration(milliseconds: 320), curve: TP.ease, decoration: BoxDecoration(color: TP.primary, borderRadius: BorderRadius.circular(99))),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.pct);
  final double pct;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 12 / 120;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width * 52 / 120);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = TP.track;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = TP.primary;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * (pct / 100).clamp(0, 1), false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.pct != pct;
}

class Ring extends StatelessWidget {
  const Ring({super.key, required this.pct, required this.caption, this.size = 150});
  final int? pct;
  final String caption;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: pct == null ? 'No $caption data yet' : '$pct percent $caption',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(size: Size(size, size), painter: _RingPainter((pct ?? 0).toDouble())),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(pct == null ? '\u2014' : '$pct%', style: tpText(size * 0.21, w: FontWeight.w700, ls: -0.8)),
            Text(caption, style: tpText(size * 0.085, w: FontWeight.w600, color: TP.muted)),
          ]),
        ]),
      ),
    );
  }
}

/// Vertical bars (0-100) with a label under each; null values render as an empty stub.
class BarChart extends StatelessWidget {
  const BarChart({super.key, required this.values, required this.labels, this.height = 120});
  final List<int?> values;
  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < values.length; i++)
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: height,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Semantics(
                  label: '${labels[i]} ${values[i] == null ? 'no data' : '${values[i]} percent'}',
                  child: FractionallySizedBox(
                    heightFactor: values[i] == null ? 0.03 : (values[i]! / 100).clamp(0.03, 1),
                    child: Container(
                      width: 22,
                      decoration: BoxDecoration(
                        color: values[i] == null ? TP.track : tierColor(values[i]),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(3)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: tpText(11, w: FontWeight.w600, color: TP.muted)),
          ]),
        ),
    ]);
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values);
  final List<int?> values;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      final x = values.length == 1 ? 0.0 : i / (values.length - 1) * size.width;
      final y = size.height - ((v - 55) / 45).clamp(0.0, 1.0) * size.height;
      pts.add(Offset(x, y));
    }
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = TP.primary,
    );
    canvas.drawCircle(pts.last, 4, Paint()..color = TP.primary);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values != values;
}

class Sparkline extends StatelessWidget {
  const Sparkline(this.values, {super.key, this.height = 90});
  final List<int?> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final real = values.whereType<int>().toList();
    if (real.length < 2) return SizedBox(height: height, child: Center(child: Text('Not enough data yet', style: rowSub)));
    return Semantics(
      label: 'Trend from ${real.first} to ${real.last} percent',
      child: SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _SparkPainter(values))),
    );
  }
}

class MeterRow extends StatelessWidget {
  const MeterRow({super.key, required this.label, required this.count, required this.total});
  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: tpText(12.5, w: FontWeight.w600, color: TP.ink2))),
        Text('$count missed', style: rowSub),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Container(
          height: 8,
          color: TP.track,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: count == 0 ? 0.04 : math.max(pct, 0.04),
            child: Container(color: count == 0 ? TP.success : TP.primary),
          ),
        ),
      ),
    ]);
  }
}

class StatTile extends StatelessWidget {
  const StatTile(this.value, this.caption, {super.key});
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(color: TP.surface, borderRadius: BorderRadius.circular(TP.radius), border: Border.all(color: TP.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: tpText(21, w: FontWeight.w700, ls: -0.4))),
        const SizedBox(height: 3),
        Text(caption, style: tpText(11.5, w: FontWeight.w600, color: TP.muted, h: 1.3)),
      ]),
    );
  }
}

class StatStrip extends StatelessWidget {
  const StatStrip(this.tiles, {super.key});
  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < tiles.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(child: tiles[i]),
      ],
    ]);
  }
}
