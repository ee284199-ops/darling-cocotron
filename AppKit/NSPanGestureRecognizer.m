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
#import <AppKit/NSPanGestureRecognizer.h>
#import <AppKit/NSView.h>

@implementation NSPanGestureRecognizer

- (instancetype) init {
    self = [super init];

    _buttonMask = 0x1;
    _numberOfTouchesRequired = 1;

    return self;
}

- (instancetype) initWithTarget: (id) target action: (SEL) action {
    self = [super initWithTarget: target action: action];

    _buttonMask = 0x1;
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

- (NSUInteger) buttonMask {
    return _buttonMask;
}

- (void) setButtonMask: (NSUInteger) buttonMask {
    _buttonMask = buttonMask;
}

- (NSUInteger) numberOfTouchesRequired {
    return _numberOfTouchesRequired;
}

- (void) setNumberOfTouchesRequired: (NSUInteger) numberOfTouchesRequired {
    _numberOfTouchesRequired = numberOfTouchesRequired;
}

- (void) mouseDown: (NSEvent *) event {
    _panStartLocationInWindow = [event locationInWindow];
    _translationOffset = NSMakePoint(0, 0);
    _tracking = YES;
}

- (void) mouseDragged: (NSEvent *) event {
    if (!_tracking)
        return;

    if ([self state] == NSGestureRecognizerStatePossible) {
        [self _recognizeWithState: NSGestureRecognizerStateBegan];

        if ([self state] != NSGestureRecognizerStateBegan) {
            // The delegate refused the gesture.
            _tracking = NO;
        }
    } else if ([self state] == NSGestureRecognizerStateBegan ||
               [self state] == NSGestureRecognizerStateChanged) {
        [self _recognizeWithState: NSGestureRecognizerStateChanged];
    }
}

- (void) mouseUp: (NSEvent *) event {
    if (!_tracking)
        return;

    _tracking = NO;

    if ([self state] == NSGestureRecognizerStateBegan ||
        [self state] == NSGestureRecognizerStateChanged)
        [self _recognizeWithState: NSGestureRecognizerStateEnded];
    else
        [self reset];
}

- (void) reset {
    [super reset];
    _tracking = NO;
    _panStartLocationInWindow = NSZeroPoint;
    _translationOffset = NSZeroPoint;
}

- (NSPoint) translationInView: (NSView *) view {
    NSPoint current;
    NSPoint start;

    if (!_hasLastLocation)
        return NSMakePoint(0, 0);

    current = _locationInWindow;
    start = _panStartLocationInWindow;

    if (view != nil) {
        current = [view convertPoint: current fromView: nil];
        start = [view convertPoint: start fromView: nil];
    }

    return NSMakePoint(current.x - start.x + _translationOffset.x,
                       current.y - start.y + _translationOffset.y);
}

- (void) setTranslation: (NSPoint) translation inView: (NSView *) view {
    NSPoint current = [self translationInView: view];

    _translationOffset = NSMakePoint(translation.x - current.x +
                                             _translationOffset.x,
                             translation.y - current.y +
                                     _translationOffset.y);
}

- (NSPoint) velocityInView: (NSView *) view {
    // Velocity tracking is not implemented.
    return NSMakePoint(0, 0);
}

@end
