#include <desktop_multi_window/desktop_multi_window_plugin.h>
#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <window_manager/window_manager_plugin.h>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"
#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Sub-window engines get the desktop_multi_window plugin registered by the
  // plugin itself, and their event channel is wired up BEFORE this callback runs.
  // Do NOT call the generated RegisterPlugins() on a sub-window engine: it re-runs
  // DesktopMultiWindowPluginRegisterWithRegistrar, which re-registers the
  // "flutter_multi_window_channel" with window id 0, then tears that channel down
  // because the main window already exists, leaving the sub-window's event channel
  // handler null. After that, invokeMethod(0, ...) from a sub-window throws
  // MissingPluginException, so note edits never reach the main window and are
  // silently lost. Register only the plugins a sub-window truly needs, one by one.
  // Independent note windows need only window_manager for lightweight window
  // controls such as "always on top" and opacity. Registering this single plugin
  // keeps the child window event channel intact while letting Dart control the
  // current child HWND.
  DesktopMultiWindowSetWindowCreatedCallback([](void *controller) {
    auto flutter_controller =
        reinterpret_cast<flutter::FlutterViewController *>(controller);
    WindowManagerPluginRegisterWithRegistrar(
        flutter_controller->engine()->GetRegistrarForPlugin(
            "WindowManagerPlugin"));
  });

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"gitnote_flutter", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
