import 'dart:math' as Math;
import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/src/map/map.dart';
import 'package:latlong/latlong.dart' hide Path; // conflict with Path from UI

class PolygonLayerOptions extends LayerOptions {
  final List<Polygon> polygons;
  final RamerDouglasPeuckerOptions ramerDouglasPeuckerOptions;
  final SutherlandHodgmanOptions sutherlandHodgmanOptions;
  final bool polygonCulling; /// screen space culling of polygons

  PolygonLayerOptions({this.polygons = const [], rebuild, this.ramerDouglasPeuckerOptions, this.sutherlandHodgmanOptions, this.polygonCulling = false}) : super(rebuild: rebuild);
}

class Polygon {
  final List<LatLng> points;
  final List<Offset> offsets = [];
  final Color color;
  final double borderStrokeWidth;
  final Color borderColor;
  final bool isDotted;
  BoundingBox boundingBox;

  Polygon({
    this.points,
    this.color = const Color(0xFF00FF00),
    this.borderStrokeWidth = 0.0,
    this.borderColor = const Color(0xFFFFFF00),
    this.isDotted = false,
  }) {
    this.boundingBox = calcBoundingBox();
  }

  BoundingBox calcBoundingBox() {
    if (points != null && points.isNotEmpty) {
      num minX;
      num maxX;
      num minY;
      num maxY;

      for (LatLng point in points) {
        // convert lat lon to custom point stored as radians
        num x = point.longitude * Math.pi / 180.0;
        num y = point.latitude * Math.pi / 180.0;
        CustomPoint cPoint = CustomPoint(x, y);

        if (minX == null || minX > cPoint.x) {
          minX = cPoint.x;
        }

        if (minY == null || minY > cPoint.y) {
          minY = cPoint.y;
        }

        if (maxX == null || maxX < cPoint.x) {
          maxX = cPoint.x;
        }

        if (maxY == null || maxY < cPoint.y) {
          maxY = cPoint.y;
        }
      }

      return BoundingBox(min: Math.Point(minX, minY), max: Math.Point(maxX, maxY));
    }

    return BoundingBox(min: Math.Point(0, 0), max: Math.Point(0, 0));
  }
}

class BoundingBox {
  Math.Point min;
  Math.Point max;

  BoundingBox({this.min, this.max});

  // bounding box will be stored as latLng in radians instead of degrees
  BoundingBox getAsDegrees() {
    BoundingBox latLngBB = BoundingBox(
      min: Math.Point(this.min.x * 180 / Math.pi, this.min.y * 180 / Math.pi),
      max: Math.Point(this.max.x * 180 / Math.pi, this.max.y * 180 / Math.pi),
    );

    return latLngBB;
  }

  BoundingBox getAsRadians() {
    BoundingBox radiansBB = BoundingBox(
      min: Math.Point(this.min.x * Math.pi / 180.0, this.min.y * Math.pi / 180.0),
      max: Math.Point(this.max.x * Math.pi / 180.0, this.max.y * Math.pi / 180.0),
    );

    return radiansBB;
  }

  bool isOverlapping(BoundingBox bounds) {
    // check if bounding box rectangle is outside the other, if it is then it's considered not overlapping
    if (this.min.y > bounds.max.y || this.max.y < bounds.min.y || this.max.x < bounds.min.x || this.min.x > bounds.max.x) {
      return false;
    }

    return true;
  }

  @override
  String toString() {
    return '$min | $max';
  }
}

/// used for line smoothing
class RamerDouglasPeuckerOptions {
  bool apply;
  double epsilon;

  RamerDouglasPeuckerOptions({this.apply = false, this.epsilon});
}

/// used for polygon clipping to screen
class SutherlandHodgmanOptions {
  bool apply;

  SutherlandHodgmanOptions({this.apply = false});
}

class PolygonLayer extends StatelessWidget {
  final PolygonLayerOptions polygonOpts;
  final MapState map;
  final Stream<Null> stream;

  PolygonLayer(this.polygonOpts, this.map, this.stream);

