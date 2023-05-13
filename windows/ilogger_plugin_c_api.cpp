#include "include/ilogger/ilogger_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "ilogger_plugin.h"

void IloggerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  ilogger::IloggerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
