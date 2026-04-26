import 'dart:math' as math;
import 'dart:ui';

enum RecognizedShape { line, circle, square, rectangle, triangle, pill, diamond, pentagon }

// ── Public API ────────────────────────────────────────────────────────────────

/// Returns the recognized shape type, or null if the stroke is unrecognisable.
RecognizedShape? detectShape(List<Offset> points) {
  if (points.length < 8) return null;

  final totalLen = _pathLength(points);
  if (totalLen < 30) return null;

  final chord = (points.last - points.first).distance;

  // Straight line: endpoint is close to start as a fraction of total length.
  if (chord / totalLen > 0.85) return RecognizedShape.line;

  // Must be roughly closed for all other shapes.
  final isClosed = (points.last - points.first).distance < 0.25 * totalLen;
  if (!isClosed) return null;

  final bbox = _boundingBox(points);
  if (bbox.width < 10 || bbox.height < 10) return null;

  final aspectRatio =
      math.max(bbox.width, bbox.height) / math.min(bbox.width, bbox.height);

  // Circularity: coefficient of variation of distances from centroid.
  final center = _centroid(points);
  final radii = points.map((p) => (p - center).distance).toList();
  final meanR = radii.reduce((a, b) => a + b) / radii.length;
  final variance = radii
          .map((r) => (r - meanR) * (r - meanR))
          .reduce((a, b) => a + b) /
      radii.length;
  final cv = math.sqrt(variance) / meanR;

  // Strongly circular radii → circle or pill depending on elongation.
  if (cv < 0.13) {
    return aspectRatio < 1.5 ? RecognizedShape.circle : RecognizedShape.pill;
  }

  // Simplify the stroke to count distinct corners.
  final epsilon = math.max(bbox.width, bbox.height) * 0.07;
  final simplified = _simplify(points, epsilon);
  // For a closed stroke the last simplified point ≈ the first, so subtract 1.
  final nCorners = simplified.length - 1;

  if (nCorners <= 2) {
    if (cv < 0.22 && aspectRatio < 1.5) return RecognizedShape.circle;
    if (aspectRatio >= 1.5) return RecognizedShape.pill;
    return null;
  }

  if (nCorners == 3) return RecognizedShape.triangle;

  if (nCorners == 5) return RecognizedShape.pentagon;

  if (nCorners == 4) {
    if (aspectRatio >= 2.0) return RecognizedShape.pill;
    final corners = simplified.sublist(0, 4);
    if (_hasRightAngles(corners)) {
      return aspectRatio < 1.3 ? RecognizedShape.square : RecognizedShape.rectangle;
    }
    return RecognizedShape.diamond;
  }

  if (nCorners == 6) {
    if (cv < 0.20) return RecognizedShape.circle;
    return null;
  }

  // Many corners but not circular enough → unclear, skip.
  if (cv < 0.20) return RecognizedShape.circle;
  return null;
}

