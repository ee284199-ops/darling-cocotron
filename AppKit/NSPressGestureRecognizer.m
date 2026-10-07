/*
 This file is part of Darling.

 Copyright (C) 2021 Lubos Dolezel

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

#import <AppKit/NSGestureRecognizer_Private.h>
#import <AppKit/NSPressGestureRecognizer.h>
#import <AppKit/NSView.h>

@implementation NSPressGestureRecognizer

- (instancetype) init {
    self = [super init];

    _buttonMask = 0x1;
    _minimumPressDuration = 0.5;
    _allowableMovement = 10.0;
    _numberOfTouchesRequired = 1;

    return self;
}

- (instancetype) initWithTarget: (id) target action: (SEL) action {
    self = [super initWithTarget: target action: action];

    _buttonMask = 0x1;
    _minimumPressDuration = 0.5;
    _allowableMovement = 10.0;
    _numberOfTouchesRequired = 1;

    return self;
}

- initWithCoder: (NSCoder *) coder {
    self = [super initWithCoder: coder];

    if (_buttonMask == 0)
        _buttonMask = 0x1;
    if (_numberOfTouchesRequired == 0)
        _numberOfTouchesRequired = 1;

    return self;
}

- (void) encodeWithCoder: (NSCoder *) coder {
    [super encodeWithCoder: coder];
}

- (void) dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_pressDurationElapsed) object: nil];
    [super dealloc];
}

- (NSUInteger) buttonMask {
    return _buttonMask;
}

- (void) setButtonMask: (NSUInteger) buttonMask {
    _buttonMask = buttonMask;
}

- (NSTimeInterval) minimumPressDuration {
    return _minimumPressDuration;
}

- (void) setMinimumPressDuration: (NSTimeInterval) minimumPressDuration {
    _minimumPressDuration = minimumPressDuration;
}

- (CGFloat) allowableMovement {
    return _allowableMovement;
}

- (void) setAllowableMovement: (CGFloat) allowableMovement {
    _allowableMovement = allowableMovement;
}

- (NSUInteger) numberOfTouchesRequired {
    return _numberOfTouchesRequired;
}

- (void) setNumberOfTouchesRequired: (NSUInteger) numberOfTouchesRequired {
    _numberOfTouchesRequired = numberOfTouchesRequired;
}

- (void) mouseDown: (NSEvent *) event {
    _pressStartLocationInWindow = [event locationInWindow];
    _tracking = YES;

    [self performSelector: @selector(_pressDurationElapsed)
               withObject: nil
               afterDelay: _minimumPressDuration];
}

- (void) _pressDurationElapsed {
    if (!_tracking || [self state] != NSGestureRecognizerStatePossible)
        return;

    [self _recognizeWithState: NSGestureRecognizerStateBegan];
}

- (void) mouseDragged: (NSEvent *) event {
    NSPoint location = [event locationInWindow];
    CGFloat dx = location.x - _pressStartLocationInWindow.x;
    CGFloat dy = location.y - _pressStartLocationInWindow.y;

    if (!_tracking)
        return;

    if (sqrt(dx * dx + dy * dy) > _allowableMovement) {
        [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_pressDurationElapsed) object: nil];
        _tracking = NO;

        if ([self state] == NSGestureRecognizerStatePossible)
            [self _recognizeWithState: NSGestureRecognizerStateFailed];
        else
            [self _recognizeWithState:
                           NSGestureRecognizerStateCancelled];
    }
}

- (void) mouseUp: (NSEvent *) event {
    if (!_tracking)
        return;

    [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_pressDurationElapsed) object: nil];
    _tracking = NO;

    if ([self state] == NSGestureRecognizerStateBegan ||
        [self state] == NSGestureRecognizerStateChanged)
        [self _recognizeWithState: NSGestureRecognizerStateEnded];
    else if ([self state] == NSGestureRecognizerStatePossible)
        [self _recognizeWithState: NSGestureRecognizerStateFailed];
}

- (void) reset {
    [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_pressDurationElapsed) object: nil];
    [super reset];
    _tracking = NO;
    _pressStartLocationInWindow = NSZeroPoint;
}

@end
