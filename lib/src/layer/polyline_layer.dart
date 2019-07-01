import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/src/map/map.dart';
import 'package:latlong/latlong.dart';

class PolylineLayerOptions extends LayerOptions {
  final List<Polyline> polylines;

  PolylineLayerOptions({this.polylines = const [], rebuild}) : super(rebuild: rebuild);
}

class Polyline {
  final List<LatLng> points;
  final List<Offset> offsets = [];
  final double strokeWidth;
  final Color color;
  final double borderStrokeWidth;
  final Color borderColor;
  final bool isDotted;
  final bool lineSmoothing;
  final double lineSmoothingEpsilon;

  Polyline({
    this.points,
    this.strokeWidth = 1.0,
    this.color = const Color(0xFF00FF00),
    this.borderStrokeWidth = 0.0,
    this.borderColor = const Color(0xFFFFFF00),
    this.isDotted = false,
    this.lineSmoothing = false,
    this.lineSmoothingEpsilon = 0.0005,
  });
}

class PolylineLayer extends StatelessWidget {
  final PolylineLayerOptions polylineOpts;
  final MapState map;
  final Stream<Null> stream;

  PolylineLayer(this.polylineOpts, this.map, this.stream);

  @override
  Widget build(BuildContext context) {
    return new LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bc) {
        final size = new Size(bc.maxWidth, bc.maxHeight);
        return _build(context, size);
      },
    );
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
    return sqrt(y);
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

  Widget _build(BuildContext context, Size size) {
    return new StreamBuilder<int>(
      stream: stream, // a Stream<int> or null
      builder: (BuildContext context, _) {
        var polylines = <Widget>[];
        for (var polylineOpt in polylineOpts.polylines) {
          polylineOpt.offsets.clear();
          var i = 0;

          if(polylineOpt.lineSmoothing) {
            // Ramer-Douglas-Peucker line simplification
            List<LatLng> pointListOut = List();
            ramerDouglasPeucker(polylineOpt.points, polylineOpt.lineSmoothingEpsilon, pointListOut);
            polylineOpt.points.clear();
            polylineOpt.points.addAll(pointListOut);
          }

          // convert points to screen space
          for (var point in polylineOpt.points) {
            var pos = map.project(point);
            pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
            polylineOpt.offsets.add(new Offset(pos.x.toDouble(), pos.y.toDouble()));
            if (i > 0 && i < polylineOpt.points.length) {
              polylineOpt.offsets.add(new Offset(pos.x.toDouble(), pos.y.toDouble()));
            }
            i++;
          }

          polylines.add(
            new CustomPaint(
              painter: new PolylinePainter(polylineOpt),
              size: size,
            ),
          );
        }

        return new Container(
          child: new Stack(
            children: polylines,
          ),
        );
      },
    );
  }
}

class PolylinePainter extends CustomPainter {
  final Polyline polylineOpt;

  PolylinePainter(this.polylineOpt);

  @override
  void paint(Canvas canvas, Size size) {
    if (polylineOpt.offsets.isEmpty) {
      return;
    }
    final rect = Offset.zero & size;
    canvas.clipRect(rect);
    final paint = new Paint()
      ..color = polylineOpt.color
      ..strokeWidth = polylineOpt.strokeWidth;
    final borderPaint = polylineOpt.borderStrokeWidth > 0.0
        ? (new Paint()
          ..color = polylineOpt.borderColor
          ..strokeWidth = polylineOpt.strokeWidth + polylineOpt.borderStrokeWidth)
        : null;
    double radius = polylineOpt.strokeWidth / 2;
    double borderRadius = radius + (polylineOpt.borderStrokeWidth / 2);
    if (polylineOpt.isDotted) {
      double spacing = polylineOpt.strokeWidth * 1.5;
      if (borderPaint != null) {
        _paintDottedLine(canvas, polylineOpt.offsets, borderRadius, spacing, borderPaint);
      }
      _paintDottedLine(canvas, polylineOpt.offsets, radius, spacing, paint);
    } else {
      if (borderPaint != null) {
        _paintLine(canvas, polylineOpt.offsets, borderRadius, borderPaint);
      }
      _paintLine(canvas, polylineOpt.offsets, radius, paint);
    }
  }

  void _paintDottedLine(Canvas canvas, List<Offset> offsets, double radius, double stepLength, Paint paint) {
    double startDistance = 0.0;
    for (int i = 0; i < offsets.length - 1; i++) {
      Offset o0 = offsets[i];
      Offset o1 = offsets[i + 1];
      double totalDistance = _dist(o0, o1);
      double distance = startDistance;
      while (distance < totalDistance) {
        double f1 = distance / totalDistance;
        double f0 = 1.0 - f1;
        var offset = Offset(o0.dx * f0 + o1.dx * f1, o0.dy * f0 + o1.dy * f1);
        canvas.drawCircle(offset, radius, paint);
        distance += stepLength;
      }
      startDistance = distance < totalDistance ? stepLength - (totalDistance - distance) : distance - totalDistance;
    }
    canvas.drawCircle(polylineOpt.offsets.last, radius, paint);
  }

  void _paintLine(Canvas canvas, List<Offset> offsets, double radius, Paint paint) {
    canvas.drawPoints(PointMode.lines, offsets, paint);
    for (var offset in offsets) {
      canvas.drawCircle(offset, radius, paint);
    }
  }

  @override
  bool shouldRepaint(PolylinePainter other) => false;
}

double _dist(Offset v, Offset w) {
  return sqrt(_dist2(v, w));
}

double _dist2(Offset v, Offset w) {
  return _sqr(v.dx - w.dx) + _sqr(v.dy - w.dy);
}

double _sqr(double x) {
  return x * x;
}
