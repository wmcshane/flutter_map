import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../widgets/drawer.dart';
import 'package:latlong/latlong.dart';
import 'package:flutter_map/resource.dart';
import 'dart:math' as Math;

class OfflineMapPage extends StatefulWidget
{
  static const String route = '/offline_map';

  String get routeName => route;

  @override
  State<StatefulWidget> createState() {
    return OfflineMapPageState();
  }
}

class OfflineMapPageState extends State<OfflineMapPage> {
  List<LatLng> drawingPoints = List();
  double epsilon = 0.5;
  double epsilonMin = 0;
  double epsilonMax = 0.7;

  double zoomMin = 3.0;
  double zoomMax = 10.0;
  double minEpsilonZoomOffset = 2.0;
  double maxEpsilonZoomOffset = 1.0;

  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(title: new Text("Offline Map")),
      drawer: buildDrawer(context, widget.routeName),
      body: new Padding(
        padding: new EdgeInsets.all(8.0),
        child: new Column(
          children: [
            new Padding(
              padding: new EdgeInsets.only(top: 8.0, bottom: 8.0),
              child: new Text(
                  "This is an offline map that is showing Anholt Island, Denmark."),
            ),
            new Flexible(
              child: new FlutterMap(
                options: new MapOptions(
                  onTap: (tappedPoint){
                    setState(() {
                      drawingPoints.add(tappedPoint);
                    });
                  },
                  onLongPress: (tappedPoint)
                  {
                    String line = "";
                    for(int i = 0; i < drawingPoints.length; i++)
                    {
                      line += 'LatLng(${drawingPoints[i].latitude}, ${drawingPoints[i].longitude}),\n';
                    }
                    printWrapped(line);
                  },
                  onPositionChanged: (mapPos, hasGesture, hasUserGesture)
                  {

                    // epsilon based on zoom
                    double zMin = Math.min((zoomMin + minEpsilonZoomOffset), zoomMax);
                    //print("zoom min = $zMin");
                    double zMax = Math.max((zoomMax - maxEpsilonZoomOffset), zoomMin);
                    //print("zoom max = $zMax");
                    double zoomMinMaxDiff = zMax-zMin;
                    double percentageToMaxZoom = (mapPos.zoom-zMin)/(zoomMinMaxDiff);
                    //print(percentageToMaxZoom);
                    double epsilonVal = (((1 - percentageToMaxZoom) * (epsilonMax-epsilonMin)) + epsilonMin);
                    epsilonVal = epsilonVal.clamp(epsilonMin, epsilonMax);
                    print(epsilonVal);
                    Future.delayed(Duration(milliseconds: 100),()
                    {
                      setState(() {
                        epsilon = epsilonVal;
                      });
                    });
                  },
                  center: new LatLng(-26.431200, 134.472700),
                  swPanBoundary: LatLng(-44.3867, 112.0496),
                  nePanBoundary: LatLng(-9.9472, 154.4897),
                  minZoom: zoomMin,
                  maxZoom: zoomMax,
                  zoom: 3.0,
                  //center: new LatLng(56.704173, 11.543808),
//                  minZoom: 12.0,
//                  maxZoom: 16.0,
//                  zoom: 13.0,
//                  swPanBoundary: LatLng(56.650266, 11.436351),
//                  nePanBoundary: LatLng(56.781361, 11.733902),
                ),
                layers: [
//                  new TileLayerOptions(
//                    offlineMode: true,
//                    maxZoom: 14.0,
//                    urlTemplate: "assets/map/anholt_osmbright/{z}/{x}/{y}.png",
//                  ),
                  new TileLayerOptions(
                      urlTemplate:
                      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      subdomains: ['a', 'b', 'c']),
                  new PolygonLayerOptions(polygons: [
                    Polygon(color: Colors.red.withAlpha(65), borderColor: Colors.red, borderStrokeWidth: 3.0, points: [
                      LatLng(56.722453, 11.542350),
                      LatLng(56.700385, 11.545177),
                      LatLng(56.704141, 11.582002),
                      LatLng(56.724023, 11.596836),
                      LatLng(56.722453, 11.542350),
                    ]),
                    Polygon(color: Colors.blue.withAlpha(65), borderColor: Colors.blue, borderStrokeWidth: 3.0, points: [
                      LatLng(56.728595, 11.610058),
                      LatLng(56.716968, 11.615169),
                      LatLng(56.736277, 11.661316),
                      LatLng(56.737715, 11.650937),
                      LatLng(56.735263, 11.637895),
                      LatLng(56.728595, 11.610058),
                    ]),
                    Polygon(points: australiaPolygonPoints, color: Colors.deepOrange.withAlpha(65), borderStrokeWidth: 5.0, borderColor: Colors.deepOrange)
                  ],
                  ramerDouglasPeuckerOptions: RamerDouglasPeuckerOptions(apply: true, epsilon: epsilon)),
                  PolylineLayerOptions( polylines:
                    [
                      Polyline(points: List.from(drawingPoints), strokeWidth: 5.0),
                      Polyline(points: [
                        LatLng(56.68647358801834, 11.511632987002764),
                        LatLng(56.68819710266902, 11.513462876206608),
                        LatLng(56.69006362845305, 11.515883330359596),
                        LatLng(56.690783278842034, 11.519284467183654),
                        LatLng(56.69006362845305, 11.524187880539003),
                        LatLng(56.689059882570014, 11.52601992508935),
                        LatLng(56.68783725447781, 11.527392880828849),
                        LatLng(56.68586328919289, 11.528045950827368),
                        LatLng(56.683887115820625, 11.528961973102561),
                        LatLng(56.68216340389397, 11.52961504310108),
                        LatLng(56.68083320840358, 11.531184135374792),
                        LatLng(56.679829216456135, 11.533669249923694),
                        LatLng(56.679829216456135, 11.537266523281968),
                        LatLng(56.68043961307264, 11.539947774365087),
                        LatLng(56.681553035213796, 11.542432888913952),
                        LatLng(56.68277376268234, 11.544001981187664),
                        LatLng(56.68428277970819, 11.545767209995589),
                        LatLng(56.68550341869798, 11.5473363022693),
                        LatLng(56.68536031134662, 11.550476642163268),
                        LatLng(56.68449744667362, 11.552502667901287),
                        LatLng(56.68266642443982, 11.554334712451668),
                        LatLng(56.682413862662465, 11.557015963534749),
                        LatLng(56.683636666849715, 11.560154148082173),
                        LatLng(56.684893104148784, 11.561266306891579),
                        LatLng(56.68500043604492, 11.567085742522082),
                      ], borderStrokeWidth: 5.0, color: Colors.blue, borderColor: Colors.blue)
                    ]
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void printWrapped(String text) {
    final pattern = new RegExp('.{1,800}'); // 800 is the size of each chunk
    pattern.allMatches(text).forEach((match) => print(match.group(0)));
  }
}
