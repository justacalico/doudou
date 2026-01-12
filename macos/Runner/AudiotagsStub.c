// Stub implementations for audiotags flutter_rust_bridge symbols
// These are needed because the audiotags macOS static library has broken/missing symbols
// The actual functionality is disabled via Platform.isMacOS check in Dart code

#include <stdint.h>

void* drop_dart_object(void* ptr) { return 0; }
void* free_WireSyncReturn(void* ptr) { return 0; }
void* get_dart_object(void* ptr) { return 0; }
void* new_box_autoadd_mime_type_0(void) { return 0; }
void* new_box_autoadd_tag_0(void) { return 0; }
void* new_box_autoadd_u32_0(void) { return 0; }
void* new_dart_opaque(void* ptr) { return 0; }
void* new_list_picture_0(int32_t len) { return 0; }
void* new_uint_8_list_0(int32_t len) { return 0; }
void* wire_read(void* port, void* path) { return 0; }
void* wire_write(void* port, void* path, void* tag) { return 0; }
