#import <CoreGraphics/CGColorSpace.h>
#import <CoreGraphics/CGGradient.h>

// These accessors are private to CoreGraphics. They are used by the gradient
// drawing code in CGContext.m to build a CGFunction from a CGGradientRef.

CGColorSpaceRef CGGradientGetColorSpace(CGGradientRef self);
size_t CGGradientGetNumberOfComponents(CGGradientRef self);
size_t CGGradientGetNumberOfColorStops(CGGradientRef self);
const CGFloat *CGGradientGetColorComponents(CGGradientRef self);
const CGFloat *CGGradientGetLocations(CGGradientRef self);
