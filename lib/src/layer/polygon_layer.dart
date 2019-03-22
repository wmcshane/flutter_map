import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/src/core/bounds.dart';
import 'package:flutter_map/src/map/map.dart';
import 'package:latlong/latlong.dart' hide Path;  // conflict with Path from UI
import 'dart:math' as Math;

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
  BoundingBox boundingBox;
  Polygon({
    this.points,
    this.color = const Color(0xFF00FF00),
    this.borderStrokeWidth = 0.0,
    this.borderColor = const Color(0xFFFFFF00),
  }){
    this.boundingBox = calcBoundingBox();
  }

  BoundingBox calcBoundingBox()
  {
    num minX;
    num maxX;
    num minY;
    num maxY;

    for(LatLng point in points)
    {
      // convert lat lon to custom point stored as radians
      num x = point.longitude * Math.pi / 180.0;
      num y = point.latitude * Math.pi / 180.0;
      CustomPoint cPoint = CustomPoint(x, y);

      if(minX == null || minX > cPoint.x)
      {
        minX = cPoint.x;
      }

      if(minY == null || minY > cPoint.y)
      {
        minY = cPoint.y;
      }

      if(maxX == null || maxX < cPoint.x)
      {
        maxX = cPoint.x;
      }

      if(maxY == null || maxY < cPoint.y)
      {
        maxY = cPoint.y;
      }
    }

    return BoundingBox(min: Math.Point(minX, minY), max: Math.Point(maxX, maxY));
  }
}

class BoundingBox
{
  Math.Point min;
  Math.Point max;

  BoundingBox({this.min, this.max});

  // bounding box will be stored as latLng in radians instead of degrees
  BoundingBox getAsDegrees()
  {
    BoundingBox latLngBB = BoundingBox (
      min: Math.Point(this.min.x * 180 / Math.pi, this.min.y * 180 / Math.pi),
      max: Math.Point(this.max.x * 180 / Math.pi, this.max.y * 180 / Math.pi),
    );

    return latLngBB;
  }

  BoundingBox getAsRadians()
  {
    BoundingBox radiansBB = BoundingBox (
      min: Math.Point(this.min.x * Math.pi / 180.0, this.min.y * Math.pi / 180.0),
      max: Math.Point(this.max.x * Math.pi / 180.0, this.max.y * Math.pi / 180.0),
    );

    return radiansBB;
  }

  bool isOverlapping(BoundingBox bounds)
  {
    // check if bounding box rectangle is outside the other, if it is then it's considered not overlapping
    if(this.min.y > bounds.max.y || this.max.y < bounds.min.y || this.max.x < bounds.min.x || this.min.x > bounds.max.x)
    {
      return false;
    }

    return true;
  }

  @override
  String toString()
  {
    return '$min | $max';
  }
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
          if(!polygonOpt.boundingBox.isOverlapping(screenBBRadians))
          {
            // skip this polygon as it's offscreen
            continue;
          }

          // TODO: polygon clipping, this will speed up the drawing of large complex polygones when up close.
//          // clip the polygon, we don't want to draw parts that are way off screen
//          List<LatLng> clippedPolygon = clipPolygon(polygonOpt, screenPoly);
//          polygonOpt = Polygon(points: clippedPolygon, borderStrokeWidth: polygonOpt.borderStrokeWidth, borderColor: polygonOpt.borderColor, color: polygonOpt.color);

          List<LatLng> clippedPoly = clipPolygon(polygonOpt.points, [screenBounds.northWest, screenBounds.southWest, screenBounds.southEast, screenBounds.northEast]);
          polygonOpt = Polygon(points: clippedPoly, color: polygonOpt.color, borderColor: polygonOpt.borderColor, borderStrokeWidth: polygonOpt.borderStrokeWidth);

          // print('\nScreen: $screenBounds');
          // print('min: $minPos | max: $maxPos');
          // print ('min: $minBound | max: $maxBound');

          // convert polygon points to screen space
          for (var point in polygonOpt.points) {
            var pos = map.project(point);
            pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
            polygonOpt.offsets.add(new Offset(pos.x.toDouble(), pos.y.toDouble()));
            if (i > 0 && i < polygonOpt.points.length) {
              polygonOpt.offsets.add(new Offset(pos.x.toDouble(), pos.y.toDouble()));
            }
            i++;
          }

          // add polygons to be rendered
          polygons.add(
            new CustomPaint(
              painter: new PolygonPainter(polygonOpt),
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
  if(outputList != null && outputList.isNotEmpty){
    if(outputList.first == outputList.last) {
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
        if (!isInside(A, B, P))
          outputList.add(intersection(A, B, P, Q));
        outputList.add(Q);
      } else if (isInside(A, B, P))
        outputList.add(intersection(A, B, P, Q));
    }

    //print(outputList);
  }

  // re add linking point
  if (outputList != null && outputList.isNotEmpty) {
    if(removedLast) {
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

    canvas.clipRect(rect);
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