  @override
  Widget build(BuildContext context) {
    return new LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bc) {
        final size = new Size(bc.maxWidth, bc.maxHeight);
        return _build(context, size);
      },
    );
  }

  Widget _build(BuildContext context, Size size) {
    return new StreamBuilder<int>(
      stream: stream, // a Stream<int> or null
      builder: (BuildContext context, _) {
        var polygons = <Widget>[];
        LatLngBounds screenBounds = map.bounds;
        //Polygon screenPoly = Polygon(points: [screenBounds.southWest, screenBounds.southEast, screenBounds.northWest, screenBounds.northEast]);
        BoundingBox screenBBRadians = BoundingBox(min: Math.Point(screenBounds.west, screenBounds.south), max: Math.Point(screenBounds.east, screenBounds.north)).getAsRadians();
        for (var polygonOpt in polygonOpts.polygons) {
          polygonOpt.offsets.clear();
          var i = 0;

//          LatLng minBound = LatLng(polygonOpt.boundingBox.minY, polygonOpt.boundingBox.minX);
//          LatLng maxBound = LatLng(polygonOpt.boundingBox.maxY, polygonOpt.boundingBox.maxX);

//          var minPos = map.project(minBound);
//          minPos = minPos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
//
//          var maxPos = map.project(maxBound);
//          maxPos = maxPos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

          // only draw polygons that overlap with the screens bounding box
          if (polygonOpts.polygonCulling && !polygonOpt.boundingBox.isOverlapping(screenBBRadians)) {
            // skip this polygon as it's offscreen
            continue;
          }

          // TODO: polygon clipping, this will speed up the drawing of large complex polygones when up close.
          // clip the polygon, we don't want to draw parts that are way off screen
          Polygon drawPoly = new Polygon();
          if (polygonOpts.sutherlandHodgmanOptions != null && polygonOpts.sutherlandHodgmanOptions.apply) {
            List<LatLng> clippedPoly = clipPolygon(List.from(polygonOpt.points), [screenBounds.northWest, screenBounds.southWest, screenBounds.southEast, screenBounds.northEast]);
            drawPoly = Polygon(points: clippedPoly, color: polygonOpt.color, borderColor: polygonOpt.borderColor, borderStrokeWidth: polygonOpt.borderStrokeWidth);
          } else {
            drawPoly = Polygon(points: List.from(polygonOpt.points), color: polygonOpt.color, borderColor: polygonOpt.borderColor, borderStrokeWidth: polygonOpt.borderStrokeWidth);
          }

          //Polygon drawPoly = Polygon(points: List.from(polygonOpt.points), color: polygonOpt.color, borderColor: polygonOpt.borderColor, borderStrokeWidth: polygonOpt.borderStrokeWidth);

          drawPoly.offsets.clear();
          //simplify the polygon
          if (polygonOpts.ramerDouglasPeuckerOptions != null && polygonOpts.ramerDouglasPeuckerOptions.apply) {
            List<LatLng> pointListOut = List();
            ramerDouglasPeucker(drawPoly.points, polygonOpts.ramerDouglasPeuckerOptions.epsilon, pointListOut);
            drawPoly.points.clear();
            drawPoly.points.addAll(pointListOut);
          }

          // convert polygon points to screen space
          for (var point in drawPoly.points) {
            var pos = map.project(point);
            pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
            drawPoly.offsets.add(new Offset(pos.x.toDouble(), pos.y.toDouble()));
            if (i > 0 && i < drawPoly.points.length) {
              drawPoly.offsets.add(new Offset(pos.x.toDouble(), pos.y.toDouble()));
            }
            i++;
          }

          // add polygons to be rendered
          polygons.add(
            new CustomPaint(
              painter: new PolygonPainter(drawPoly),
              size: size,
            ),
          );
        }

        //print('Drawing ${polygons.length} Polygons');

        return new Container(
          child: new Stack(
            children: polygons,
          ),
        );
      },
    );
  }
}

