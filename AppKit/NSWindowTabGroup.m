/* Copyright (c) 2026 Darling Developers

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

#import <AppKit/NSWindow.h>
#import <AppKit/NSWindowTabGroup.h>

@implementation NSWindowTabGroup

// The group is owned by its window, so the window is not retained.
- (instancetype) initWithWindow: (NSWindow *) window {
    self = [super init];

    _window = window;

    return self;
}

- (NSWindowTabbingIdentifier) identifier {
    return [_window tabbingIdentifier];
}

- (NSArray<NSWindow *> *) windows {
    if (_window == nil)
        return [NSArray array];

    return [NSArray arrayWithObject: _window];
}

- (NSWindow *) selectedWindow {
    return _window;
}

- (void) setSelectedWindow: (NSWindow *) selectedWindow {
    if (selectedWindow == _window)
        [_window makeKeyAndOrderFront: nil];
}

- (void) addWindow: (NSWindow *) window {
    [window orderFront: nil];
}

- (void) insertWindow: (NSWindow *) window atIndex: (NSInteger) index {
    [window orderFront: nil];
}

- (void) removeWindow: (NSWindow *) window {
    // There is no tab UI, every window is alone in its own group.
}

- (BOOL) isOverviewVisible {
    return _overviewVisible;
}

- (void) setOverviewVisible: (BOOL) overviewVisible {
    _overviewVisible = overviewVisible;
}

- (BOOL) isTabBarVisible {
    return NO;
}

// called by the window when it goes away, in case someone else keeps the group
- (void) _detachWindow {
    _window = nil;
}

@end
