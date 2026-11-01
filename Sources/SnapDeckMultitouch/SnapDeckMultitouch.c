#include "SnapDeckMultitouch.h"

#include <dlfcn.h>
#include <math.h>
#include <pthread.h>
#include <stddef.h>
#include <string.h>

typedef void *MTDeviceRef;

typedef struct {
    float x;
    float y;
} MTPoint;

typedef struct {
    MTPoint position;
    MTPoint velocity;
} MTVector;

/// Compatibility layout used by MultitouchSupport on modern macOS. It is kept
/// private to this bridge and never exposed to Swift.
typedef struct {
    int32_t frame;
    int32_t padding;
    double timestamp;
    int32_t identifier;
    int32_t state;
    int32_t finger_id;
    int32_t hand_id;
    MTVector normalized;
    float size;
    int32_t zero1;
    float angle;
    float major_axis;
    float minor_axis;
    MTVector millimeters;
    int32_t zero2[2];
    float unknown;
} MTTouch;

typedef int (*MTContactCallback)(MTDeviceRef, MTTouch *, int32_t, double, int32_t);
typedef MTDeviceRef (*MTDeviceCreateDefaultFn)(void);
typedef void (*MTRegisterContactFrameCallbackFn)(MTDeviceRef, MTContactCallback);
typedef void (*MTUnregisterContactFrameCallbackFn)(MTDeviceRef, MTContactCallback);
typedef void (*MTDeviceStartFn)(MTDeviceRef, int32_t);
typedef void (*MTDeviceStopFn)(MTDeviceRef);
typedef void (*MTDeviceReleaseFn)(MTDeviceRef);
typedef bool (*MTDeviceIsRunningFn)(MTDeviceRef);

static const char *framework_path =
    "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport";

static pthread_mutex_t state_lock = PTHREAD_MUTEX_INITIALIZER;
static void *framework_handle = NULL;
static MTDeviceRef device = NULL;
static SDTouchFrameCallback client_callback = NULL;
static void *client_context = NULL;
static MTUnregisterContactFrameCallbackFn unregister_callback = NULL;
static MTDeviceStopFn stop_device = NULL;
static MTDeviceReleaseFn release_device = NULL;
static MTDeviceIsRunningFn device_is_running = NULL;
static bool running = false;
static char last_error[192] = "not started";
static int32_t last_forwarded_active_count = 0;
static double last_forwarded_timestamp = 0;
static int32_t minimum_contact_count = 3;
static const double frame_interval = 1.0 / 60.0;

static void set_error(const char *message) {
    pthread_mutex_lock(&state_lock);
    if (message == NULL) {
        last_error[0] = '\0';
    } else {
        strncpy(last_error, message, sizeof(last_error) - 1);
        last_error[sizeof(last_error) - 1] = '\0';
    }
    pthread_mutex_unlock(&state_lock);
}

static int contact_frame_callback(
    MTDeviceRef callback_device,
    MTTouch *touches,
    int32_t count,
    double timestamp,
    int32_t frame
) {
    (void)callback_device;
    (void)frame;

    if (count < 0 || count > 32 || (count > 0 && touches == NULL)) {
        return 0;
    }

    int32_t active_count = 0;
    float sum_x = 0;
    float sum_y = 0;
    for (int32_t index = 0; index < count; index++) {
        if (touches[index].state == 3 || touches[index].state == 4) {
            active_count++;
            sum_x += touches[index].normalized.position.x;
            sum_y += touches[index].normalized.position.y;
        }
    }

    float cx = active_count > 0 ? sum_x / (float)active_count : 0;
    float cy = active_count > 0 ? sum_y / (float)active_count : 0;

    float spread = 0;
    if (active_count > 1) {
        float sum_squared = 0;
        for (int32_t index = 0; index < count; index++) {
            if (touches[index].state != 3 && touches[index].state != 4) {
                continue;
            }
            float dx = touches[index].normalized.position.x - cx;
            float dy = touches[index].normalized.position.y - cy;
            sum_squared += dx * dx + dy * dy;
        }
        spread = sqrtf(sum_squared / (float)active_count);
    }

    pthread_mutex_lock(&state_lock);
    SDTouchFrameCallback callback = client_callback;
    void *context = client_context;
    int32_t minimum = minimum_contact_count;
    bool had_forwarded_touches = last_forwarded_active_count > 0;
    bool should_forward = false;

    if (active_count < minimum) {
        // Send terminal frames down to zero so the recognizer can release its
        // lock only after the pad is fully empty.
        if (had_forwarded_touches) {
            should_forward = true;
        }
    } else {
        should_forward = active_count != last_forwarded_active_count
            || timestamp <= last_forwarded_timestamp
            || timestamp - last_forwarded_timestamp >= frame_interval;
    }

    if (should_forward) {
        last_forwarded_active_count = active_count;
        last_forwarded_timestamp = timestamp;
    }
    pthread_mutex_unlock(&state_lock);

    if (callback != NULL && should_forward) {
        SDTouchFrame output = {
            .count = active_count,
            .x = cx,
            .y = cy,
            .spread = spread,
            .timestamp = timestamp
        };
        callback(&output, context);
    }
    return 0;
}

