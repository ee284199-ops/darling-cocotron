/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

// Original - Christopher Lloyd <cjwl@objc.net>
#import <AppKit/NSApplication.h>
#import <AppKit/NSColorSpace.h>
#import <AppKit/NSDisplay.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSScreen.h>
#import <AppKit/NSWindow.h>

NSNotificationName const NSScreenColorSpaceDidChangeNotification = @"NSScreenColorSpaceDidChangeNotification";

@implementation NSScreen

- initWithFrame: (NSRect) frame visibleFrame: (NSRect) visibleFrame {
    _frame = frame;
    _visibleFrame = visibleFrame;
    return self;
}

- (void) dealloc {
    if (_edid)
        [_edid release];
    [super dealloc];
}

+ (NSScreen *) mainScreen {
    NSScreen *result = [[NSApp keyWindow] screen];

    if (result == nil) {
        NSArray *screens = [self screens];

        if ([screens count] > 0)
            result = [screens objectAtIndex: 0];
    }

    return result;
}

+ (NSArray *) screens {
    // NSDisplay lists every output, inactive ones included, because CoreGraphics
    // maps display IDs to positions in that list. Like macOS, only report the
    // displays that are actually in use.
    NSMutableArray *screens = [NSMutableArray array];

    for (NSScreen *screen in [[NSDisplay currentDisplay] screens]) {
        if (!NSIsEmptyRect([screen frame]))
            [screens addObject: screen];
    }

    return screens;
}

- (NSWindowDepth) depth {
    return _depth;
}

- (NSRect) frame {
    return _frame;
}

- (NSRect) visibleFrame {
    return _visibleFrame;
}

- (CGFloat) userSpaceScaleFactor {
    return 1.0;
}

- (CGFloat) backingScaleFactor {
    return 1.0;
}

- (NSString *) localizedName {
    return [NSString stringWithFormat: @"Display %u",
                                       (unsigned) _directDisplayID];
}

- (NSRect) convertRectToBacking: (NSRect) rect {
    return rect;
}

- (NSRect) convertRectFromBacking: (NSRect) rect {
    return rect;
}

- (NSRect) backingAlignedRect: (NSRect) rect options: (NSAlignmentOptions) options {
    return NSIntegralRect(rect);
}

- (CGFloat) maximumExtendedDynamicRangeColorComponentValue {
    return 1.0;
}

- (CGFloat) maximumPotentialExtendedDynamicRangeColorComponentValue {
    return 1.0;
}

- (CGFloat) maximumReferenceExtendedDynamicRangeColorComponentValue {
    return 0.0;
}

- (NSInteger) maximumFramesPerSecond {
    return 60;
}

- (NSColorSpace *) colorSpace {
    return [NSColorSpace sRGBColorSpace];
}

- (id) description {
    return [NSString stringWithFormat: @"< %@ - frame %@, visible %@ >",
                                       [super description],
                                       NSStringFromRect(_frame),
                                       NSStringFromRect(_visibleFrame)];
}

- (NSDictionary<NSDeviceDescriptionKey, id> *) deviceDescription {
    return @{
        @"NSScreenNumber" : [NSNumber numberWithUnsignedInt: _directDisplayID],
        NSDeviceSize : [NSValue valueWithSize: _frame.size],
        NSDeviceResolution : [NSValue valueWithSize: NSMakeSize(72, 72)],
        NSDeviceIsScreen : @"YES",
        NSDeviceColorSpaceName : NSCalibratedRGBColorSpace,
        NSDeviceBitsPerSample : [NSNumber numberWithInt: 8]
    };
}

@end

@implementation NSScreen (Darling)
- (NSData *) edid {
    return self->_edid;
}

- (void) setEdid: (NSData *) data {
    NSData *old = self->_edid;
    self->_edid = [data retain];
    [old release];
}

- (CGDirectDisplayID) cgDirectDisplayID {
    return self->_directDisplayID;
}

- (void) setCgDirectDisplayID: (CGDirectDisplayID) displayID {
    self->_directDisplayID = displayID;
}

@end
