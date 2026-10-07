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

#import <AppKit/NSApplication.h>
#import <AppKit/NSGestureRecognizer.h>
#import <AppKit/NSGestureRecognizer_Private.h>
#import <AppKit/NSMagnificationGestureRecognizer.h>
#import <AppKit/NSRotationGestureRecognizer.h>
#import <AppKit/NSView.h>
#include <math.h>

@implementation NSGestureRecognizer

- (instancetype) init {
    self = [super init];

    _enabled = YES;
    _state = NSGestureRecognizerStatePossible;

    return self;
}

- (instancetype) initWithTarget: (id) target action: (SEL) action {
    self = [self init];

    // Like on macOS, the target is not retained.
    _target = target;
    _action = action;

    return self;
}

- (void) dealloc {
    [_pressureConfiguration release];
    [super dealloc];
}

- initWithCoder: (NSCoder *) coder {
    self = [self init];

    _enabled = YES;

    return self;
}

- (void) encodeWithCoder: (NSCoder *) coder {
    // Nothing to encode yet.
}

- (id) target {
    return _target;
}

- (SEL) action {
    return _action;
}

- (void) setAction: (SEL) action {
    _action = action;
}

- (id) delegate {
    return _delegate;
}

- (void) setDelegate: (id) delegate {
    // Like on macOS, the delegate is not retained.
    _delegate = delegate;
}

- (BOOL) isEnabled {
    return _enabled;
}

- (void) setEnabled: (BOOL) enabled {
    _enabled = enabled;
    if (!enabled)
        [self reset];
}

- (NSGestureRecognizerState) state {
    return _state;
}

- (void) setState: (NSGestureRecognizerState) state {
    _state = state;
}

- (NSView *) view {
    return _view;
}

- (void) _setView: (NSView *) view {
    // The view is owned by the view hierarchy, it is not retained.
    _view = view;
}

- (NSUInteger) allowedTouchTypes {
    return _allowedTouchTypes;
}

- (void) setAllowedTouchTypes: (NSUInteger) allowedTouchTypes {
    _allowedTouchTypes = allowedTouchTypes;
}

- (BOOL) delaysPrimaryMouseButtonEvents {
    return _delaysPrimaryMouseButtonEvents;
}

- (void) setDelaysPrimaryMouseButtonEvents: (BOOL) delays {
    _delaysPrimaryMouseButtonEvents = delays;
}

- (BOOL) delaysSecondaryMouseButtonEvents {
    return _delaysSecondaryMouseButtonEvents;
}

- (void) setDelaysSecondaryMouseButtonEvents: (BOOL) delays {
    _delaysSecondaryMouseButtonEvents = delays;
}

- (BOOL) delaysOtherMouseButtonEvents {
    return _delaysOtherMouseButtonEvents;
}

- (void) setDelaysOtherMouseButtonEvents: (BOOL) delays {
    _delaysOtherMouseButtonEvents = delays;
}

- (BOOL) delaysKeyEvents {
    return _delaysKeyEvents;
}

- (void) setDelaysKeyEvents: (BOOL) delays {
    _delaysKeyEvents = delays;
}

- (BOOL) delaysMagnificationEvents {
    return _delaysMagnificationEvents;
}

- (void) setDelaysMagnificationEvents: (BOOL) delays {
    _delaysMagnificationEvents = delays;
}

- (BOOL) delaysRotationEvents {
    return _delaysRotationEvents;
}

- (void) setDelaysRotationEvents: (BOOL) delays {
    _delaysRotationEvents = delays;
}

- (NSPressureConfiguration *) pressureConfiguration {
    return _pressureConfiguration;
}

- (void) setPressureConfiguration:
        (NSPressureConfiguration *) pressureConfiguration
{
    [pressureConfiguration retain];
    [_pressureConfiguration release];
    _pressureConfiguration = pressureConfiguration;
}

- (NSPoint) locationInView: (NSView *) view {
    if (!_hasLastLocation)
        return NSMakePoint(0, 0);

    if (view == nil)
        return _locationInWindow;

    return [view convertPoint: _locationInWindow fromView: nil];
}

- (void) reset {
    [self setState: NSGestureRecognizerStatePossible];
    _hasLastLocation = NO;
}