/// Generates a list of canvas points that represent the "perfect" version of
/// [shape] fitted to the bounding box / center of [original].
List<Offset> generateShapePoints(
    RecognizedShape shape, List<Offset> original) {
  final bbox = _boundingBox(original);
  final center = _centroid(original);
  final w = bbox.width;
  final h = bbox.height;

  switch (shape) {
    case RecognizedShape.line:
      return [original.first, original.last];

    case RecognizedShape.circle:
      final radii = original.map((p) => (p - center).distance).toList();
      final meanR = radii.reduce((a, b) => a + b) / radii.length;
      return List.generate(81, (i) {
        final angle = 2 * math.pi * i / 80;
        return center +
            Offset(math.cos(angle) * meanR, math.sin(angle) * meanR);
      });

    case RecognizedShape.square:
      final epsilon = math.max(w, h) * 0.07;
      final simplified = _simplify(original, epsilon);
      if (simplified.length >= 5) {
        return _perfectSquareFromCorners(simplified.sublist(0, 4));
      }
      // Fallback: axis-aligned square.
      final side = math.max(w, h);
      final half = side / 2;
      final cx = center.dx, cy = center.dy;
      return _densePolygon([
        Offset(cx - half, cy - half),
        Offset(cx + half, cy - half),
        Offset(cx + half, cy + half),
        Offset(cx - half, cy + half),
      ]);

    case RecognizedShape.rectangle:
      final epsilon = math.max(w, h) * 0.07;
      final simplified = _simplify(original, epsilon);
      if (simplified.length >= 5) {
        return _perfectRectFromCorners(simplified.sublist(0, 4));
      }
      // Fallback: axis-aligned rect.
      return _densePolygon([
        Offset(bbox.left, bbox.top),
        Offset(bbox.right, bbox.top),
        Offset(bbox.right, bbox.bottom),
        Offset(bbox.left, bbox.bottom),
      ]);

    case RecognizedShape.triangle:
      final epsilon = math.max(w, h) * 0.07;
      final simplified = _simplify(original, epsilon);
      if (simplified.length >= 4) {
        return _densePolygon([simplified[0], simplified[1], simplified[2]]);
      }
      // Fallback: isosceles from bounding box.
      final mx = bbox.left + w / 2;
      return _densePolygon([
        Offset(mx, bbox.top),
        Offset(bbox.right, bbox.bottom),
        Offset(bbox.left, bbox.bottom),
      ]);

    case RecognizedShape.pill:
      return _generatePill(bbox);

    case RecognizedShape.diamond:
      final epsilon = math.max(w, h) * 0.07;
      final simplified = _simplify(original, epsilon);
      if (simplified.length >= 5) {
        return _perfectDiamondFromCorners(simplified.sublist(0, 4));
      }
      // Fallback: axis-aligned diamond from bounding box.
      return _densePolygon([
        Offset(bbox.left + w / 2, bbox.top),
        Offset(bbox.right, bbox.top + h / 2),
        Offset(bbox.left + w / 2, bbox.bottom),
        Offset(bbox.left, bbox.top + h / 2),
      ]);

    case RecognizedShape.pentagon:
      final epsilon = math.max(w, h) * 0.07;
      final simplified = _simplify(original, epsilon);
      if (simplified.length >= 6) {
        return _densePolygon(simplified.sublist(0, 5));
      }
      // Fallback: regular pentagon from center + mean radius.
      final radii = original.map((p) => (p - center).distance).toList();
      final meanR = radii.reduce((a, b) => a + b) / radii.length;
      return _densePolygon(List.generate(5, (i) {
        final angle = -math.pi / 2 + 2 * math.pi * i / 5;
        return center + Offset(math.cos(angle) * meanR, math.sin(angle) * meanR);
      }));
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

double _pathLength(List<Offset> pts) {
  double len = 0;
  for (int i = 1; i < pts.length; i++) {
    len += (pts[i] - pts[i - 1]).distance;
  }
  return len;
}

Offset _centroid(List<Offset> pts) {
  double sx = 0, sy = 0;
  for (final p in pts) {
    sx += p.dx;
    sy += p.dy;
  }
  return Offset(sx / pts.length, sy / pts.length);
}

Rect _boundingBox(List<Offset> pts) {
  double minX = double.infinity,
      maxX = -double.infinity,
      minY = double.infinity,
      maxY = -double.infinity;
  for (final p in pts) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// Returns true if every interior angle of the polygon is close to 90°.
bool _hasRightAngles(List<Offset> corners) {
  final n = corners.length;
  for (int i = 0; i < n; i++) {
    final prev = corners[(i - 1 + n) % n];
    final curr = corners[i];
    final next = corners[(i + 1) % n];
    final v1 = curr - prev;
    final v2 = next - curr;
    final len1 = v1.distance;
    final len2 = v2.distance;
    if (len1 < 1 || len2 < 1) return false;
    final cosAngle = (v1.dx * v2.dx + v1.dy * v2.dy) / (len1 * len2);
    if (cosAngle.abs() > 0.35) return false;
  }
  return true;
}

/// Generates a perfect square that preserves the rotation of the drawn corners.
/// Each corner is projected from the mean center at equal radii, 90° apart.
List<Offset> _perfectSquareFromCorners(List<Offset> corners) {
  double cx = 0, cy = 0;
  for (final p in corners) { cx += p.dx; cy += p.dy; }
  cx /= corners.length;
  cy /= corners.length;

  final meanR = corners
      .map((p) => (p - Offset(cx, cy)).distance)
      .reduce((a, b) => a + b) /
      corners.length;

  final angle0 = math.atan2(corners[0].dy - cy, corners[0].dx - cx);

  return _densePolygon(List.generate(4, (i) {
    final a = angle0 + i * math.pi / 2;
    return Offset(cx + math.cos(a) * meanR, cy + math.sin(a) * meanR);
  }));
}

/// Generates a perfect rectangle (right angles, opposite sides equal) that
/// preserves the orientation of the drawn corners.
List<Offset> _perfectRectFromCorners(List<Offset> corners) {
  double cx = 0, cy = 0;
  for (final p in corners) { cx += p.dx; cy += p.dy; }
  cx /= corners.length;
  cy /= corners.length;

  // Primary axis: average direction of the first and opposite edges.
  final e01 = corners[1] - corners[0];
  final e32 = corners[2] - corners[3];
  final axisAngle = math.atan2(
      (e01.dy + e32.dy) / 2, (e01.dx + e32.dx) / 2);
  final cosA = math.cos(axisAngle), sinA = math.sin(axisAngle);

  // Project corners onto local (u, v) axes.
  double maxU = -double.infinity, minU = double.infinity;
  double maxV = -double.infinity, minV = double.infinity;
  for (final p in corners) {
    final dx = p.dx - cx, dy = p.dy - cy;
    final u = dx * cosA + dy * sinA;
    final v = -dx * sinA + dy * cosA;
    if (u > maxU) maxU = u;
    if (u < minU) minU = u;
    if (v > maxV) maxV = v;
    if (v < minV) minV = v;
  }

  final hw = math.max(maxU.abs(), minU.abs());
  final hh = math.max(maxV.abs(), minV.abs());

  // Rotate the 4 corners back to world space.
  return _densePolygon([
    Offset(cx - hw * cosA + hh * sinA, cy - hw * sinA - hh * cosA),
    Offset(cx + hw * cosA + hh * sinA, cy + hw * sinA - hh * cosA),
    Offset(cx + hw * cosA - hh * sinA, cy + hw * sinA + hh * cosA),
    Offset(cx - hw * cosA - hh * sinA, cy - hw * sinA + hh * cosA),
  ]);
}

/// Generates a diamond/rhombus with equal side lengths from the drawn corners.
List<Offset> _perfectDiamondFromCorners(List<Offset> corners) {
  double cx = 0, cy = 0;
  for (final p in corners) { cx += p.dx; cy += p.dy; }
  cx /= corners.length;
  cy /= corners.length;

  // Use the mean distance along each axis pair (pairs of opposite corners).
  final axis1 = (corners[0] - corners[2]).distance / 2;
  final axis2 = (corners[1] - corners[3]).distance / 2;

  // Preserve the orientation of the first axis.
  final angle0 = math.atan2(corners[0].dy - cy, corners[0].dx - cx);
  final angle1 = angle0 + math.pi / 2;

  return _densePolygon([
    Offset(cx + math.cos(angle0) * axis1, cy + math.sin(angle0) * axis1),
    Offset(cx + math.cos(angle1) * axis2, cy + math.sin(angle1) * axis2),
    Offset(cx - math.cos(angle0) * axis1, cy - math.sin(angle0) * axis1),
    Offset(cx - math.cos(angle1) * axis2, cy - math.sin(angle1) * axis2),
  ]);
}

/// Douglas-Peucker polyline simplification.
List<Offset> _simplify(List<Offset> pts, double epsilon) {
  if (pts.length <= 2) return List.of(pts);

  double maxDist = 0;
  int maxIdx = 0;
  final start = pts.first;
  final end = pts.last;
  final seg = end - start;
  final segLen = seg.distance;

  for (int i = 1; i < pts.length - 1; i++) {
    double dist;
    if (segLen < 1e-6) {
      dist = (pts[i] - start).distance;
    } else {
      final t = ((pts[i] - start).dx * seg.dx + (pts[i] - start).dy * seg.dy) /
          (segLen * segLen);
      final proj = start + Offset(seg.dx * t, seg.dy * t);
      dist = (pts[i] - proj).distance;
    }
    if (dist > maxDist) {
      maxDist = dist;
      maxIdx = i;
    }
  }

  if (maxDist > epsilon) {
    final left = _simplify(pts.sublist(0, maxIdx + 1), epsilon);
    final right = _simplify(pts.sublist(maxIdx), epsilon);
    return [...left.sublist(0, left.length - 1), ...right];
  }
  return [start, end];
}

/// Generates points along a stadium (pill / capsule) shape.
/// Straight sections are explicitly interpolated so the bezier renderer
/// doesn't curve them into arches.
List<Offset> _generatePill(Rect bbox) {
  final w = bbox.width;
  final h = bbox.height;
  final r = math.min(w, h) / 2;
  final pts = <Offset>[];
  const segs = 24;
  const straightSegs = 12;

  if (w >= h) {
    // Horizontal pill: right cap → bottom straight → left cap → top straight.
    final cx = bbox.left + w / 2;
    final cy = bbox.top + h / 2;
    final straight = w - h;
    for (int i = 0; i <= segs; i++) {
      final a = -math.pi / 2 + math.pi * i / segs;
      pts.add(Offset(cx + straight / 2 + r * math.cos(a), cy + r * math.sin(a)));
    }
    final bottomRight = pts.last;
    final bottomLeft = Offset(cx - straight / 2, cy + r);
    for (int i = 1; i <= straightSegs; i++) {
      pts.add(Offset.lerp(bottomRight, bottomLeft, i / straightSegs)!);
    }
    for (int i = 1; i <= segs; i++) {
      final a = math.pi / 2 + math.pi * i / segs;
      pts.add(Offset(cx - straight / 2 + r * math.cos(a), cy + r * math.sin(a)));
    }
    final topLeft = pts.last;
    final topRight = Offset(cx + straight / 2, cy - r);
    for (int i = 1; i <= straightSegs; i++) {
      pts.add(Offset.lerp(topLeft, topRight, i / straightSegs)!);
    }
  } else {
    // Vertical pill: bottom cap → left straight → top cap → right straight.
    final cx = bbox.left + w / 2;
    final cy = bbox.top + h / 2;
    final straight = h - w;
    for (int i = 0; i <= segs; i++) {
      final a = math.pi * i / segs;
      pts.add(Offset(cx + r * math.cos(a), cy + straight / 2 + r * math.sin(a)));
    }
    final bottomLeft = pts.last;
    final topLeft = Offset(cx - r, cy - straight / 2);
    for (int i = 1; i <= straightSegs; i++) {
      pts.add(Offset.lerp(bottomLeft, topLeft, i / straightSegs)!);
    }
    for (int i = 1; i <= segs; i++) {
      final a = math.pi + math.pi * i / segs;
      pts.add(Offset(cx + r * math.cos(a), cy - straight / 2 + r * math.sin(a)));
    }
    final topRight = pts.last;
    final bottomRight = Offset(cx + r, cy + straight / 2);
    for (int i = 1; i <= straightSegs; i++) {
      pts.add(Offset.lerp(topRight, bottomRight, i / straightSegs)!);
    }
  }

  pts.add(pts.first);
  return pts;
}

/// Generates densely interpolated points along a closed polygon so the
/// quadratic-bezier stroke renderer follows straight edges accurately.
List<Offset> _densePolygon(List<Offset> corners, {int stepsPerEdge = 20}) {
  final pts = <Offset>[];
  for (int i = 0; i < corners.length; i++) {
    final a = corners[i];
    final b = corners[(i + 1) % corners.length];
    for (int j = 0; j < stepsPerEdge; j++) {
      pts.add(Offset.lerp(a, b, j / stepsPerEdge)!);
    }
  }
  pts.add(corners[0]);
  return pts;
}