/// Sutherland-Hodgman polygon clipping
/// https://rosettacode.org/wiki/Sutherland-Hodgman_polygon_clipping#Java
/// // TODO: convert points to radians!!!
List<LatLng> clipPolygon(List<LatLng> subjectPolygon, List<LatLng> clipPolygon) {
  List<LatLng> outputList = List.from(subjectPolygon); // TODO: may need list.from

  bool removedLast = false;
  // remove linking point
  if (outputList != null && outputList.isNotEmpty) {
    if (outputList.first == outputList.last) {
      removedLast = true;
      outputList.removeAt(outputList.length - 1);
    }
  }

  int len = clipPolygon.length;
  for (int i = 0; i < len; i++) {
    int len2 = outputList.length;
    List<LatLng> inputList = List.from(outputList);
    outputList = new List(); // TODO: may be faster with .clear or making it a fixed list

    LatLng A = clipPolygon[((i + len - 1) % len)];
    A = LatLng(A.latitude, A.longitude);
    LatLng B = clipPolygon[(i)];
    B = LatLng(B.latitude, B.longitude);

    for (int j = 0; j < len2; j++) {
      LatLng P = inputList[((j + len2 - 1) % len2)];
      LatLng Q = inputList[(j)];

      if (isInside(A, B, Q)) {
        if (!isInside(A, B, P)) outputList.add(intersection(A, B, P, Q));
        outputList.add(Q);
      } else if (isInside(A, B, P)) outputList.add(intersection(A, B, P, Q));
    }

    //print(outputList);
  }

  // re add linking point
  if (outputList != null && outputList.isNotEmpty) {
    if (removedLast) {
      outputList.add(outputList[0]);
    }
  }

  return outputList;
}

bool isInside(LatLng a, LatLng b, LatLng c) {
  return (a.longitude - c.longitude) * (b.latitude - c.latitude) > (a.latitude - c.latitude) * (b.longitude - c.longitude);
}

LatLng intersection(LatLng a, LatLng b, LatLng p, LatLng q) {
  double A1 = b.latitude - a.latitude;
  double B1 = a.longitude - b.longitude;
  double C1 = A1 * a.longitude + B1 * a.latitude;

  double A2 = q.latitude - p.latitude;
  double B2 = p.longitude - q.longitude;
  double C2 = A2 * p.longitude + B2 * p.latitude;

  double det = A1 * B2 - A2 * B1;
  double x = (B2 * C1 - B1 * C2) / det;
  double y = (A1 * C2 - A2 * C1) / det;

  return new LatLng(y, x); // TODO: was x, y
}

double perpendicularDistance(LatLng pt, LatLng lineStart, LatLng lineEnd) {
  double dx = lineEnd.longitude - lineStart.longitude;
  double dy = lineEnd.latitude - lineStart.latitude;

  // Normalize
  //double mag = (sqrt(dx) + sqrt(dy)); // TODO: no hypot function in dart
  double mag = hypot([dx, dy]);
  if (mag > 0.0) {
    dx /= mag;
    dy /= mag;
  }
  double pvx = pt.longitude - lineStart.longitude;
  double pvy = pt.latitude - lineStart.latitude;

  // Get dot product (project pv onto normalized direction)
  double pvdot = dx * pvx + dy * pvy;

  // Scale line direction vector and subtract it from pv
  double ax = pvx - pvdot * dx;
  double ay = pvy - pvdot * dy;

  //return (sqrt(ax) + sqrt(ay)); // TODO: no hypot function in dart
  return hypot([ax, ay]);
}

hypot(List<double> arguments) {
  var y = 0.0;
  arguments.reversed.forEach((v) {
    y += v * v;
  });
  return Math.sqrt(y);
}

List<LatLng> ramerDouglasPeucker(List<LatLng> pointList, double epsilon, List<LatLng> out) {
  if (pointList.length < 2) {
    return pointList; // not enough points to simplify return og list
  }

  // Find the point with the maximum distance from line between the start and end
  double dmax = 0.0;
  int index = 0;
  int end = pointList.length - 1;
  for (int i = 1; i < end; ++i) {
    double d = perpendicularDistance(pointList[i], pointList[0], pointList[end]);
    if (d > dmax) {
      index = i;
      dmax = d;
    }
  }

  // If max distance is greater than epsilon, recursively simplify
  if (dmax > epsilon) {
    List<LatLng> recResults1 = List();
    List<LatLng> recResults2 = List();

    List<LatLng> firstLine = List.from(pointList.getRange(0, index + 1));
    List<LatLng> lastLine = List.from(pointList.getRange(index, pointList.length));
    ramerDouglasPeucker(firstLine, epsilon, recResults1);
    ramerDouglasPeucker(lastLine, epsilon, recResults2);

    // build the result list
    out.addAll(recResults1.getRange(0, recResults1.length - 1));
    out.addAll(recResults2);
    if (out.length < 2) throw ("Problem assembling output");
  } else {
    // Just return start and end points
    out.clear();
    out.add(pointList[0]);
    out.add(pointList[(pointList.length - 1)]);
  }
}