- (void) _recognizeWithState: (NSGestureRecognizerState) state {
    if (_state == NSGestureRecognizerStatePossible) {
        if (_delegate != nil &&
            [_delegate respondsToSelector:
                            @selector(gestureRecognizerShouldBegin:)] &&
            ![_delegate gestureRecognizerShouldBegin: self]) {
            [self setState: NSGestureRecognizerStateFailed];
            [self reset];
            return;
        }
    }

    [self setState: state];

    // A failed gesture never reaches its target.
    if (_action != NULL && state != NSGestureRecognizerStateFailed)
        [NSApp sendAction: _action to: _target from: self];

    if (state == NSGestureRecognizerStateEnded ||
        state == NSGestureRecognizerStateCancelled ||
        state == NSGestureRecognizerStateFailed)
        [self reset];
}

- (void) _handleMouseEvent: (NSEvent *) event {
    if (!_enabled)
        return;

    _locationInWindow = [event locationInWindow];
    _hasLastLocation = YES;

    switch ([event type]) {
    case NSLeftMouseDown:
        [self mouseDown: event];
        break;
    case NSRightMouseDown:
        [self rightMouseDown: event];
        break;
    case NSOtherMouseDown:
        [self otherMouseDown: event];
        break;
    case NSLeftMouseDragged:
        [self mouseDragged: event];
        break;
    case NSRightMouseDragged:
        [self rightMouseDragged: event];
        break;
    case NSOtherMouseDragged:
        [self otherMouseDragged: event];
        break;
    case NSLeftMouseUp:
        [self mouseUp: event];
        break;
    case NSRightMouseUp:
        [self rightMouseUp: event];
        break;
    case NSOtherMouseUp:
        [self otherMouseUp: event];
        break;
    case NSMouseMoved:
        [self mouseMoved: event];
        break;
    default:
        break;
    }
}

- (void) mouseDown: (NSEvent *) event {
}

- (void) rightMouseDown: (NSEvent *) event {
}

- (void) otherMouseDown: (NSEvent *) event {
}

- (void) mouseDragged: (NSEvent *) event {
}

- (void) rightMouseDragged: (NSEvent *) event {
}

- (void) otherMouseDragged: (NSEvent *) event {
}

- (void) mouseUp: (NSEvent *) event {
}

- (void) rightMouseUp: (NSEvent *) event {
}

- (void) otherMouseUp: (NSEvent *) event {
}

- (void) mouseMoved: (NSEvent *) event {
}

- (void) keyDown: (NSEvent *) event {
}

- (void) keyUp: (NSEvent *) event {
}

- (void) flagsChanged: (NSEvent *) event {
}

- (void) tabletPoint: (NSEvent *) event {
}

- (void) magnifyWithEvent: (NSEvent *) event {
}

- (void) rotateWithEvent: (NSEvent *) event {
}

- (void) pressureChangeWithEvent: (NSEvent *) event {
}

@end

@implementation NSMagnificationGestureRecognizer {
    CGFloat _magnification;
}

- initWithCoder: (NSCoder *) coder {
    self = [super initWithCoder: coder];
    return self;
}

- (void) encodeWithCoder: (NSCoder *) coder {
    [super encodeWithCoder: coder];
}

- (CGFloat) magnification {
    return _magnification;
}

- (void) setMagnification: (CGFloat) magnification {
    _magnification = magnification;
}

- (void) magnifyWithEvent: (NSEvent *) event {
    // No trackpad magnification events arrive on this backend.
}

@end

@implementation NSRotationGestureRecognizer {
    CGFloat _rotation; // in radians
}

- initWithCoder: (NSCoder *) coder {
    self = [super initWithCoder: coder];
    return self;
}

- (void) encodeWithCoder: (NSCoder *) coder {
    [super encodeWithCoder: coder];
}

- (CGFloat) rotation {
    return _rotation;
}

- (void) setRotation: (CGFloat) rotation {
    _rotation = rotation;
}

- (CGFloat) rotationInDegrees {
    return _rotation * 180.0 / M_PI;
}

- (void) setRotationInDegrees: (CGFloat) rotationInDegrees {
    _rotation = rotationInDegrees * M_PI / 180.0;
}

- (void) rotateWithEvent: (NSEvent *) event {
    // No trackpad rotation events arrive on this backend.
}

@end
