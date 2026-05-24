#include "include/flutter_rhwp/flutter_rhwp_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_rhwp_plugin.h"

void FlutterRhwpPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_rhwp::FlutterRhwpPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
