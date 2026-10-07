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

#import <AppKit/AppKitExport.h>
#import <Foundation/Foundation.h>

@class NSWindow;

typedef NSString *NSWindowTabbingIdentifier;

// Darling has no window tabs: every window is alone in a group of its own,
// which the window creates when asked for its tabGroup.
@interface NSWindowTabGroup : NSObject {
@private
    NSWindow *_window;
    BOOL _overviewVisible;
}

// used by NSWindow
- initWithWindow: (NSWindow *) window;
- (void) _detachWindow;

- (NSWindowTabbingIdentifier) identifier;

- (NSArray<NSWindow *> *) windows;

- (NSWindow *) selectedWindow;
- (void) setSelectedWindow: (NSWindow *) selectedWindow;

- (void) addWindow: (NSWindow *) window;
- (void) insertWindow: (NSWindow *) window atIndex: (NSInteger) index;
- (void) removeWindow: (NSWindow *) window;

@property(getter=isOverviewVisible) BOOL overviewVisible;
@property(readonly, getter=isTabBarVisible) BOOL tabBarVisible;

@end
