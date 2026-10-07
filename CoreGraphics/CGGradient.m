#import <CoreGraphics/CGColor.h>
#import <CoreGraphics/CGGradient.h>
#import "CGGradient_Private.h"
#import <Foundation/NSString.h>

// CGGradientRef is an opaque `struct CGGradient *`. The real object is the
// private Objective-C class below; CFRetain/CFRelease and the CGGradient*
// functions work on it because it is a Cocotron object.

@interface CGGradient_impl : NSObject {
  @public
    CGColorSpaceRef _colorSpace;
    size_t _numberOfComponents; // color components including alpha
    size_t _numberOfColorStops;
    CGFloat *_components; // _numberOfColorStops * _numberOfComponents values
    CGFloat *_locations;  // _numberOfColorStops values
}

- initWithColorSpace: (CGColorSpaceRef) colorSpace
         components: (const CGFloat *) components
          locations: (const CGFloat *) locations
              count: (size_t) count;

@end

@implementation CGGradient_impl

- initWithColorSpace: (CGColorSpaceRef) colorSpace
         components: (const CGFloat *) components
          locations: (const CGFloat *) locations
              count: (size_t) count
{
    size_t i;

    self = [super init];
    if (self == nil)
        return nil;

    _colorSpace = CGColorSpaceRetain(colorSpace);
    _numberOfComponents = CGColorSpaceGetNumberOfComponents(colorSpace) + 1;
    _numberOfColorStops = count;

    _components =
            NSZoneMalloc(NULL, sizeof(CGFloat) * count * _numberOfComponents);
    for (i = 0; i < count * _numberOfComponents; i++)
        _components[i] = components[i];

    _locations = NSZoneMalloc(NULL, sizeof(CGFloat) * count);
    if (locations != NULL) {
        for (i = 0; i < count; i++)
            _locations[i] = locations[i];
    } else if (count == 1) {
        _locations[0] = 0;
    } else {
        // Evenly spaced, 0 for the first color and 1 for the last one.
        for (i = 0; i < count; i++)
            _locations[i] = (CGFloat) i / (CGFloat) (count - 1);
    }

    return self;
}

- (void) dealloc {
    if (_colorSpace != NULL)
        CGColorSpaceRelease(_colorSpace);
    if (_components != NULL)
        NSZoneFree(NULL, _components);
    if (_locations != NULL)
        NSZoneFree(NULL, _locations);
    [super dealloc];
}

@end

CFTypeID CGGradientGetTypeID(void) {
    return (CFTypeID) [CGGradient_impl self];
}

CGGradientRef CGGradientCreateWithColorComponents(CGColorSpaceRef colorSpace,
                                                  const CGFloat components[],
                                                  const CGFloat locations[],
                                                  size_t count)
{
    if (colorSpace == NULL || components == NULL || count == 0)
        return NULL;

    return (CGGradientRef) (void *) [[CGGradient_impl alloc]
                 initWithColorSpace: colorSpace
                         components: components
                          locations: locations
                              count: count];
}

CGGradientRef CGGradientCreateWithColors(CGColorSpaceRef colorSpace,
                                         CFArrayRef colors,
                                         const CGFloat locations[])
{
    CFIndex i, count = (colors != NULL) ? CFArrayGetCount(colors) : 0;
    size_t numberOfComponents;
    CGFloat *components;
    CGGradientRef result;
    BOOL createdColorSpace = NO;

    if (count <= 0)
        return NULL;

    if (colorSpace == NULL) {
        // Like on macOS, a default device RGB color space is used.
        colorSpace = CGColorSpaceCreateDeviceRGB();
        createdColorSpace = YES;
    }
    if (colorSpace == NULL)
        return NULL;

    numberOfComponents = CGColorSpaceGetNumberOfComponents(colorSpace) + 1;
    components = NSZoneMalloc(
            NULL, sizeof(CGFloat) * (size_t) count * numberOfComponents);

    for (i = 0; i < count; i++) {
        CGColorRef color = (CGColorRef) CFArrayGetValueAtIndex(colors, i);
        size_t checkNumberOfComponents = CGColorGetNumberOfComponents(color);
        const CGFloat *copy = CGColorGetComponents(color);
        CGFloat *dest = components + (size_t) i * numberOfComponents;
        size_t j;

        if (checkNumberOfComponents == numberOfComponents) {
            for (j = 0; j < numberOfComponents; j++)
                dest[j] = copy[j];
        } else if (checkNumberOfComponents == 2 && numberOfComponents == 4) {
            // Gray plus alpha, expand to r = g = b = gray.
            dest[0] = copy[0];
            dest[1] = copy[0];
            dest[2] = copy[0];
            dest[3] = copy[1];
        } else if (checkNumberOfComponents == 4 && numberOfComponents == 2) {
            // RGB plus alpha, use luminance.
            dest[0] = 0.299 * copy[0] + 0.587 * copy[1] + 0.114 * copy[2];
            dest[1] = copy[3];
        } else {
            NSLog(@"CGGradientCreateWithColors, color spaces don't match, "
                  @"conversion not implemented, using black");
            for (j = 0; j < numberOfComponents; j++)
                dest[j] = 0;
            dest[numberOfComponents - 1] = CGColorGetAlpha(color);
        }
    }

    result = CGGradientCreateWithColorComponents(colorSpace, components,
                                                 locations, count);
    NSZoneFree(NULL, components);

    if (createdColorSpace)
        CGColorSpaceRelease(colorSpace);

    return result;
}

void CGGradientRelease(CGGradientRef self) {
    if (self == NULL)
        return;

    CFRelease(self);
}

CGGradientRef CGGradientRetain(CGGradientRef self) {
    if (self == NULL)
        return NULL;

    return (CGGradientRef) CFRetain(self);
}

CGColorSpaceRef CGGradientGetColorSpace(CGGradientRef self) {
    return ((CGGradient_impl *) (void *) self)->_colorSpace;
}

size_t CGGradientGetNumberOfComponents(CGGradientRef self) {
    return ((CGGradient_impl *) (void *) self)->_numberOfComponents;
}

size_t CGGradientGetNumberOfColorStops(CGGradientRef self) {
    return ((CGGradient_impl *) (void *) self)->_numberOfColorStops;
}

const CGFloat *CGGradientGetColorComponents(CGGradientRef self) {
    return ((CGGradient_impl *) (void *) self)->_components;
}

const CGFloat *CGGradientGetLocations(CGGradientRef self) {
    return ((CGGradient_impl *) (void *) self)->_locations;
}
