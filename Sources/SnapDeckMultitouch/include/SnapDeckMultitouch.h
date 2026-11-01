#ifndef SNAPDECK_MULTITOUCH_H
#define SNAPDECK_MULTITOUCH_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// A compact gesture frame: only the data the window gesture recognizer needs.
typedef struct {
    int32_t count;
    float x;
    float y;
    float spread;
    double timestamp;
} SDTouchFrame;

typedef void (*SDTouchFrameCallback)(const SDTouchFrame *frame, void *context);

/// Starts the default trackpad (including an external Apple Magic Trackpad).
/// Frames with fewer than three active contacts are not forwarded, except for
/// one terminal frame after a multi-finger contact ends.
bool SDMTStart(SDTouchFrameCallback callback, void *context);

void SDMTStop(void);

/// True when the private framework and all required symbols are available.
bool SDMTIsAvailable(void);

/// True when a device was acquired and started.
bool SDMTIsRunning(void);

const char *SDMTLastError(void);

#ifdef __cplusplus
}
#endif

#endif
