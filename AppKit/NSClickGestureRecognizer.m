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

#import <AppKit/NSClickGestureRecognizer.h>
#import <AppKit/NSGestureRecognizer_Private.h>
#import <AppKit/NSView.h>

@implementation NSClickGestureRecognizer

- (instancetype) init {
    self = [super init];

    _buttonMask = 0x1;
    _numberOfClicksRequired = 1;
    _numberOfTouchesRequired = 1;

    return self;
}

- (instancetype) initWithTarget: (id) target action: (SEL) action {
    self = [super initWithTarget: target action: action];

    _buttonMask = 0x1;
    _numberOfClicksRequired = 1;
    _numberOfTouchesRequired = 1;

    return self;
}

- initWithCoder: (NSCoder *) coder {
    self = [super initWithCoder: coder];

    if (_buttonMask == 0)
        _buttonMask = 0x1;
    if (_numberOfClicksRequired == 0)
        _numberOfClicksRequired = 1;
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

- (NSUInteger) numberOfClicksRequired {
    return _numberOfClicksRequired;
}

- (void) setNumberOfClicksRequired: (NSUInteger) numberOfClicksRequired {
    _numberOfClicksRequired = numberOfClicksRequired;
}

- (NSUInteger) numberOfTouchesRequired {
    return _numberOfTouchesRequired;
}

- (void) setNumberOfTouchesRequired: (NSUInteger) numberOfTouchesRequired {
    _numberOfTouchesRequired = numberOfTouchesRequired;
}

- (void) mouseUp: (NSEvent *) event {
    NSUInteger buttonMask;
    NSView *view;
    NSPoint location;

    switch ([event type]) {
    case NSLeftMouseUp:
        buttonMask = 0x1;
        break;
    case NSRightMouseUp:
        buttonMask = 0x2;
        break;
    default:
        buttonMask = 1 << [event buttonNumber];
        break;
    }

    if (!(_buttonMask & buttonMask)) {
        [self reset];
        return;
    }

    if ([event clickCount] < _numberOfClicksRequired)
        return;

    view = [self view];
    if (view != nil) {
        location = [view convertPoint: [event locationInWindow]
                             fromView: nil];
        if (!NSPointInRect(location, [view bounds])) {
            [self reset];
            return;
        }
    }

    [self _recognizeWithState: NSGestureRecognizerStateEnded];
}

- (void) rightMouseUp: (NSEvent *) event {
    [self mouseUp: event];
}

- (void) otherMouseUp: (NSEvent *) event {
    [self mouseUp: event];
}

@end
