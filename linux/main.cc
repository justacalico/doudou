#include "my_application.h"

static gboolean has_server_flag(int argc, char** argv) {
  for (int i = 1; i < argc; ++i) {
    if (g_strcmp0(argv[i], "-server") == 0) {
      return TRUE;
    }
  }
  return FALSE;
}

int main(int argc, char** argv) {
  g_autoptr(MyApplication) app = my_application_new(has_server_flag(argc, argv));
  return g_application_run(G_APPLICATION(app), argc, argv);
}
