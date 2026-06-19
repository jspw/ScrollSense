#include "CScrollHID.h"
#include <CoreFoundation/CoreFoundation.h>

// IOHIDEvent is an opaque type. Forward-declare it to match the system typedef.
typedef struct __IOHIDEvent *IOHIDEventRef;

// Private IOKit / CoreGraphics symbols. These are exported by the frameworks
// but have no public header, so we declare them ourselves.
extern IOHIDEventRef CGEventCopyIOHIDEvent(CGEventRef event);
extern double IOHIDEventGetFloatValue(IOHIDEventRef event, uint32_t field);
extern void IOHIDEventSetFloatValue(IOHIDEventRef event, uint32_t field, double value);

// Field selectors from <IOKit/hid/IOHIDEventField.h>:
//   IOHIDEventFieldBase(type) == (type << 16); kIOHIDEventTypeScroll == 6
#define SS_IOHID_SCROLL_X (6 << 16)        // kIOHIDEventFieldScrollX
#define SS_IOHID_SCROLL_Y ((6 << 16) + 1)  // kIOHIDEventFieldScrollY

void ss_invert_iohid_scroll(CGEventRef event) {
    IOHIDEventRef hid = CGEventCopyIOHIDEvent(event);
    if (!hid) {
        return;
    }
    double y = IOHIDEventGetFloatValue(hid, SS_IOHID_SCROLL_Y);
    double x = IOHIDEventGetFloatValue(hid, SS_IOHID_SCROLL_X);
    IOHIDEventSetFloatValue(hid, SS_IOHID_SCROLL_Y, -y);
    IOHIDEventSetFloatValue(hid, SS_IOHID_SCROLL_X, -x);
    CFRelease(hid);  // CGEventCopyIOHIDEvent returns a +1 reference
}
