/* Copyright (c) 2008 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import <CoreText/CTFontDescriptor.h>
#import "KTFontDescriptorInternal.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSNumber.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#include <stdlib.h>
#include <string.h>

const CFStringRef kCTFontURLAttribute = CFSTR("NSCTFontFileURLAttribute");
const CFStringRef kCTFontNameAttribute = CFSTR("NSFontNameAttribute");
const CFStringRef kCTFontDisplayNameAttribute = CFSTR("NSFontVisibleNameAttribute");
const CFStringRef kCTFontFamilyNameAttribute = CFSTR("NSFontFamilyAttribute");
const CFStringRef kCTFontStyleNameAttribute = CFSTR("NSFontFaceAttribute");
const CFStringRef kCTFontTraitsAttribute = CFSTR("NSCTFontTraitsAttribute");
const CFStringRef kCTFontVariationAttribute = CFSTR("NSCTFontVariationAttribute");
const CFStringRef kCTFontVariationAxesAttribute = CFSTR("NSCTFontVariationAxesAttribute");
const CFStringRef kCTFontSizeAttribute = CFSTR("NSFontSizeAttribute");
const CFStringRef kCTFontMatrixAttribute = CFSTR("NSCTFontMatrixAttribute");
const CFStringRef kCTFontCascadeListAttribute = CFSTR("NSCTFontCascadeListAttribute");
const CFStringRef kCTFontCharacterSetAttribute = CFSTR("NSCTFontCharacterSetAttribute");
const CFStringRef kCTFontLanguagesAttribute = CFSTR("NSCTFontLanguagesAttribute");
const CFStringRef kCTFontBaselineAdjustAttribute = CFSTR("NSCTFontBaselineAdjustAttribute");
const CFStringRef kCTFontMacintoshEncodingsAttribute = CFSTR("NSCTFontMacintoshEncodingsAttribute");
const CFStringRef kCTFontFeaturesAttribute = CFSTR("NSCTFontFeaturesAttribute");
const CFStringRef kCTFontFeatureSettingsAttribute = CFSTR("NSCTFontFeatureSettingsAttribute");
const CFStringRef kCTFontFixedAdvanceAttribute = CFSTR("NSCTFontFixedAdvanceAttribute");
const CFStringRef kCTFontOrientationAttribute = CFSTR("NSCTFontOrientationAttribute");
const CFStringRef kCTFontEnabledAttribute = CFSTR("NSCTFontEnabledAttribute");
const CFStringRef kCTFontFormatAttribute = CFSTR("NSCTFontFormatAttribute");
const CFStringRef kCTFontRegistrationScopeAttribute = CFSTR("NSCTFontRegistrationScopeAttribute");
const CFStringRef kCTFontPriorityAttribute = CFSTR("NSCTFontPriorityAttribute");

const CFStringRef kKTFontFileIndexAttribute = CFSTR("KTFontFileIndex");
const CFStringRef kKTFontDataAttribute = CFSTR("KTFontData");

// CTFontFormat values (subset of the public enum)
enum {
    kKTFontFormatUnrecognized = 0,
    kKTFontFormatTrueType = 3,
};

//
// the descriptor object
//

@implementation KTFontDescriptor

- initWithAttributes: (NSDictionary *)attributes {
    if (attributes == nil)
        attributes = [NSDictionary dictionary];
    _attributes = [attributes copy];
    return self;
}

- (void) dealloc {
    [_attributes release];
    [super dealloc];
}

- (NSDictionary *) attributes {
    return _attributes;
}

// what CFGetTypeID() asks Objective-C objects for
- (CFTypeID) _cfTypeID {
    return CTFontDescriptorGetTypeID();
}

@end

//
// helpers
//

NSLock *KTFontFontConfigLock(void) {
    static NSLock *lock = nil;

    if (lock == nil) {
        @synchronized ([KTFontDescriptor class]) {
            if (lock == nil)
                lock = [NSLock new];
        }
    }
    return lock;
}

static NSString *KTStringFromFcChar8(const FcChar8 *value) {
    if (value == NULL)
        return nil;
    return [NSString stringWithUTF8String: (const char *) value];
}

static const FcChar8 *KTFcChar8FromString(NSString *value) {
    if (value == nil)
        return NULL;
    return (const FcChar8 *) [value UTF8String];
}

static double KTClamp(double value, double min, double max) {
    if (value < min)
        return min;
    if (value > max)
        return max;
    return value;
}

// build the traits dictionary for a fontconfig pattern
static NSDictionary *KTFontTraitsFromFcPattern(FcPattern *pattern) {
    int weight = FC_WEIGHT_REGULAR;
    int slant = FC_SLANT_ROMAN;
    int width = FC_WIDTH_NORMAL;
    int spacing = FC_PROPORTIONAL;
    uint32_t symbolic = 0;

    FcPatternGetInteger(pattern, FC_WEIGHT, 0, &weight);
    FcPatternGetInteger(pattern, FC_SLANT, 0, &slant);
    FcPatternGetInteger(pattern, FC_WIDTH, 0, &width);
    FcPatternGetInteger(pattern, FC_SPACING, 0, &spacing);

    if (weight >= FC_WEIGHT_BOLD)
        symbolic |= kCTFontTraitBold;
    if (slant >= FC_SLANT_ITALIC)
        symbolic |= kCTFontTraitItalic;
    if (spacing == FC_MONO || spacing == FC_DUAL || spacing == FC_CHARCELL)
        symbolic |= kCTFontTraitMonoSpace;

    double weightTrait = ((double) weight / (double) FC_WEIGHT_REGULAR) - 1.0;
    double widthTrait = ((double) width / (double) FC_WIDTH_NORMAL) - 1.0;
    double slantTrait = slant >= FC_SLANT_ITALIC ? 1.0 : (slant >= FC_SLANT_OBLIQUE ? 0.5 : 0.0);

    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedInt: symbolic], (NSString *) kCTFontSymbolicTrait,
            [NSNumber numberWithDouble: KTClamp(weightTrait, -1, 1)], (NSString *) kCTFontWeightTrait,
            [NSNumber numberWithDouble: KTClamp(widthTrait, -1, 1)], (NSString *) kCTFontWidthTrait,
            [NSNumber numberWithDouble: slantTrait], (NSString *) kCTFontSlantTrait,
            nil];
}

// map a fontconfig pattern to a complete descriptor's attributes
static NSDictionary *KTFontAttributesFromFcPattern(FcPattern *pattern) {
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    FcChar8 *string = NULL;
    int integer = 0;

    if (FcPatternGetString(pattern, FC_FILE, 0, &string) == FcResultMatch) {
        NSString *path = KTStringFromFcChar8(string);
        NSURL *url = (path != nil) ? [NSURL fileURLWithPath: path] : nil;
        if (url != nil)
            [attributes setObject: url forKey: (NSString *) kCTFontURLAttribute];
    }

    if (FcPatternGetInteger(pattern, FC_INDEX, 0, &integer) == FcResultMatch)
        [attributes setObject: [NSNumber numberWithInt: integer] forKey: (NSString *) kKTFontFileIndexAttribute];

    if (FcPatternGetString(pattern, FC_FAMILY, 0, &string) == FcResultMatch)
        [attributes setObject: KTStringFromFcChar8(string) forKey: (NSString *) kCTFontFamilyNameAttribute];

    if (FcPatternGetString(pattern, FC_STYLE, 0, &string) == FcResultMatch)
        [attributes setObject: KTStringFromFcChar8(string) forKey: (NSString *) kCTFontStyleNameAttribute];

    if (FcPatternGetString(pattern, FC_POSTSCRIPT_NAME, 0, &string) == FcResultMatch)
        [attributes setObject: KTStringFromFcChar8(string) forKey: (NSString *) kCTFontNameAttribute];

    {
        BOOL haveDisplay = NO;

#ifdef FC_FULLNAME
        if (FcPatternGetString(pattern, FC_FULLNAME, 0, &string) == FcResultMatch) {
            [attributes setObject: KTStringFromFcChar8(string) forKey: (NSString *) kCTFontDisplayNameAttribute];
            haveDisplay = YES;
        }
#endif

        if (!haveDisplay) {
            NSString *family = [attributes objectForKey: (NSString *) kCTFontFamilyNameAttribute];
            NSString *style = [attributes objectForKey: (NSString *) kCTFontStyleNameAttribute];
            if (family != nil) {
                NSString *display = style != nil ? [NSString stringWithFormat: @"%@ %@", family, style] : family;
                [attributes setObject: display forKey: (NSString *) kCTFontDisplayNameAttribute];
            }
        }
    }

    [attributes setObject: KTFontTraitsFromFcPattern(pattern) forKey: (NSString *) kCTFontTraitsAttribute];
    [attributes setObject: [NSNumber numberWithInt: kKTFontFormatTrueType] forKey: (NSString *) kCTFontFormatAttribute];
    [attributes setObject: [NSNumber numberWithBool: YES] forKey: (NSString *) kCTFontEnabledAttribute];

    return attributes;
}


// build a fontconfig query pattern from a descriptor's attributes
static FcPattern *KTFontPatternFromAttributes(NSDictionary *attributes) {
    FcPattern *pattern = FcPatternCreate();
    NSDictionary *traits = [attributes objectForKey: (NSString *) kCTFontTraitsAttribute];
    NSString *family = nil;
    NSString *name = nil;

    family = [attributes objectForKey: (NSString *) kCTFontFamilyNameAttribute];
    name = [attributes objectForKey: (NSString *) kCTFontNameAttribute];

    if (family == nil && name != nil) {
        // a PostScript name such as Menlo-Bold: look for its family
        NSRange dash = [name rangeOfString: @"-"];
        family = dash.location != NSNotFound && dash.location > 0 ? [name substringToIndex: dash.location] : name;
    }

    if (family != nil) {
        FcPatternAddString(pattern, FC_FAMILY, KTFcChar8FromString(family));
        O2FontAddFallbackFamilies(pattern, family);
    }

    {
        NSString *style = [attributes objectForKey: (NSString *) kCTFontStyleNameAttribute];
        if (style != nil)
            FcPatternAddString(pattern, FC_STYLE, KTFcChar8FromString(style));
    }

    if (traits != nil) {
        NSNumber *symbolic = [traits objectForKey: (NSString *) kCTFontSymbolicTrait];
        if (symbolic != nil) {
            uint32_t value = [symbolic unsignedIntValue];
            if (value & kCTFontTraitBold)
                FcPatternAddInteger(pattern, FC_WEIGHT, FC_WEIGHT_BOLD);
            if (value & kCTFontTraitItalic)
                FcPatternAddInteger(pattern, FC_SLANT, FC_SLANT_ITALIC);
            if (value & kCTFontTraitMonoSpace)
                FcPatternAddInteger(pattern, FC_SPACING, FC_MONO);
        }

        NSNumber *weight = [traits objectForKey: (NSString *) kCTFontWeightTrait];
        if (weight != nil) {
            double normalized = [weight doubleValue];
            int fcWeight = (int) ((normalized + 1.0) * (double) FC_WEIGHT_REGULAR);
            FcPatternAddInteger(pattern, FC_WEIGHT, fcWeight);
        }

        NSNumber *slant = [traits objectForKey: (NSString *) kCTFontSlantTrait];
        if (slant != nil) {
            double normalized = [slant doubleValue];
            FcPatternAddInteger(pattern, FC_SLANT, normalized >= 0.5 ? FC_SLANT_ITALIC : FC_SLANT_ROMAN);
        }

        NSNumber *width = [traits objectForKey: (NSString *) kCTFontWidthTrait];
        if (width != nil) {
            double normalized = [width doubleValue];
            int fcWidth = (int) ((normalized + 1.0) * (double) FC_WIDTH_NORMAL);
            FcPatternAddInteger(pattern, FC_WIDTH, fcWidth);
        }
    }

    return pattern;
}

// caller must hold KTFontFontConfigLock()
static FcFontSet *KTFontMatchSet(NSDictionary *attributes) {
    FcConfig *config = O2FontSharedFontConfig();
    FcPattern *pattern = KTFontPatternFromAttributes(attributes);
    FcCharSet *charset = NULL;
    FcResult result;
    FcFontSet *set;

    FcConfigSubstitute(config, pattern, FcMatchPattern);
    FcDefaultSubstitute(pattern);

    set = FcFontSort(config, pattern, FcTrue, &charset, &result);

    FcPatternDestroy(pattern);
    if (charset != NULL)
        FcCharSetDestroy(charset);

    return set;
}

static BOOL KTFontAttributesSatisfyMandatory(NSDictionary *attributes, CFSetRef mandatoryAttributes) {
    CFIndex count;
    const void **values;
    CFIndex i;
    BOOL result = YES;

    if (mandatoryAttributes == NULL)
        return YES;

    count = CFSetGetCount(mandatoryAttributes);
    if (count == 0)
        return YES;

    values = (const void **) malloc(sizeof(const void *) * count);
    CFSetGetValues(mandatoryAttributes, values);

    for (i = 0; i < count; i++) {
        if ([attributes objectForKey: (NSString *) values[i]] == nil) {
            result = NO;
            break;
        }
    }

    free(values);
    return result;
}

//
// descriptors from fontconfig
//

CTFontDescriptorRef KTFontDescriptorCreateWithFcPattern(FcPattern *pattern) {
    NSDictionary *attributes = KTFontAttributesFromFcPattern(pattern);
    return (CTFontDescriptorRef) [[KTFontDescriptor alloc] initWithAttributes: attributes];
}

CFArrayRef KTFontDescriptorCreateFontDescriptorsForAllFonts(void) {
    NSMutableArray *result = [NSMutableArray array];
    FcConfig *config;
    const FcSetName sets[2] = { FcSetSystem, FcSetApplication };
    int i;
    int j;

    [KTFontFontConfigLock() lock];
    config = O2FontSharedFontConfig();

    for (i = 0; i < 2; i++) {
        FcFontSet *set = FcConfigGetFonts(config, sets[i]);
        if (set == NULL)
            continue;

        for (j = 0; j < set->nfont; j++) {
            NSDictionary *attributes = KTFontAttributesFromFcPattern(set->fonts[j]);
            KTFontDescriptor *descriptor = [[KTFontDescriptor alloc] initWithAttributes: attributes];
            [result addObject: descriptor];
            [descriptor release];
        }
    }

    [KTFontFontConfigLock() unlock];

    return (CFArrayRef) [result copy];
}

CTFontDescriptorRef KTFontDescriptorCreateWithFontName(CFStringRef name) {
    NSDictionary *attributes = [NSDictionary dictionaryWithObject: (NSString *) name
                                                           forKey: (NSString *) kCTFontNameAttribute];
    return (CTFontDescriptorRef) [[KTFontDescriptor alloc] initWithAttributes: attributes];
}

CFArrayRef KTFontDescriptorCreateMatchingFontDescriptors(CTFontDescriptorRef descriptor, CFSetRef mandatoryAttributes) {
    NSDictionary *attributes = [(KTFontDescriptor *) descriptor attributes];
    NSMutableArray *result = [NSMutableArray array];
    FcFontSet *set;

    [KTFontFontConfigLock() lock];
    set = KTFontMatchSet(attributes);

    if (set != NULL) {
        // FcFontSort lists every installed font, closest first. When a family was asked for, CoreText
        // only returns that family's faces, so keep the faces of the family fontconfig picked.
        BOOL familyQuery = [attributes objectForKey: (NSString *) kCTFontFamilyNameAttribute] != nil ||
                           [attributes objectForKey: (NSString *) kCTFontNameAttribute] != nil;
        FcChar8 *pickedFamily = NULL;
        int i;

        if (familyQuery && set->nfont > 0)
            FcPatternGetString(set->fonts[0], FC_FAMILY, 0, &pickedFamily);

        for (i = 0; i < set->nfont; i++) {
            NSDictionary *matchAttributes;

            if (pickedFamily != NULL) {
                FcChar8 *family = NULL;

                if (FcPatternGetString(set->fonts[i], FC_FAMILY, 0, &family) != FcResultMatch ||
                    strcmp((const char *) family, (const char *) pickedFamily) != 0)
                    continue;
            }

            matchAttributes = KTFontAttributesFromFcPattern(set->fonts[i]);

            if (!KTFontAttributesSatisfyMandatory(matchAttributes, mandatoryAttributes))
                continue;

            KTFontDescriptor *match = [[KTFontDescriptor alloc] initWithAttributes: matchAttributes];
            [result addObject: match];
            [match release];
        }

        FcFontSetDestroy(set);
    }
    [KTFontFontConfigLock() unlock];

    return (CFArrayRef) [result copy];
}

CTFontDescriptorRef KTFontDescriptorCreateMatchingFontDescriptor(CTFontDescriptorRef descriptor, CFSetRef mandatoryAttributes) {
    CFArrayRef matches = KTFontDescriptorCreateMatchingFontDescriptors(descriptor, mandatoryAttributes);
    CTFontDescriptorRef result = NULL;

    if (matches != NULL) {
        if (CFArrayGetCount(matches) > 0)
            result = (CTFontDescriptorRef) CFArrayGetValueAtIndex(matches, 0);
        if (result != NULL)
            CFRetain(result);
        CFRelease(matches);
    }

    return result;
}

CTFontDescriptorRef KTFontDescriptorCreateForCharacter(CTFontDescriptorRef descriptor, uint32_t character) {
    FcConfig *config;
    FcPattern *pattern = FcPatternCreate();
    FcCharSet *charset = FcCharSetCreate();
    FcPattern *match = NULL;
    FcResult result;
    CTFontDescriptorRef output = NULL;

    (void) descriptor;

    FcCharSetAddChar(charset, character);
    FcPatternAddCharSet(pattern, FC_CHARSET, charset);
    FcCharSetDestroy(charset);

    [KTFontFontConfigLock() lock];
    config = O2FontSharedFontConfig();

    FcConfigSubstitute(config, pattern, FcMatchPattern);
    FcDefaultSubstitute(pattern);
    match = FcFontMatch(config, pattern, &result);
    FcPatternDestroy(pattern);

    if (match != NULL) {
        output = KTFontDescriptorCreateWithFcPattern(match);
        FcPatternDestroy(match);
    }

    [KTFontFontConfigLock() unlock];

    return output;
}

CGFontRef KTFontDescriptorCopyGraphicsFont(CTFontDescriptorRef descriptor) {
    NSDictionary *attributes = [(KTFontDescriptor *) descriptor attributes];
    NSData *data = [attributes objectForKey: (NSString *) kKTFontDataAttribute];

    if (data != nil) {
        O2DataProviderRef provider = O2DataProviderCreateWithCFData((CFDataRef) data);
        CGFontRef font;

        if (provider == NULL)
            return NULL;
        font = (CGFontRef) O2FontCreateWithDataProvider(provider);
        O2DataProviderRelease(provider);
        return font;
    }

    {
        NSString *name = [attributes objectForKey: (NSString *) kCTFontNameAttribute];

        if (name != nil) {
            CGFontRef registered = KTFontManagerCopyGraphicsFontForName((CFStringRef) name);
            if (registered != NULL)
                return registered;
        }
    }

    {
        NSURL *url = [attributes objectForKey: (NSString *) kCTFontURLAttribute];

        if ([url isKindOfClass: [NSURL class]]) {
            NSString *path = [url path];
            NSNumber *indexNumber = [attributes objectForKey: (NSString *) kKTFontFileIndexAttribute];
            int index = indexNumber != nil ? [indexNumber intValue] : 0;
            FT_Face face;

            if (path == nil)
                return NULL;

            if (O2FontFreeTypeNewFace([path fileSystemRepresentation], index, &face) != 0)
                return NULL;

            return (CGFontRef) [[O2Font_freetype alloc] initWithFace: face];
        }
    }

    {
        CTFontDescriptorRef match = KTFontDescriptorCreateMatchingFontDescriptor(descriptor, NULL);
        CGFontRef font;

        if (match == NULL)
            return NULL;
        font = KTFontDescriptorCopyGraphicsFont(match);
        CFRelease(match);
        return font;
    }
}

//
// public API
//

CTFontDescriptorRef CTFontDescriptorCreateWithAttributes(CFDictionaryRef attributes) {
    return (CTFontDescriptorRef) [[KTFontDescriptor alloc] initWithAttributes: (NSDictionary *) attributes];
}

CTFontDescriptorRef CTFontDescriptorCreateWithNameAndSize(CFStringRef name, CGFloat size) {
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                (NSString *) name, (NSString *) kCTFontNameAttribute,
                                [NSNumber numberWithDouble: size], (NSString *) kCTFontSizeAttribute,
                                nil];
    return (CTFontDescriptorRef) [[KTFontDescriptor alloc] initWithAttributes: attributes];
}

CTFontDescriptorRef CTFontDescriptorCreateCopyWithAttributes(CTFontDescriptorRef original, CFDictionaryRef attributes) {
    NSMutableDictionary *merged = [[[(KTFontDescriptor *) original attributes] mutableCopy] autorelease];

    if (attributes != NULL)
        [merged addEntriesFromDictionary: (NSDictionary *) attributes];

    return (CTFontDescriptorRef) [[KTFontDescriptor alloc] initWithAttributes: merged];
}

CTFontDescriptorRef CTFontDescriptorCreateCopyWithFamily(CTFontDescriptorRef original, CFStringRef family) {
    NSMutableDictionary *merged = [[[(KTFontDescriptor *) original attributes] mutableCopy] autorelease];
    [merged setObject: (NSString *) family forKey: (NSString *) kCTFontFamilyNameAttribute];
    return (CTFontDescriptorRef) [[KTFontDescriptor alloc] initWithAttributes: merged];
}

CTFontDescriptorRef CTFontDescriptorCreateCopyWithSymbolicTraits(CTFontDescriptorRef original, CTFontSymbolicTraits value, CTFontSymbolicTraits mask) {
    NSMutableDictionary *merged = [[[(KTFontDescriptor *) original attributes] mutableCopy] autorelease];
    NSDictionary *traits = [merged objectForKey: (NSString *) kCTFontTraitsAttribute];
    NSMutableDictionary *newTraits = traits != nil ? [[traits mutableCopy] autorelease] : [NSMutableDictionary dictionary];
    uint32_t symbolic = [[newTraits objectForKey: (NSString *) kCTFontSymbolicTrait] unsignedIntValue];

    symbolic = (symbolic & ~(uint32_t) mask) | (value & mask);
    [newTraits setObject: [NSNumber numberWithUnsignedInt: symbolic] forKey: (NSString *) kCTFontSymbolicTrait];
    [merged setObject: newTraits forKey: (NSString *) kCTFontTraitsAttribute];

    return (CTFontDescriptorRef) [[KTFontDescriptor alloc] initWithAttributes: merged];
}

CTFontDescriptorRef CTFontDescriptorCreateCopyWithVariation(CTFontDescriptorRef original, CFNumberRef variationIdentifier, CGFloat variationValue) {
    NSMutableDictionary *merged = [[[(KTFontDescriptor *) original attributes] mutableCopy] autorelease];
    NSMutableDictionary *variation = [[[merged objectForKey: (NSString *) kCTFontVariationAttribute] mutableCopy] autorelease];

    if (variation == nil)
        variation = [NSMutableDictionary dictionary];

    [variation setObject: [NSNumber numberWithDouble: variationValue] forKey: (id) variationIdentifier];
    [merged setObject: variation forKey: (NSString *) kCTFontVariationAttribute];

    return (CTFontDescriptorRef) [[KTFontDescriptor alloc] initWithAttributes: merged];
}

CTFontDescriptorRef CTFontDescriptorCreateCopyWithFeature(CTFontDescriptorRef original, CFNumberRef featureTypeIdentifier, CFNumberRef featureSelectorIdentifier) {
    NSMutableDictionary *merged = [[[(KTFontDescriptor *) original attributes] mutableCopy] autorelease];
    NSMutableArray *features = [[[merged objectForKey: (NSString *) kCTFontFeatureSettingsAttribute] mutableCopy] autorelease];

    if (features == nil)
        features = [NSMutableArray array];

    [features addObject: [NSDictionary dictionaryWithObjectsAndKeys:
                          (id) featureTypeIdentifier, (NSString *) kCTFontFeatureTypeIdentifierKey,
                          (id) featureSelectorIdentifier, (NSString *) kCTFontFeatureSelectorIdentifierKey,
                          nil]];
    [merged setObject: features forKey: (NSString *) kCTFontFeatureSettingsAttribute];

    return (CTFontDescriptorRef) [[KTFontDescriptor alloc] initWithAttributes: merged];
}

CFDictionaryRef CTFontDescriptorCopyAttributes(CTFontDescriptorRef descriptor) {
    return (CFDictionaryRef) [[(KTFontDescriptor *) descriptor attributes] copy];
}

CFTypeRef CTFontDescriptorCopyAttribute(CTFontDescriptorRef descriptor, CFStringRef attribute) {
    id value = [[(KTFontDescriptor *) descriptor attributes] objectForKey: (NSString *) attribute];
    return (CFTypeRef) [value retain];
}

CFTypeRef CTFontDescriptorCopyLocalizedAttribute(CTFontDescriptorRef descriptor, CFStringRef attribute, CFStringRef *language) {
    if (language != NULL)
        *language = NULL;
    return CTFontDescriptorCopyAttribute(descriptor, attribute);
}

CFArrayRef CTFontDescriptorCreateMatchingFontDescriptors(CTFontDescriptorRef descriptor, CFSetRef mandatoryAttributes) {
    return KTFontDescriptorCreateMatchingFontDescriptors(descriptor, mandatoryAttributes);
}

CTFontDescriptorRef CTFontDescriptorCreateMatchingFontDescriptor(CTFontDescriptorRef descriptor, CFSetRef mandatoryAttributes) {
    return KTFontDescriptorCreateMatchingFontDescriptor(descriptor, mandatoryAttributes);
}

CFTypeID CTFontDescriptorGetTypeID(void) {
    return (CFTypeID) [KTFontDescriptor class];
}