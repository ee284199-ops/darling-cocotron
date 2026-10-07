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

#import <AppKit/AppKitExport.h>
#import <Foundation/Foundation.h>
#import <AppKit/NSGestureRecognizer.h>

@interface NSPressGestureRecognizer : NSGestureRecognizer <NSCoding> {
    NSUInteger _buttonMask;
    NSTimeInterval _minimumPressDuration;
    CGFloat _allowableMovement;
    NSUInteger _numberOfTouchesRequired;
    NSPoint _pressStartLocationInWindow;
    BOOL _tracking;
}

@property NSUInteger buttonMask;
- (NSUInteger) buttonMask;
- (void) setButtonMask: (NSUInteger) buttonMask;

@property NSTimeInterval minimumPressDuration;
- (NSTimeInterval) minimumPressDuration;
- (void) setMinimumPressDuration: (NSTimeInterval) minimumPressDuration;

@property CGFloat allowableMovement;
- (CGFloat) allowableMovement;
- (void) setAllowableMovement: (CGFloat) allowableMovement;

@property NSUInteger numberOfTouchesRequired;
- (NSUInteger) numberOfTouchesRequired;
- (void) setNumberOfTouchesRequired: (NSUInteger) numberOfTouchesRequired;

@end
