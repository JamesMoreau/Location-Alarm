import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_alarm/alarm.dart';
import 'package:location_alarm/constants.dart';
import 'package:location_alarm/location_alarm_state.dart';
import 'package:location_alarm/main.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<ProximityAlarmState>(
      builder: (state) {
        var statusBarHeight = MediaQuery.of(context).padding.top;

        // Place all the alarms on the map.
        var circles = <CircleMarker>[];
        for (var alarm in state.alarms) {
          var marker = CircleMarker(
            point: alarm.position,
            color: alarm.color.withOpacity(alarmColorOpacity),
            borderColor: alarmBorderColor,
            borderStrokeWidth: alarmBorderWidth,
            radius: alarm.radius,
            useRadiusInMeter: true,
          );
          circles.add(marker);
        }

        // Overlay the alarm placement marker on top of the map. This is only visible when the user is placing an alarm.
        if (state.isPlacingAlarm) {
          var alarmPlacementPosition = state.mapController.camera.center;
          var alarmPlacementMarker = CircleMarker(
            point: alarmPlacementPosition,
            radius: state.alarmPlacementRadius,
            color: Colors.redAccent.withOpacity(0.5),
            borderColor: Colors.black,
            borderStrokeWidth: 2,
            useRadiusInMeter: true,
          );
          circles.add(alarmPlacementMarker);
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            FlutterMap(
              mapController: state.mapController,
              options: MapOptions(
                initialCenter: LatLng(0, 0),
                initialZoom: initialZoom,
                interactionOptions: InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                maxZoom: maxZoomSupported,
                keepAlive: true, // Keep the map alive when it is not visible.
                onMapEvent: (event) => state.update(), // @Speed Currently, we rebuild the MapView widget on every map event. Maybe this is slow.
              ),
              children: [
                TileLayer(
                  // urlTemplate: openStreetMapTemplateUrl,
                  urlTemplate: openStreetMapTemplateUrl,
                  userAgentPackageName: 'com.location_alarm.app',
                  tileProvider: CancellableNetworkTileProvider(),
                ),
                CircleLayer(circles: circles),
                CurrentLocationLayer(),
              ],
            ),
            Positioned( // Attribution to OpenStreetMap
              top: statusBarHeight + 5,
              child: Align(
                child: Container(
                  padding: EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '© OpenStreetMap contributors',
                  ),
                ),
              ),
            ),
            Positioned(
              // Place the alarm placement buttons in the top right corner.
              top: statusBarHeight + 10,
              right: 15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  FloatingActionButton(onPressed: navigateMapToUserLocation, elevation: 4, child: Icon(CupertinoIcons.location_fill)),
                  SizedBox(height: 10),
                  if (state.isPlacingAlarm) ...[
                    // Show the confirm and cancel buttons when the user is placing an alarm.
                    FloatingActionButton(
                      onPressed: () {
                        // Save alarm
                        var alarmPlacementPosition = state.mapController.camera.center;
                        var alarm = createAlarm(name: 'Alarm', position: alarmPlacementPosition, radius: state.alarmPlacementRadius);
                        addAlarm(alarm);
                        resetAlarmPlacementUIState();
                        state.update();
                      },
                      elevation: 4,
                      child: Icon(Icons.check),
                    ),
                    SizedBox(height: 10),
                    FloatingActionButton(
                      onPressed: () {
                        resetAlarmPlacementUIState();
                        state.update();
                      },
                      elevation: 4,
                      child: Icon(Icons.cancel_rounded),
                    ),
                  ] else ...[
                    // Show the place alarm button when the user is not placing an alarm.
                    FloatingActionButton(
                      onPressed: () {
                        state.isPlacingAlarm = true;
                        state.update();
                      },
                      elevation: 4,
                      child: Icon(Icons.pin_drop_rounded),
                    ),
                  ],
                  SizedBox.shrink(),
                ],
              ),
            ),
            if (state.isPlacingAlarm) // Show the slider to adjust the new alarm's radius.
              Positioned(
                bottom: 150,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    child: Row(
                      children: [
                        Text('Size:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Slider(
                            value: state.alarmPlacementRadius,
                            onChanged: (value) {
                              state.alarmPlacementRadius = value;
                              state.update();
                            },
                            min: 100,
                            max: 3000,
                            divisions: 100,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SizedBox.shrink(),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    checkLocationPermissions();
    navigateMapToUserLocation();
    super.initState();
  }

  @override
  void dispose() {
    resetAlarmPlacementUIState();
    super.dispose();
  }
}

Future<void> checkLocationPermissions() async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.deniedForever) {
    debugPrint('Warning: User has denied location permissions.');
    ScaffoldMessenger.of(NavigationService.navigatorKey.currentContext!).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Container(
          padding: const EdgeInsets.all(8),
          child: Text('Location permissions are required to use this app.'),
        ),
        action: SnackBarAction(label: 'Settings', onPressed: Geolocator.openAppSettings),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

Future<void> navigateMapToUserLocation() async {
  var pas = Get.find<ProximityAlarmState>();

  var userPosition = await Geolocator.getLastKnownPosition();
  if (userPosition == null) {
    debugPrint('Error: Unable to navigate map to user location.');
    return;
  }

  var userLocation = LatLng(userPosition.latitude, userPosition.longitude);
  pas.mapController.move(userLocation, initialZoom);
}
