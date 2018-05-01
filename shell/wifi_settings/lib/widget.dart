import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

import 'src/fuchsia/wifi_settings_model.dart';
import 'src/wlan_info.dart';

/// Embeddable widget allowing the user to connect to wifi
Widget buildWlanWidget() {
  return new ScopedModel<WifiSettingsModel>(
      model: new WifiSettingsModel(), child: const WlanInfo());
}
