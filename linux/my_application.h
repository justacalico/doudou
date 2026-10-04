#ifndef FLUTTER_MY_APPLICATION_H_
#define FLUTTER_MY_APPLICATION_H_

#include <gtk/gtk.h>

G_DECLARE_FINAL_TYPE(MyApplication, my_application, MY, APPLICATION,
                     GtkApplication)

/**
 * my_application_new:
 * @server_mode: TRUE when the process runs the headless sync server.
 *
 * Creates a new Flutter-based application. In server mode the application is
 * non-unique and never creates a window; it only hosts a headless engine.
 *
 * Returns: a new #MyApplication.
 */
MyApplication* my_application_new(gboolean server_mode);

#endif  // FLUTTER_MY_APPLICATION_H_
