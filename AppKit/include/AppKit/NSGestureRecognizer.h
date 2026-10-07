/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <AppKit/AppKitExport.h>
#import <AppKit/NSEvent.h>
#import <Foundation/Foundation.h>

@class NSView, NSPressureConfiguration, NSGestureRecognizer;

typedef NS_ENUM(NSInteger, NSGestureRecognizerState) {
    NSGestureRecognizerStatePossible = 0,
    NSGestureRecognizerStateBegan = 1,
    NSGestureRecognizerStateChanged = 2,
    NSGestureRecognizerStateEnded = 3,
    NSGestureRecognizerStateCancelled = 4,
    NSGestureRecognizerStateFailed = 5,

    NSGestureRecognizerStateRecognized = NSGestureRecognizerStateEnded
};

@protocol NSGestureRecognizerDelegate <NSObject>
- (BOOL) gestureRecognizerShouldBegin: (NSGestureRecognizer *) gestureRecognizer;
@end

@interface NSGestureRecognizer : NSObject <NSCoding> {
    id _target;
    SEL _action;
    id _delegate;
    NSView *_view;
    NSPressureConfiguration *_pressureConfiguration;

    BOOL _enabled;
    BOOL _delaysPrimaryMouseButtonEvents;
    BOOL _delaysSecondaryMouseButtonEvents;
    BOOL _delaysOtherMouseButtonEvents;
    BOOL _delaysKeyEvents;
    BOOL _delaysMagnificationEvents;
    BOOL _delaysRotationEvents;

    NSUInteger _allowedTouchTypes;
    NSGestureRecognizerState _state;
    NSPoint _locationInWindow;
    BOOL _hasLastLocation;
}

- initWithTarget: (id) target action: (SEL) action;

- (id) target;
- (SEL) action;
- (void) setAction: (SEL) action;

- (id) delegate;
- (void) setDelegate: (id) delegate;

@property(getter=isEnabled) BOOL enabled;
- (BOOL) isEnabled;
- (void) setEnabled: (BOOL) enabled;

@property(readonly) NSGestureRecognizerState state;
- (NSGestureRecognizerState) state;

@property(readonly) NSView *view;
- (NSView *) view;

@property NSUInteger allowedTouchTypes;
- (NSUInteger) allowedTouchTypes;
- (void) setAllowedTouchTypes: (NSUInteger) allowedTouchTypes;

@property BOOL delaysPrimaryMouseButtonEvents;
- (BOOL) delaysPrimaryMouseButtonEvents;
- (void) setDelaysPrimaryMouseButtonEvents: (BOOL) delays;

@property BOOL delaysSecondaryMouseButtonEvents;
- (BOOL) delaysSecondaryMouseButtonEvents;
- (void) setDelaysSecondaryMouseButtonEvents: (BOOL) delays;

@property BOOL delaysOtherMouseButtonEvents;
- (BOOL) delaysOtherMouseButtonEvents;
- (void) setDelaysOtherMouseButtonEvents: (BOOL) delays;

@property BOOL delaysKeyEvents;
- (BOOL) delaysKeyEvents;
- (void) setDelaysKeyEvents: (BOOL) delays;

@property BOOL delaysMagnificationEvents;
- (BOOL) delaysMagnificationEvents;
- (void) setDelaysMagnificationEvents: (BOOL) delays;

@property BOOL delaysRotationEvents;
- (BOOL) delaysRotationEvents;
- (void) setDelaysRotationEvents: (BOOL) delays;

@property(copy) NSPressureConfiguration *pressureConfiguration;
- (NSPressureConfiguration *) pressureConfiguration;
- (void) setPressureConfiguration: (NSPressureConfiguration *) pressureConfiguration;

- (NSPoint) locationInView: (NSView *) view;

- (void) reset;

- (void) mouseDown: (NSEvent *) event;
- (void) rightMouseDown: (NSEvent *) event;
- (void) otherMouseDown: (NSEvent *) event;
- (void) mouseDragged: (NSEvent *) event;
- (void) rightMouseDragged: (NSEvent *) event;
- (void) otherMouseDragged: (NSEvent *) event;
- (void) mouseUp: (NSEvent *) event;
- (void) rightMouseUp: (NSEvent *) event;
- (void) otherMouseUp: (NSEvent *) event;
- (void) mouseMoved: (NSEvent *) event;

- (void) keyDown: (NSEvent *) event;
- (void) keyUp: (NSEvent *) event;
- (void) flagsChanged: (NSEvent *) event;

- (void) tabletPoint: (NSEvent *) event;
- (void) magnifyWithEvent: (NSEvent *) event;
- (void) rotateWithEvent: (NSEvent *) event;
- (void) pressureChangeWithEvent: (NSEvent *) event;

@end
