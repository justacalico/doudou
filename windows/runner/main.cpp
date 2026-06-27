#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

struct FindWindowData {
  HWND hwnd;
};

static BOOL CALLBACK FindDoudouWindow(HWND hwnd, LPARAM lParam) {
  wchar_t title[256];
  if (GetWindowTextW(hwnd, title, 256) > 0) {
    if (wcscmp(title, L"doudou") == 0 && IsWindowVisible(hwnd)) {
      auto* data = reinterpret_cast<FindWindowData*>(lParam);
      data->hwnd = hwnd;
      return FALSE;
    }
  }
  return TRUE;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE mutex = CreateMutexW(nullptr, TRUE, L"doudou_single_instance_mutex");
  if (mutex == nullptr || GetLastError() == ERROR_ALREADY_EXISTS) {
    if (mutex) CloseHandle(mutex);

    FindWindowData data{nullptr};
    EnumWindows(FindDoudouWindow, reinterpret_cast<LPARAM>(&data));
    if (data.hwnd != nullptr) {
      if (IsIconic(data.hwnd)) {
        ShowWindow(data.hwnd, SW_RESTORE);
      }
      SetForegroundWindow(data.hwnd);
    }
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"doudou", origin, size)) {
    CloseHandle(mutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  CloseHandle(mutex);
  return EXIT_SUCCESS;
}