void SDMTSetMinimumContactCount(int32_t count) {
    if (count < 1) {
        count = 1;
    } else if (count > 4) {
        count = 4;
    }
    pthread_mutex_lock(&state_lock);
    if (minimum_contact_count != count) {
        minimum_contact_count = count;
        last_forwarded_active_count = 0;
        last_forwarded_timestamp = 0;
    }
    pthread_mutex_unlock(&state_lock);
}

bool SDMTIsAvailable(void) {
    void *handle = dlopen(framework_path, RTLD_LAZY | RTLD_LOCAL);
    if (handle == NULL) {
        return false;
    }
    bool available =
        dlsym(handle, "MTDeviceCreateDefault") != NULL &&
        dlsym(handle, "MTRegisterContactFrameCallback") != NULL &&
        dlsym(handle, "MTDeviceStart") != NULL &&
        dlsym(handle, "MTDeviceStop") != NULL;
    dlclose(handle);
    return available;
}

bool SDMTIsRunning(void) {
    pthread_mutex_lock(&state_lock);
    bool current_running = running;
    MTDeviceRef current_device = device;
    MTDeviceIsRunningFn current_is_running = device_is_running;
    pthread_mutex_unlock(&state_lock);

    if (!current_running || current_device == NULL) {
        return false;
    }
    if (current_is_running == NULL) {
        return true;
    }
    return current_is_running(current_device);
}

const char *SDMTLastError(void) {
    return last_error;
}

bool SDMTStart(SDTouchFrameCallback callback, void *context) {
    if (callback == NULL) {
        set_error("touch callback is NULL");
        return false;
    }

    pthread_mutex_lock(&state_lock);
    if (running) {
        client_callback = callback;
        client_context = context;
        pthread_mutex_unlock(&state_lock);
        return true;
    }

    void *handle = dlopen(framework_path, RTLD_LAZY | RTLD_LOCAL);
    if (handle == NULL) {
        pthread_mutex_unlock(&state_lock);
        set_error("MultitouchSupport.framework is unavailable");
        return false;
    }

    MTDeviceCreateDefaultFn create_device = NULL;
    MTRegisterContactFrameCallbackFn register_callback = NULL;
    MTDeviceStartFn start_device = NULL;
    MTDeviceStopFn resolved_stop = NULL;
    MTUnregisterContactFrameCallbackFn resolved_unregister = NULL;
    MTDeviceReleaseFn resolved_release = NULL;
    MTDeviceIsRunningFn resolved_is_running = NULL;

    bool resolved =
        (create_device = (MTDeviceCreateDefaultFn)dlsym(handle, "MTDeviceCreateDefault")) != NULL &&
        (register_callback = (MTRegisterContactFrameCallbackFn)dlsym(handle, "MTRegisterContactFrameCallback")) != NULL &&
        (start_device = (MTDeviceStartFn)dlsym(handle, "MTDeviceStart")) != NULL &&
        (resolved_stop = (MTDeviceStopFn)dlsym(handle, "MTDeviceStop")) != NULL;

    if (!resolved) {
        dlclose(handle);
        pthread_mutex_unlock(&state_lock);
        set_error("required MultitouchSupport symbols are unavailable");
        return false;
    }

    resolved_unregister = (MTUnregisterContactFrameCallbackFn)dlsym(handle, "MTUnregisterContactFrameCallback");
    resolved_release = (MTDeviceReleaseFn)dlsym(handle, "MTDeviceRelease");
    resolved_is_running = (MTDeviceIsRunningFn)dlsym(handle, "MTDeviceIsRunning");

    MTDeviceRef created_device = create_device();
    if (created_device == NULL) {
        dlclose(handle);
        pthread_mutex_unlock(&state_lock);
        set_error("no trackpad device was found");
        return false;
    }

    framework_handle = handle;
    device = created_device;
    client_callback = callback;
    client_context = context;
    unregister_callback = resolved_unregister;
    stop_device = resolved_stop;
    release_device = resolved_release;
    device_is_running = resolved_is_running;
    last_forwarded_active_count = 0;
    last_forwarded_timestamp = 0;
    running = true;
    last_error[0] = '\0';
    pthread_mutex_unlock(&state_lock);

    register_callback(created_device, contact_frame_callback);
    start_device(created_device, 0);
    return true;
}

void SDMTStop(void) {
    pthread_mutex_lock(&state_lock);
    MTDeviceRef current_device = device;
    MTUnregisterContactFrameCallbackFn current_unregister = unregister_callback;
    MTDeviceStopFn current_stop = stop_device;
    MTDeviceReleaseFn current_release = release_device;

    client_callback = NULL;
    client_context = NULL;
    last_forwarded_active_count = 0;
    last_forwarded_timestamp = 0;
    running = false;
    pthread_mutex_unlock(&state_lock);

    if (current_device == NULL) {
        return;
    }
    if (current_unregister != NULL) {
        current_unregister(current_device, contact_frame_callback);
    }
    if (current_stop != NULL) {
        current_stop(current_device);
    }
    if (current_release != NULL) {
        current_release(current_device);
    }

    pthread_mutex_lock(&state_lock);
    device = NULL;
    unregister_callback = NULL;
    stop_device = NULL;
    release_device = NULL;
    device_is_running = NULL;
    pthread_mutex_unlock(&state_lock);
}