class PolygonPainter extends CustomPainter {
  final Polygon polygonOpt;

  PolygonPainter(this.polygonOpt);

  @override
  void paint(Canvas canvas, Size size) {
    if (polygonOpt.offsets.isEmpty) {
      return;
    }
    final rect = Offset.zero & size;
    canvas.clipRect(rect);
    final paint = new Paint()
      ..style = PaintingStyle.fill
      ..color = polygonOpt.color;
    final borderPaint = polygonOpt.borderStrokeWidth > 0.0
        ? (new Paint()
          ..color = polygonOpt.borderColor
          ..strokeWidth = polygonOpt.borderStrokeWidth)
        : null;

    List<List<Offset>> rings = new List();
    Offset ringStart = polygonOpt.offsets[0];
    int slidingWindow = 0;
    for (int i = 1; i < polygonOpt.offsets.length - 1; i++) {
      Offset cur = polygonOpt.offsets[i];
      if (ringStart == cur) {
        //found the ring start, this is the end of the first polygon
        rings.add(polygonOpt.offsets.sublist(slidingWindow, i + 1));
        slidingWindow = i + 3;
        if (slidingWindow < polygonOpt.offsets.length - 1) {
          i = slidingWindow;
          ringStart = polygonOpt.offsets[slidingWindow];
        }
      }
    }

    _paintPolygon(canvas, rings, paint);

    double borderRadius = (polygonOpt.borderStrokeWidth / 2);
    if (polygonOpt.borderStrokeWidth > 0.0) {
      if (polygonOpt.isDotted) {
        var spacing = polygonOpt.borderStrokeWidth * 1.5;
        for (List<Offset> ring in rings) {
          _paintDottedLine(canvas, ring, borderRadius, spacing, borderPaint);
        }
      } else {
        for (List<Offset> ring in rings) {
          _paintLine(canvas, ring, borderRadius, borderPaint);
        }
      }
    }

    canvas.clipRect(rect);
  }

  void _paintDottedLine(Canvas canvas, List<Offset> offsets, double radius, double stepLength, Paint paint) {
    var startDistance = 0.0;
    for (var i = 0; i < offsets.length - 1; i++) {
      var o0 = offsets[i];
      var o1 = offsets[i + 1];
      var totalDistance = _dist(o0, o1);
      var distance = startDistance;
      while (distance < totalDistance) {
        var f1 = distance / totalDistance;
        var f0 = 1.0 - f1;
        var offset = Offset(o0.dx * f0 + o1.dx * f1, o0.dy * f0 + o1.dy * f1);
        canvas.drawCircle(offset, radius, paint);
        distance += stepLength;
      }
      startDistance = distance < totalDistance ? stepLength - (totalDistance - distance) : distance - totalDistance;
    }
    canvas.drawCircle(polygonOpt.offsets.last, radius, paint);
  }

  void _paintLine(Canvas canvas, List<Offset> offsets, double radius, Paint paint) {
    canvas.drawPoints(PointMode.lines, offsets, paint);
    for (var offset in offsets) {
      canvas.drawCircle(offset, radius, paint);
    }
  }

  void _paintPolygon(Canvas canvas, List<List<Offset>> polygons, Paint paint) {
    Path path = new Path();
    for (List<Offset> ring in polygons) {
      path.addPolygon(ring, true);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(PolygonPainter other) => false;

  double _dist(Offset v, Offset w) {
    return sqrt(_dist2(v, w));
  }

  double _dist2(Offset v, Offset w) {
    return _sqr(v.dx - w.dx) + _sqr(v.dy - w.dy);
  }

  double _sqr(double x) {
    return x * x;
  }
}
