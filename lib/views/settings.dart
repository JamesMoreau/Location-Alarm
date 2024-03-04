import 'dart:io';

import 'package:feedback_sentry/feedback_sentry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:june/june.dart';
import 'package:loca_alert/constants.dart';
import 'package:loca_alert/loca_alert_state.dart';
import 'package:path_provider/path_provider.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return JuneBuilder(
      () => LocaAlertState(),
      builder: (state) {
        return SafeArea(
          child: Scrollbar(
            child: ListView(
              children: [
                /*Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SwitchListTile(
                    title: Text('Alarm Notification'),
                    value: state.notification,
                    onChanged: (value) {
                      changeAlarmNotification(newValue: value);
                    },
                    thumbIcon: thumbIcon,
                  ),
                ),*/
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text('Alarm Sound'),
                    trailing: Switch(
                      value: state.alarmSound,
                      thumbIcon: thumbIcon,
                      onChanged: (value) {
                        changeAlarmSound(newValue: value);
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text('Vibration'),
                    trailing: Switch(
                      value: state.vibration,
                      thumbIcon: thumbIcon,
                      onChanged: (value) {
                        changeVibration(newValue: value);
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text('Show Closest Off-Screen Alarm'),
                    trailing: Switch(
                      value: state.showClosestOffScreenAlarm,
                      onChanged: (value) {
                        changeShowClosestOffScreenAlarm(newValue: value);
                      },
                      thumbIcon: thumbIcon,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text('Location Settings'),
                    trailing: Icon(Icons.keyboard_arrow_right),
                    onTap: Geolocator.openLocationSettings,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text('Give Feedback'),
                    trailing: Icon(Icons.feedback_rounded),
                    onTap: () {
                      BetterFeedback.of(context).showAndUploadToSentry();
                    },
                  ),
                ),
                if (kDebugMode)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text('Print Alarms In Storage.'),
                      trailing: Icon(Icons.alarm_rounded),
                      onTap: () async {
                        var directory = await getApplicationDocumentsDirectory();
                        var alarmsPath = '${directory.path}${Platform.pathSeparator}$alarmsFilename';
                        var alarmsFile = File(alarmsPath);

                        if (!alarmsFile.existsSync()) {
                          debugPrint('Warning: No alarms file found in storage.');
                          return;
                        }

                        var alarmJsons = await alarmsFile.readAsString();
                        if (alarmJsons.isEmpty) {
                          debugPrint('No alarms found in storage.');
                          return;
                        }

                        debugPrint('Alarms found in storage: $alarmJsons');
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// for switch icons.
final MaterialStateProperty<Icon?> thumbIcon = MaterialStateProperty.resolveWith<Icon?>((states) {
  if (states.contains(MaterialState.selected)) return const Icon(Icons.check_rounded);
  return const Icon(Icons.close_rounded);
});
