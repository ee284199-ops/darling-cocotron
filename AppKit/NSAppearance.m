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

#import <AppKit/NSAppearance.h>

NSString *const NSAppearanceNameAqua = @"NSAppearanceNameAqua";
NSString *const NSAppearanceNameDarkAqua = @"NSAppearanceNameDarkAqua";
NSString *const NSAppearanceNameSystem = @"NSAppearanceNameSystem";
NSString *const NSAppearanceNameTouchBar = @"NSAppearanceNameTouchBar";
NSString *const NSAppearanceNameLightContent = @"NSAppearanceNameLightContent";
NSString *const NSAppearanceNameVibrantDark = @"NSAppearanceNameVibrantDark";
NSString *const NSAppearanceNameVibrantLight = @"NSAppearanceNameVibrantLight";
NSString *const NSAppearanceNameAccessibilityHighContrastAqua =
        @"NSAppearanceNameAccessibilityAqua";
NSString *const NSAppearanceNameAccessibilityHighContrastDarkAqua =
        @"NSAppearanceNameAccessibilityDarkAqua";
NSString *const NSAppearanceNameAccessibilityHighContrastSystem =
        @"NSAppearanceNameAccessibilityHighContrastSystem";
NSString *const NSAppearanceNameAccessibilityHighContrastVibrantLight =
        @"NSAppearanceNameAccessibilityVibrantLight";
NSString *const NSAppearanceNameAccessibilityHighContrastVibrantDark =
        @"NSAppearanceNameAccessibilityVibrantDark";

NSString *const NSAppearanceNameControlStrip =
        @"NSAppearanceNameControlStrip"; // Undocumented

static NSAppearance *_currentAppearance = nil;

@implementation NSAppearance

- (instancetype) initWithName: (NSAppearanceName) name {
    self = [super init];

    _name = [name copy];

    return self;
}

+ (NSAppearance *) appearanceNamed: (NSAppearanceName) name {
    if (name == nil)
        return nil;

    return [[[self alloc] initWithName: name] autorelease];
}

+ (NSAppearance *) currentAppearance {
    if (_currentAppearance == nil)
        _currentAppearance =
                [[self appearanceNamed: NSAppearanceNameAqua] retain];

    return _currentAppearance;
}

+ (void) setCurrentAppearance: (NSAppearance *) appearance {
    [appearance retain];
    [_currentAppearance release];
    _currentAppearance = appearance;
}

+ (NSAppearance *) currentDrawingAppearance {
    return [self currentAppearance];
}

- (NSAppearanceName) name {
    return _name;
}

- (NSAppearanceName) bestMatchFromAppearancesWithNames:
        (NSArray<NSAppearanceName> *) names
{
    if ([names containsObject: _name])
        return _name;

    if ([_name rangeOfString: @"Dark"].location != NSNotFound &&
        [names containsObject: NSAppearanceNameDarkAqua])
        return NSAppearanceNameDarkAqua;

    if ([names containsObject: NSAppearanceNameAqua])
        return NSAppearanceNameAqua;

    return nil;
}

- (BOOL) allowsVibrancy {
    return NO;
}

- (void) dealloc {
    [_name release];
    [super dealloc];
}

- (void) encodeWithCoder: (NSCoder *) aCoder {
    if ([aCoder allowsKeyedCoding])
        [aCoder encodeObject: _name forKey: @"NSAppearanceName"];
}

- (id) initWithCoder: (NSCoder *) aDecoder {
    if ([aDecoder allowsKeyedCoding])
        _name = [[aDecoder decodeObjectForKey: @"NSAppearanceName"] copy];

    return self;
}

+ (BOOL) supportsSecureCoding
{
    return YES;
}

@end
