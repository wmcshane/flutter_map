import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/src/map/map.dart';
import 'package:latlong/latlong.dart' hide Path;  // conflict with Path from UI

class PolygonLayerOptions extends LayerOptions {
  final List<Polygon> polygons;
  PolygonLayerOptions({this.polygons = const [], rebuild})
      : super(rebuild: rebuild);
}

class Polygon {
  final List<LatLng> points;
  final List<Offset> offsets = [];
  final Color color;
  final double borderStrokeWidth;
  final Color borderColor;
  Polygon({
    this.points,
    this.color = const Color(0xFF00FF00),
    this.borderStrokeWidth = 0.0,
    this.borderColor = const Color(0xFFFFFF00),
  });
}

class PolygonLayer extends StatelessWidget {
  final PolygonLayerOptions polygonOpts;
  final MapState map;
  final Stream<Null> stream;

  PolygonLayer(this.polygonOpts, this.map, this.stream);

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
        for (var polygonOpt in polygonOpts.polygons) {
          polygonOpt.offsets.clear();
          var i = 0;
          for (var point in polygonOpt.points) {
            var pos = map.project(point);
            pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
            polygonOpt.offsets.add(new Offset(pos.x.toDouble(), pos.y.toDouble()));
            if (i > 0 && i < polygonOpt.points.length) {
              polygonOpt.offsets.add(new Offset(pos.x.toDouble(), pos.y.toDouble()));
            }
            i++;
          }
        }

        var polygons = <Widget>[];
        for (var polygonOpt in this.polygonOpts.polygons) {
          polygons.add(
            new CustomPaint(
              painter: new PolygonPainter(polygonOpt),
              size: size,
            ),
          );
        }

        return new Container(
          child: new Stack(
            children: polygons,
          ),
        );
      },
    );
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
    for(int i = 1; i < polygonOpt.offsets.length-1; i++){
      Offset cur = polygonOpt.offsets[i];
      if(ringStart == cur){
        //found the ring start, this is the end of the first polygon
        rings.add(polygonOpt.offsets.sublist(slidingWindow, i+1));
        slidingWindow = i + 3;
        if(slidingWindow < polygonOpt.offsets.length-1) {
          i = slidingWindow;
          ringStart = polygonOpt.offsets[slidingWindow];
        }
      }
    }

    _paintPolygon(canvas, rings, paint);

    double borderRadius = (polygonOpt.borderStrokeWidth / 2);
    if (polygonOpt.borderStrokeWidth > 0.0) {
      for(List<Offset> ring in rings) {
        _paintLine(canvas, ring, borderRadius, borderPaint);
      }
    }
  }

  void _paintLine(Canvas canvas, List<Offset> offsets, double radius, Paint paint) {
    canvas.drawPoints(PointMode.lines, offsets, paint);
    for (var offset in offsets) {
      canvas.drawCircle(offset, radius, paint);
    }
  }

  void _paintPolygon(Canvas canvas, List<List<Offset>> polygons, Paint paint) {
    Path path = new Path();
    for(List<Offset> ring in polygons) {
      path.addPolygon(ring, true);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(PolygonPainter other) => false;
}
