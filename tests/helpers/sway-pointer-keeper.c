/* Private headless-test fixture: keep wl_seat pointer capability alive.
 * No uinput, physical devices or global input. WAYLAND_DISPLAY selects the
 * private compositor created by sway-wallpapers-session.test.py.
 */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <wayland-client.h>
#include "virtual-pointer.h"

static struct zwlr_virtual_pointer_manager_v1 *manager;
static void global(void *data, struct wl_registry *registry, uint32_t name,
        const char *interface, uint32_t version) {
    (void)data; (void)version;
    if (strcmp(interface, "zwlr_virtual_pointer_manager_v1") == 0)
        manager = wl_registry_bind(registry, name,
            &zwlr_virtual_pointer_manager_v1_interface, 1);
}
static void removed(void *data, struct wl_registry *registry, uint32_t name) {
    (void)data; (void)registry; (void)name;
}
int main(void) {
    struct wl_display *display = wl_display_connect(NULL);
    assert(display);
    struct wl_registry *registry = wl_display_get_registry(display);
    const struct wl_registry_listener listener = {global, removed};
    wl_registry_add_listener(registry, &listener, NULL);
    assert(wl_display_roundtrip(display) >= 0 && manager);
    struct zwlr_virtual_pointer_v1 *pointer =
        zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager, NULL);
    assert(pointer && wl_display_roundtrip(display) >= 0);
    puts("ready");
    fflush(stdout);
    /* Commands on stdin inject real protocol events, not Sway's synthetic
     * button4/5 IPC events (whose v120 values are 1 on Sway 1.11).
     * w/f <axis: 0 vertical, 1 horizontal> <notches/pixels>.
     */
    char mode;
    unsigned axis;
    double amount;
    while (scanf(" %c %u %lf", &mode, &axis, &amount) == 3) {
        if (axis > 1) return 2;
        if (mode == 'w') {
            zwlr_virtual_pointer_v1_axis_source(pointer, WL_POINTER_AXIS_SOURCE_WHEEL);
            zwlr_virtual_pointer_v1_axis_discrete(pointer, 0, axis,
                wl_fixed_from_double(amount * 15), (int)amount);
        } else if (mode == 'f') {
            zwlr_virtual_pointer_v1_axis_source(pointer, WL_POINTER_AXIS_SOURCE_FINGER);
            zwlr_virtual_pointer_v1_axis(pointer, 0, axis, wl_fixed_from_double(amount));
        } else return 2;
        zwlr_virtual_pointer_v1_frame(pointer);
        assert(wl_display_roundtrip(display) >= 0);
        puts("done");
        fflush(stdout);
    }
    return 0;
}
