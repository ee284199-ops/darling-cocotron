/*
 This file is part of Darling.

 Copyright (C) 2025 Darling Developers

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

#import <AppKit/NSGestureRecognizer.h>

@interface NSGestureRecognizer (NSGestureRecognizerPrivate)

// Only for AppKit internals and recognizer subclasses.
- (void) setState: (NSGestureRecognizerState) state;

// Asks the delegate gestureRecognizerShouldBegin: when leaving the Possible
// state, transitions to the given state, sends the action to the target and
// resets back to Possible for Ended/Cancelled/Failed.
- (void) _recognizeWithState: (NSGestureRecognizerState) state;

- (void) _setView: (NSView *) view;

// Entry point used by NSWindow to feed mouse events to recognizers.
- (void) _handleMouseEvent: (NSEvent *) event;

@end
