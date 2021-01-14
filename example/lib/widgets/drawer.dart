import 'package:flutter/material.dart';

import '../pages/animated_map_controller.dart';
import '../pages/circle.dart';
import '../pages/custom_crs/custom_crs.dart';
import '../pages/esri.dart';
import '../pages/home.dart';
import '../pages/live_location.dart';
import '../pages/map_controller.dart';
import '../pages/marker_anchor.dart';
import '../pages/moving_markers.dart';
import '../pages/offline_map.dart';
import '../pages/on_tap.dart';
import '../pages/overlay_image.dart';
import '../pages/plugin_api.dart';
import '../pages/plugin_scalebar.dart';
import '../pages/plugin_zoombuttons.dart';
import '../pages/polyline.dart';
import '../pages/sliding_map.dart';
import '../pages/tap_to_add.dart';
import '../pages/tile_loading_error_handle.dart';
import '../pages/widgets.dart';
import '../pages/wms_tile_layer.dart';

Widget _buildMenuItem(
    BuildContext context, Widget title, String routeName, String currentRoute) {
  var isSelected = routeName == currentRoute;

  return ListTile(
    title: title,
    selected: isSelected,
    onTap: () {
      if (isSelected) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, routeName);
      }
    },
  );
}

Drawer buildDrawer(BuildContext context, String currentRoute) {
  return Drawer(
    child: ListView(
      children: <Widget>[
        const DrawerHeader(
          child: Center(
            child: Text('Flutter Map Examples'),
          ),
        ),
        _buildMenuItem(
          context,
          const Text('OpenStreetMap'),
          HomePage.route,
          currentRoute,
        ),
        _buildMenuItem(
          context,
          const Text('WMS Layer'),
          WMSLayerPage.route,
          currentRoute,
        ),
        _buildMenuItem(
          context,
          const Text('Custom CRS'),
          CustomCrsPage.route,
          currentRoute,
        ),
        _buildMenuItem(
          context,
          const Text('Add Pins'),
          TapToAddPage.route,
          currentRoute,
        ),
        _buildMenuItem(
          context,
          const Text('Esri'),
          EsriPage.route,
          currentRoute,
        ),
        _buildMenuItem(
          context,
          const Text('Polylines'),
          PolylinePage.route,
          currentRoute,
        ),
        _buildMenuItem(
          context,
          const Text('MapController'),
          MapControllerPage.route,
          currentRoute,
        ),
        _buildMenuItem(
          context,
          const Text('Animated MapController'),
          AnimatedMapControllerPage.route,
          currentRoute,
        ),
        _buildMenuItem(
          context,
          const Text('Marker Anchors'),
          MarkerAnchorPage.route,
          currentRoute,
        ),
        _buildMenuItem(
          context,
          const Text('Plugins'),
          PluginPage.route,
          currentRoute,
        ),
        _buildMenuItem(
          context,
          const Text('ScaleBar Plugins'),
          PluginScaleBar.route,
          currentRoute,
        ),
        _buildMenuItem(
          context,
          const Text('ZoomButtons Plugins'),
          PluginZoomButtons.route,
          currentRoute,
        ),
        _buildMenuItem(
          context,
          const Text('Offline Map'),
          OfflineMapPage.route,
          currentRoute,
        ),
        _buildMenuItem(
          context,
          const Text('OnTap'),
          OnTapPage.route,
          currentRoute,
        ),
        _buildMenuItem(
          context,
          const Text('Moving Markers'),
          MovingMarkersPage.route,
          currentRoute,
        ),
        _buildMenuItem(
          context,
          const Text('Circle'),
          CirclePage.route,
          currentRoute,
        ),
        _buildMenuItem(
          context,
          const Text('Overlay Image'),
          OverlayImagePage.route,
          currentRoute,
        ),
        ListTile(
          title: const Text('Sliding Map'),
          selected: currentRoute == SlidingMapPage.route,
          onTap: () =>
              Navigator.pushReplacementNamed(context, SlidingMapPage.route),
        ),
        ListTile(
          title: const Text('Widgets'),
          selected: currentRoute == WidgetsPage.route,
          onTap: () {
            Navigator.pushReplacementNamed(context, WidgetsPage.route);
          },
        ),
        ListTile(
          title: const Text('Live Location Update'),
          selected: currentRoute == LiveLocationPage.route,
          onTap: () {
            Navigator.pushReplacementNamed(context, LiveLocationPage.route);
          },
        ),
        ListTile(
          title: const Text('Tile loading error handle'),
          selected: currentRoute == TileLoadingErrorHandle.route,
          onTap: () {
            Navigator.pushReplacementNamed(
                context, TileLoadingErrorHandle.route);
          },
        ),
      ],
    ),
  );
}
