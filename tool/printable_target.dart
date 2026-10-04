// Generates printable test targets as PDFs, with ring sizes taken from
// TargetModel.ikthof() so the print always matches the scoring.
//
//   dart run tool/printable_target.dart
//
// Writes docs/thrower/reference/printable/target-<paper>.pdf.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:thrower_app/scoring/target_model.dart';

/// Full-size IKTHOF target diameter.
const fullDiameterMm = 500.0;

class Paper {
  const Paper(this.name, this.widthMm, this.heightMm, this.diameterMm);

  final String name;
  final double widthMm;
  final double heightMm;
  final double diameterMm;
}

const papers = [
  Paper('A4', 210, 297, 180),
  Paper('A3', 297, 420, 270),
  Paper('A1-full-size', 594, 841, fullDiameterMm),
];

const red = '0.776 0.157 0.157'; // #C62828, as TargetPainter.
const wood = '0.890 0.788 0.627'; // #E3C9A0, as TargetPainter.

double pt(double mm) => mm * 72 / 25.4;

/// PDF path for a circle, using four Bézier curves.
String circle(double cx, double cy, double r) {
  const k = 0.5523;
  final c = k * r;
  String p(double x, double y) => '${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)}';
  return [
    '${p(cx + r, cy)} m',
    '${p(cx + r, cy + c)} ${p(cx + c, cy + r)} ${p(cx, cy + r)} c',
    '${p(cx - c, cy + r)} ${p(cx - r, cy + c)} ${p(cx - r, cy)} c',
    '${p(cx - r, cy - c)} ${p(cx - c, cy - r)} ${p(cx, cy - r)} c',
    '${p(cx + c, cy - r)} ${p(cx + r, cy - c)} ${p(cx + r, cy)} c',
    'f',
  ].join('\n');
}

String text(double x, double y, double size, String s) =>
    'BT /F1 $size Tf ${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} Td (${s.replaceAll('(', r'\(').replaceAll(')', r'\)')}) Tj ET';

String pageContent(Paper paper, TargetModel model) {
  final w = pt(paper.widthMm);
  final h = pt(paper.heightMm);
  final cx = w / 2;
  final cy = h / 2 + pt(8);
  final outerRadius = pt(paper.diameterMm / 2);
  final ops = <String>[];

  // Outermost ring first so smaller rings paint over it; the bull is red.
  for (var i = model.rings.length - 1; i >= 0; i--) {
    ops.add('${i.isEven ? red : wood} rg');
    ops.add(circle(cx, cy, model.rings[i].outerRadius * outerRadius));
  }

  // 100 mm scale bar to check the printer didn't scale the page.
  final margin = pt(12);
  final barY = pt(14);
  ops.add('0 0 0 RG 1 w ${margin.toStringAsFixed(2)} ${barY.toStringAsFixed(2)} m '
      '${(margin + pt(100)).toStringAsFixed(2)} ${barY.toStringAsFixed(2)} l S');
  for (final tick in [0.0, 50.0, 100.0]) {
    final x = (margin + pt(tick)).toStringAsFixed(2);
    ops.add('$x ${(barY - 4).toStringAsFixed(2)} m $x ${(barY + 4).toStringAsFixed(2)} l S');
  }
  ops.add('0 0 0 rg');
  ops.add(text(margin + pt(103), barY - 3, 8, '100 mm: measure this to check print scale'));

  final scale = paper.diameterMm == fullDiameterMm ? 'full size' : '${(paper.diameterMm / fullDiameterMm * 100).round()}% of the 50 cm IKTHOF target';
  final rings = [for (final r in model.rings) '${r.score}'].join(' / ');
  ops.add(text(margin, h - pt(14), 10,
      'Thrower App test target, ${paper.name}: ${paper.diameterMm.round()} mm across ($scale). Print at 100% / actual size.'));
  ops.add(text(margin, h - pt(20), 8, 'Rings score $rings from the centre outwards.'));
  return ops.join('\n');
}

/// Minimal single-page PDF with Helvetica.
List<int> pdf(Paper paper, String content) {
  final w = pt(paper.widthMm).toStringAsFixed(2);
  final h = pt(paper.heightMm).toStringAsFixed(2);
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $w $h] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
    '<< /Length ${latin1.encode(content).length} >>\nstream\n$content\nendstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  final out = BytesBuilder()..add(latin1.encode('%PDF-1.4\n'));
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    out.add(latin1.encode('${i + 1} 0 obj\n${objects[i]}\nendobj\n'));
  }
  final xref = out.length;
  out.add(latin1.encode([
    'xref',
    '0 ${objects.length + 1}',
    '0000000000 65535 f ',
    for (final o in offsets) '${o.toString().padLeft(10, '0')} 00000 n ',
    'trailer << /Size ${objects.length + 1} /Root 1 0 R >>',
    'startxref',
    '$xref',
    '%%EOF',
    '',
  ].join('\n')));
  return out.toBytes();
}

void main() {
  final model = TargetModel.ikthof();
  final dir = Directory('docs/thrower/reference/printable')..createSync(recursive: true);
  for (final paper in papers) {
    final file = File('${dir.path}/target-${paper.name}.pdf');
    file.writeAsBytesSync(pdf(paper, pageContent(paper, model)));
    stdout.writeln('Wrote ${file.path}');
  }
}
