import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/src/map/map.dart';
import 'package:latlong/latlong.dart' hide Path; // conflict with Path from UI

class PolygonLayerOptions extends LayerOptions {
  final List<Polygon> polygons;
  final bool polygonCulling;
  final bool innerRingSupport;

  /// screen space culling of polygons based on bounding box
  PolygonLayerOptions({
    Key key,
    this.polygons = const [],
    this.polygonCulling = false,
    this.innerRingSupport = false,
    rebuild,
  }) : super(key: key, rebuild: rebuild);
}

class Polygon {
  final List<LatLng> points;
  final List<Offset> offsets = [];
  List<List<Offset>> rings = [];

  final Color color;
  final double borderStrokeWidth;
  final Color borderColor;
  final bool isDotted;
  LatLngBounds boundingBox;

  Polygon({
    this.points,
    this.color = const Color(0xFF00FF00),
    this.borderStrokeWidth = 0.0,
    this.borderColor = const Color(0xFFFFFF00),
    this.isDotted = false,
  }) {
    boundingBox = LatLngBounds.fromPoints(points);
  }

  void buildRings() {
    this.rings.clear();
    List<List<Offset>> rings = new List();
    Offset ringStart = offsets[0];
    int slidingWindow = 0;
    for(int i = 1; i < offsets.length-1; i++){
      Offset cur = offsets[i];
      if(ringStart == cur){
        //found the ring start, this is the end of the first polygon
        rings.add(offsets.sublist(slidingWindow, i+1));
        slidingWindow = i + 3;
        if(slidingWindow < offsets.length-1) {
          i = slidingWindow;
          ringStart = offsets[slidingWindow];
        }
      }
    }
    this.rings = rings;
  }
}

class PolygonLayerWidget extends StatelessWidget {
  final PolygonLayerOptions options;
  PolygonLayerWidget({@required this.options}) : super(key: options.key);

  @override
  Widget build(BuildContext context) {
    final mapState = MapState.of(context);
    return PolygonLayer(options, mapState, mapState.onMoved);
  }
}

class PolygonLayer extends StatelessWidget {
  final PolygonLayerOptions polygonOpts;
  final MapState map;
  final Stream stream;

  PolygonLayer(this.polygonOpts, this.map, this.stream)
      : super(key: polygonOpts.key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bc) {
        // TODO unused BoxContraints should remove?
        final size = Size(bc.maxWidth, bc.maxHeight);
        return _build(context, size);
      },
    );
  }

  Widget _build(BuildContext context, Size size) {
    return StreamBuilder(
      stream: stream, // a Stream<void> or null
      builder: (BuildContext context, _) {
        var polygons = <Widget>[];

        for (var polygon in polygonOpts.polygons) {
          polygon.offsets.clear();

          if (polygonOpts.polygonCulling &&
              !polygon.boundingBox.isOverlapping(map.bounds)) {
            // skip this polygon as it's offscreen
            continue;
          }

          _fillOffsets(polygon.offsets, polygon.points);

          polygon.buildRings();

          polygons.add(
            CustomPaint(
              painter: PolygonPainter(polygon),
              size: size,
            ),
          );
        }

        return Container(
          child: Stack(
            children: polygons,
          ),
        );
      },
    );
  }

  void _fillOffsets(final List<Offset> offsets, final List<LatLng> points) {
    for (var i = 0; i < points.length; i++) {
      var point = points[i];

      var pos = map.project(point);
      pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) -
          map.getPixelOrigin();
      offsets.add(Offset(pos.x.toDouble(), pos.y.toDouble()));
      if (i > 0) {
        offsets.add(Offset(pos.x.toDouble(), pos.y.toDouble()));
      }
    }
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
    _paintPolygon(canvas, rect);
  }

  void _paintBorder(Canvas canvas) {
    if (polygonOpt.borderStrokeWidth > 0.0) {
      var borderRadius = (polygonOpt.borderStrokeWidth / 2);

      final borderPaint = Paint()
        ..color = polygonOpt.borderColor
        ..strokeWidth = polygonOpt.borderStrokeWidth;

      if (polygonOpt.isDotted) {
        var spacing = polygonOpt.borderStrokeWidth * 1.5;
        for(var ring in polygonOpt.rings) {
          _paintDottedLine(canvas, ring, borderRadius, spacing, borderPaint);
        }
      } else {
        for(var ring in polygonOpt.rings) {
          _paintLine(canvas, ring, borderRadius, borderPaint);
        }
      }
    }
  }

  void _paintDottedLine(Canvas canvas, List<Offset> offsets, double radius,
      double stepLength, Paint paint) {
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
      startDistance = distance < totalDistance
          ? stepLength - (totalDistance - distance)
          : distance - totalDistance;
    }
    canvas.drawCircle(offsets.last, radius, paint);
  }

  void _paintLine(
      Canvas canvas, List<Offset> offsets, double radius, Paint paint) {
    canvas.drawPoints(PointMode.lines, [...offsets, offsets[0]], paint);
    for (var offset in offsets) {
      canvas.drawCircle(offset, radius, paint);
    }
  }

  void _paintPolygon(Canvas canvas, Rect rect) {
    final paint = Paint();

    canvas.clipRect(rect);

    paint
      ..style = PaintingStyle.fill
      ..color = polygonOpt.color;

    var path = Path();
    for(var ring in polygonOpt.rings) {
      path.addPolygon(ring, true);
    }
    canvas.drawPath(path, paint);

    _paintBorder(canvas);
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
