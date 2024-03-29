import 'dart:async';
import 'dart:io';

import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:june/june.dart';
import 'package:latlong2/latlong.dart';
import 'package:loca_alert/globals_constants_and_utility.dart';
import 'package:loca_alert/loca_alert_state.dart';
import 'package:loca_alert/views/alarms.dart';
import 'package:loca_alert/views/map.dart';
import 'package:loca_alert/views/settings.dart';
import 'package:location/location.dart';
import 'package:path_provider/path_provider.dart';

/*
 TODO:
*/

void main() async {
  // Check that we are on a supported platform
  if ( !(Platform.isIOS || Platform.isAndroid) ) {
    debugPrintError('This app is not supported on this platform. Supported platforms are iOS and Android.');
    return;
  }

  runApp(const MainApp());

  // Setup state
	var state = June.getState(LocaAlertState());

  // Set up local notifications.
  var initializationSettings = const InitializationSettings(iOS: DarwinInitializationSettings());
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Set up location stuff
  await location.enableBackgroundMode();
  location.onLocationChanged.listen((location) async { // Register the location update callback
    var latitude = location.latitude;
    var longitude = location.longitude;
    if (latitude == null || longitude == null) return; // This shouldn't happen, but just in case.
    
    var state = June.getState(LocaAlertState());
    state.userLocation = LatLng(latitude, longitude);
    state.setState();

    await checkAlarms(); // Check if the user has entered the radius of any alarms.

    // Update the map camera position to the user's location
    if (state.followUserLocation && state.currentView == ProximityAlarmViews.map)	await moveMapToUserLocation();
  });
  Timer.periodic(const Duration(seconds: 20), (timer) async { // Check periodically if the location permission has been denied. If so, cancel the location updates.
    var state = June.getState(LocaAlertState());
    var permission = await location.hasPermission();

    if (permission == PermissionStatus.denied || permission == PermissionStatus.deniedForever) {
      state.userLocation = null;
      state.followUserLocation = false;
      state.setState();
    }
  });
  
  // Load saved alarms and settings.
	await loadSettingsFromStorage();
  await loadAlarmsFromStorage();

  // Set up http overrides. This is needed to increase the number of concurrent http requests allowed. This helps with the map tiles loading.
  HttpOverrides.global = MyHttpOverrides();

  // Load map tile cache
  var cacheDirectory = await getApplicationCacheDirectory();
  var mapTileCachePath = '${cacheDirectory.path}${Platform.pathSeparator}$mapTileCacheFilename';
	state.mapTileCacheStore = FileCacheStore(mapTileCachePath);
  state.setState(); // Notify the ui that the map tile cache is loaded.
}

enum ProximityAlarmViews { alarms, map, settings }

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set preferred orientation to portrait
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: JuneBuilder(
        () => LocaAlertState(),
        builder: (state) {

          // Check that everything is initialized before building the app. Right now, the only thing that needs to be initialized is the map tile cache.
          var appIsInitialized = state.mapTileCacheStore != null;
          if (!appIsInitialized) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          return Scaffold(
            body: PageView(
              controller: state.pageController,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe gesture to change pages
              children: [
                const AlarmsView(),
                const MapView(),
                const SettingsView(),
              ],
            ),
            extendBody: true,
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 5,
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
              ),
							child: ClipRRect(
								borderRadius: const BorderRadius.only(
									topLeft: Radius.circular(50),
									topRight: Radius.circular(50),
								),
								child: NavigationBar(
									elevation: 3,
									onDestinationSelected: (int index) {
										state.currentView = ProximityAlarmViews.values[index];
										debugPrint('Navigating to ${state.currentView}.');
										state.setState();
										state.pageController.jumpToPage(index);
										// state.pageController.animateToPage(index, duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
									},
									selectedIndex: state.currentView.index,
									destinations: const [
										NavigationDestination(
											icon: Icon(Icons.pin_drop_rounded),
											label: 'Alarms',
										),
										NavigationDestination(
											icon: Icon(Icons.map_rounded),
											label: 'Map',
										),
										NavigationDestination(
											icon: Icon(Icons.settings_rounded),
											label: 'Settings',
										),
									],
								),
							),
						),
          );
        },
      ),
      theme: locationAlarmTheme,
      navigatorKey: NavigationService.navigatorKey,
    );
  }
}
