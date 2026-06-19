#ifndef C_SCROLL_HID_H
#define C_SCROLL_HID_H

#include <CoreGraphics/CoreGraphics.h>

/// Negate the scroll X/Y values carried in the CGEvent's embedded IOHID event.
///
/// For trackpad (continuous) scroll events, apps read the precise scroll amount
/// from the embedded IOHID event, not from the CGEvent delta fields. Reversing
/// scroll direction therefore requires flipping these fields too. Uses private
/// IOKit symbols that have no public Swift-importable header.
void ss_invert_iohid_scroll(CGEventRef event);

#endif /* C_SCROLL_HID_H */
