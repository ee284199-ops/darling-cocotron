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

#import <CoreText/CTFont.h>
#import <CoreText/CoreText.h>
#import <CoreText/KTFont.h>
#import "KTFontDescriptorInternal.h"

#import <CoreGraphics/CGContext.h>
#import <CoreGraphics/CGPath.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNumber.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <Onyx2D/O2Font_freetype.h>

#include <stdlib.h>

#import FT_TRUETYPE_TABLES_H

const CFStringRef kCTFontCopyrightNameKey = CFSTR("CTFontCopyrightName");
const CFStringRef kCTFontFamilyNameKey = CFSTR("CTFontFamilyName");
const CFStringRef kCTFontSubFamilyNameKey = CFSTR("CTFontSubFamilyName");
const CFStringRef kCTFontStyleNameKey = CFSTR("CTFontSubFamilyName");
const CFStringRef kCTFontUniqueNameKey = CFSTR("CTFontUniqueName");
const CFStringRef kCTFontFullNameKey = CFSTR("CTFontFullName");
const CFStringRef kCTFontVersionNameKey = CFSTR("CTFontVersionName");
const CFStringRef kCTFontPostScriptNameKey = CFSTR("CTFontPostScriptName");
const CFStringRef kCTFontTrademarkNameKey = CFSTR("CTFontTrademarkName");
const CFStringRef kCTFontManufacturerNameKey = CFSTR("CTFontManufacturerName");
const CFStringRef kCTFontDesignerNameKey = CFSTR("CTFontDesignerName");
const CFStringRef kCTFontDescriptionNameKey = CFSTR("CTFontDescriptionName");
const CFStringRef kCTFontVendorURLNameKey = CFSTR("CTFontVendorURLName");
const CFStringRef kCTFontDesignerURLNameKey = CFSTR("CTFontDesignerURLName");
const CFStringRef kCTFontLicenseNameKey = CFSTR("CTFontLicenseNameName");
const CFStringRef kCTFontLicenseURLNameKey = CFSTR("CTFontLicenseURLName");
const CFStringRef kCTFontSampleTextNameKey = CFSTR("CTFontSampleTextName");
const CFStringRef kCTFontPostScriptCIDNameKey = CFSTR("CTFontPostScriptCIDName");

const CFStringRef kCTFontVariationAxisIdentifierKey = CFSTR("NSCTVariationAxisIdentifier");
const CFStringRef kCTFontVariationAxisMinimumValueKey = CFSTR("NSCTVariationAxisMinimumValue");
const CFStringRef kCTFontVariationAxisMaximumValueKey = CFSTR("NSCTVariationAxisMaximumValue");
const CFStringRef kCTFontVariationAxisDefaultValueKey = CFSTR("NSCTVariationAxisDefaultValue");
const CFStringRef kCTFontVariationAxisNameKey = CFSTR("NSCTVariationAxisName");
const CFStringRef kCTFontVariationAxisHiddenKey = CFSTR("NSCTVariationAxisHidden");

const CFStringRef kCTFontFeatureTypeIdentifierKey = CFSTR("CTFeatureTypeIdentifier");
const CFStringRef kCTFontFeatureTypeNameKey = CFSTR("CTFeatureTypeName");
const CFStringRef kCTFontFeatureTypeExclusiveKey = CFSTR("CTFeatureTypeExclusive");
const CFStringRef kCTFontFeatureTypeSelectorsKey = CFSTR("CTFeatureTypeSelectors");
const CFStringRef kCTFontFeatureSelectorIdentifierKey = CFSTR("CTFeatureSelectorIdentifier");
const CFStringRef kCTFontFeatureSelectorNameKey = CFSTR("CTFeatureSelectorName");
const CFStringRef kCTFontFeatureSelectorDefaultKey = CFSTR("CTFeatureSelectorDefault");
const CFStringRef kCTFontFeatureSelectorSettingKey = CFSTR("CTFeatureSelectorSetting");
const CFStringRef kCTFontFeatureSampleTextKey = CFSTR("CTFeatureSampleText");
const CFStringRef kCTFontFeatureTooltipTextKey = CFSTR("CTFeatureTooltipText");

enum {
    kKTFontFormatTrueType = 3,
};

//
// helpers
//

static FT_Face KTFontFace(CTFontRef font) {
    KTFont *ktf = (KTFont *) font;
    CGFontRef cgFont;
    O2Font_freetype *ftFont;

    if (ktf == nil)
        return NULL;

    cgFont = [ktf font];
    if (cgFont == NULL)
        return NULL;

    ftFont = (O2Font_freetype *) (O2FontRef) cgFont;
    if (![ftFont isKindOfClass: [O2Font_freetype class]])
        return NULL;

    return [ftFont face];
}

static NSDictionary *KTFontDescriptorAttributes(CTFontRef font) {
    KTFont *ktf = (KTFont *) font;

    if ([ktf descriptor] == NULL)
        return nil;

    return [(KTFontDescriptor *) [ktf descriptor] attributes];
}

static id KTFontDescriptorAttribute(CTFontRef font, CFStringRef key) {
    return [KTFontDescriptorAttributes(font) objectForKey: (NSString *) key];
}

// FreeType only flags fonts whose glyphs all have one width. fontconfig also calls "dual width"
// fonts monospace (Noto Sans Mono CJK: fixed-width Latin, double-width CJK), and so do terminals.
static BOOL KTFaceHasFixedWidthLatin(FT_Face face) {
    const FT_ULong probes[] = { 'i', 'W', 'm', '1', '.' };
    FT_Pos width = 0;
    size_t i;

    for (i = 0; i < sizeof(probes) / sizeof(probes[0]); i++) {
        FT_UInt glyph = FT_Get_Char_Index(face, probes[i]);

        if (glyph == 0 || FT_Load_Glyph(face, glyph, FT_LOAD_NO_SCALE) != 0)
            return NO;
        if (i == 0)
            width = face->glyph->advance.x;
        else if (face->glyph->advance.x != width)
            return NO;
    }
    return width > 0;
}

static NSDictionary *KTFontTraitsForFont(CTFontRef font) {
    NSDictionary *traits = KTFontDescriptorAttribute(font, kCTFontTraitsAttribute);

    if (traits != nil)
        return traits;

    {
        FT_Face face = KTFontFace(font);
        uint32_t symbolic = 0;

        if (face != NULL) {
            if (face->style_flags & FT_STYLE_FLAG_BOLD)
                symbolic |= kCTFontTraitBold;
            if (face->style_flags & FT_STYLE_FLAG_ITALIC)
                symbolic |= kCTFontTraitItalic;
            if ((face->face_flags & FT_FACE_FLAG_FIXED_WIDTH) || KTFaceHasFixedWidthLatin(face))
                symbolic |= kCTFontTraitMonoSpace;
        }

        return [NSDictionary dictionaryWithObjectsAndKeys:
                [NSNumber numberWithUnsignedInt: symbolic], (NSString *) kCTFontSymbolicTrait,
                [NSNumber numberWithDouble: 0.0], (NSString *) kCTFontWeightTrait,
                [NSNumber numberWithDouble: 0.0], (NSString *) kCTFontWidthTrait,
                [NSNumber numberWithDouble: 0.0], (NSString *) kCTFontSlantTrait,
                nil];
    }
}

// merge a base attribute dictionary with names derived from the FreeType face
static NSDictionary *KTFontAttributesWithFaceNames(CTFontRef font, NSDictionary *base) {
    FT_Face face = KTFontFace(font);
    NSMutableDictionary *attributes = base != nil ? [[base mutableCopy] autorelease] : [NSMutableDictionary dictionary];

    if (face != NULL) {
        if ([attributes objectForKey: (NSString *) kCTFontFamilyNameAttribute] == nil && face->family_name != NULL)
            [attributes setObject: [NSString stringWithUTF8String: face->family_name]
                           forKey: (NSString *) kCTFontFamilyNameAttribute];
        if ([attributes objectForKey: (NSString *) kCTFontStyleNameAttribute] == nil && face->style_name != NULL)
            [attributes setObject: [NSString stringWithUTF8String: face->style_name]
                           forKey: (NSString *) kCTFontStyleNameAttribute];
        if ([attributes objectForKey: (NSString *) kCTFontNameAttribute] == nil) {
            const char *postScriptName = FT_Get_Postscript_Name(face);
            if (postScriptName != NULL)
                [attributes setObject: [NSString stringWithUTF8String: postScriptName]
                               forKey: (NSString *) kCTFontNameAttribute];
        }
        if ([attributes objectForKey: (NSString *) kCTFontDisplayNameAttribute] == nil) {
            NSString *family = [attributes objectForKey: (NSString *) kCTFontFamilyNameAttribute];
            NSString *style = [attributes objectForKey: (NSString *) kCTFontStyleNameAttribute];
            if (family != nil)
                [attributes setObject: (style != nil ? [NSString stringWithFormat: @"%@ %@", family, style] : family)
                               forKey: (NSString *) kCTFontDisplayNameAttribute];
        }
    }

    if ([attributes objectForKey: (NSString *) kCTFontTraitsAttribute] == nil)
        [attributes setObject: KTFontTraitsForFont(font) forKey: (NSString *) kCTFontTraitsAttribute];
    if ([attributes objectForKey: (NSString *) kCTFontFormatAttribute] == nil)
        [attributes setObject: [NSNumber numberWithInt: kKTFontFormatTrueType] forKey: (NSString *) kCTFontFormatAttribute];
    if ([attributes objectForKey: (NSString *) kCTFontEnabledAttribute] == nil)
        [attributes setObject: [NSNumber numberWithBool: YES] forKey: (NSString *) kCTFontEnabledAttribute];

    return attributes;
}

static CTFontRef KTFontCreateWithDescriptorAndMatrix(CTFontDescriptorRef descriptor, CGFloat size, const CGAffineTransform *matrix) {
    NSDictionary *attributes;
    CGAffineTransform transform = matrix != NULL ? *matrix : CGAffineTransformIdentity;
    CGFontRef cgFont;
    KTFont *font;

    if (descriptor == NULL)
        return NULL;

    attributes = [(KTFontDescriptor *) descriptor attributes];

    if (size == 0) {
        NSNumber *sizeNumber = [attributes objectForKey: (NSString *) kCTFontSizeAttribute];
        size = sizeNumber != nil ? [sizeNumber doubleValue] : 12.0;
    }
    if (size <= 0)
        size = 12.0;

    cgFont = KTFontDescriptorCopyGraphicsFont(descriptor);
    if (cgFont == NULL)
        return NULL;

    font = [[KTFont alloc] initWithFont: cgFont descriptor: descriptor size: size matrix: &transform];
    CGFontRelease(cgFont);

    return (CTFontRef) font;
}

//
// creation
//

CTFontRef CTFontCreateWithName(CFStringRef name, CGFloat size, const CGAffineTransform *matrix) {
    return CTFontCreateWithNameAndOptions(name, size, matrix, kCTFontOptionsDefault);
}

CTFontRef CTFontCreateWithNameAndOptions(CFStringRef name, CGFloat size,
                                         const CGAffineTransform *matrix,
                                         CTFontOptions options)
{
    CTFontDescriptorRef descriptor;
    CTFontRef font;

    (void) options;

    if (name == NULL)
        return NULL;

    if (size == 0)
        size = 12.0;

    descriptor = KTFontDescriptorCreateWithFontName(name);
    if (descriptor == NULL)
        return NULL;

    font = CTFontCreateWithFontDescriptor(descriptor, size, matrix);
    CFRelease(descriptor);
    return font;
}

CTFontRef CTFontCreateWithFontDescriptor(CTFontDescriptorRef descriptor, CGFloat size,
                                         const CGAffineTransform *matrix)
{
    return CTFontCreateWithFontDescriptorAndOptions(descriptor, size, matrix, kCTFontOptionsDefault);
}

CTFontRef CTFontCreateWithFontDescriptorAndOptions(CTFontDescriptorRef descriptor, CGFloat size,
                                                   const CGAffineTransform *matrix,
                                                   CTFontOptions options)
{
    (void) options;
    return KTFontCreateWithDescriptorAndMatrix(descriptor, size, matrix);
}

CTFontRef CTFontCreateUIFontForLanguage(CTFontUIFontType uiFontType,
                                        CGFloat size, CFStringRef language)
{
    return (CTFontRef)[[KTFont alloc] initWithUIFontType: uiFontType
                                         size: size
                                     language: (NSString *)language];
}

CTFontRef CTFontCreateCopyWithAttributes(CTFontRef font, CGFloat size,
                                         const CGAffineTransform *matrix,
                                         CTFontDescriptorRef attributes)
{
    CTFontDescriptorRef base;
    CTFontDescriptorRef descriptor;
    CFDictionaryRef attributeDictionary = NULL;
    CGAffineTransform transform;
    CTFontRef result;

    if (font == NULL)
        return NULL;

    base = CTFontCopyFontDescriptor(font);
    if (attributes != NULL)
        attributeDictionary = CTFontDescriptorCopyAttributes(attributes);
    descriptor = CTFontDescriptorCreateCopyWithAttributes(base, attributeDictionary);

    transform = matrix != NULL ? *matrix : [(KTFont *) font matrix];
    if (size == 0)
        size = CTFontGetSize(font);

    result = KTFontCreateWithDescriptorAndMatrix(descriptor, size, &transform);

    if (attributeDictionary != NULL)
        CFRelease(attributeDictionary);
    CFRelease(descriptor);
    CFRelease(base);
    return result;
}

CTFontRef CTFontCreateCopyWithSymbolicTraits(CTFontRef font, CGFloat size,
                                             const CGAffineTransform *matrix,
                                             CTFontSymbolicTraits symTraitValue,
                                             CTFontSymbolicTraits symTraitMask)
{
    CTFontDescriptorRef base;
    CTFontDescriptorRef descriptor;
    CGAffineTransform transform;
    CTFontRef result;

    if (font == NULL)
        return NULL;

    base = CTFontCopyFontDescriptor(font);
    descriptor = CTFontDescriptorCreateCopyWithSymbolicTraits(base, symTraitValue, symTraitMask);

    transform = matrix != NULL ? *matrix : [(KTFont *) font matrix];
    if (size == 0)
        size = CTFontGetSize(font);

    result = KTFontCreateWithDescriptorAndMatrix(descriptor, size, &transform);

    CFRelease(descriptor);
    CFRelease(base);
    return result;
}

CTFontRef CTFontCreateCopyWithFamily(CTFontRef font, CGFloat size,
                                     const CGAffineTransform *matrix, CFStringRef family)
{
    CTFontDescriptorRef base;
    CTFontDescriptorRef descriptor;
    CGAffineTransform transform;
    CTFontRef result;

    if (font == NULL)
        return NULL;

    base = CTFontCopyFontDescriptor(font);
    descriptor = CTFontDescriptorCreateCopyWithFamily(base, family);

    transform = matrix != NULL ? *matrix : [(KTFont *) font matrix];
    if (size == 0)
        size = CTFontGetSize(font);

    result = KTFontCreateWithDescriptorAndMatrix(descriptor, size, &transform);

    CFRelease(descriptor);
    CFRelease(base);
    return result;
}

CTFontRef CTFontCreateForString(CTFontRef currentFont, CFStringRef string, CFRange range) {
    return CTFontCreateForStringWithLanguage(currentFont, string, range, NULL);
}

CTFontRef CTFontCreateForStringWithLanguage(CTFontRef currentFont, CFStringRef string,
                                            CFRange range, CFStringRef language)
{
    FT_Face face;
    UniChar *characters;
    CFIndex length;
    CFIndex i;
    BOOL covered = YES;
    uint32_t firstUncovered = 0;

    (void) language;

    if (currentFont == NULL || string == NULL)
        return NULL;

    length = CFStringGetLength(string);
    if (range.location < 0 || range.location > length)
        range.location = 0;
    if (range.length < 0 || range.location + range.length > length)
        range.length = length - range.location;

    face = KTFontFace(currentFont);
    if (face == NULL)
        return NULL;

    characters = (UniChar *) malloc(sizeof(UniChar) * (range.length > 0 ? range.length : 1));
    CFStringGetCharacters(string, range, characters);

    for (i = 0; i < range.length; i++) {
        uint32_t code = characters[i];

        if (code >= 0xD800 && code <= 0xDBFF && i + 1 < range.length &&
            characters[i + 1] >= 0xDC00 && characters[i + 1] <= 0xDFFF) {
            code = 0x10000 + ((code - 0xD800) << 10) + (characters[i + 1] - 0xDC00);
            ++i;
        }

        if (FT_Get_Char_Index(face, code) == 0) {
            covered = NO;
            firstUncovered = code;
            break;
        }
    }

    free(characters);

    if (covered) {
        CFRetain(currentFont);
        return currentFont;
    }

    {
        CTFontDescriptorRef base = CTFontCopyFontDescriptor(currentFont);
        CTFontDescriptorRef fallback = KTFontDescriptorCreateForCharacter(base, firstUncovered);
        CGAffineTransform transform = [(KTFont *) currentFont matrix];
        CTFontRef result;

        CFRelease(base);
        if (fallback == NULL)
            return NULL;

        result = KTFontCreateWithDescriptorAndMatrix(fallback, CTFontGetSize(currentFont), &transform);
        CFRelease(fallback);
        return result;
    }
}

//
// descriptor
//

CTFontDescriptorRef CTFontCopyFontDescriptor(CTFontRef font) {
    NSDictionary *attributes = KTFontDescriptorAttributes(font);
    NSDictionary *merged = KTFontAttributesWithFaceNames(font, attributes);
    NSMutableDictionary *result = [[merged mutableCopy] autorelease];

    [result setObject: [NSNumber numberWithDouble: CTFontGetSize(font)] forKey: (NSString *) kCTFontSizeAttribute];
    return (CTFontDescriptorRef) [[KTFontDescriptor alloc] initWithAttributes: result];
}

CFTypeRef CTFontCopyAttribute(CTFontRef font, CFStringRef attribute) {
    if (font == NULL || attribute == NULL)
        return NULL;

    if (CFEqual(attribute, kCTFontSizeAttribute))
        return (CFTypeRef) [[NSNumber alloc] initWithDouble: CTFontGetSize(font)];

    {
        CTFontDescriptorRef descriptor = CTFontCopyFontDescriptor(font);
        CFTypeRef value;

        if (descriptor == NULL)
            return NULL;
        value = CTFontDescriptorCopyAttribute(descriptor, attribute);
        CFRelease(descriptor);
        return value;
    }
}

CGFloat CTFontGetSize(CTFontRef self) {
    return [self pointSize];
}

CGAffineTransform CTFontGetMatrix(CTFontRef font) {
    return [(KTFont *) font matrix];
}

CTFontSymbolicTraits CTFontGetSymbolicTraits(CTFontRef font) {
    NSDictionary *traits = KTFontTraitsForFont(font);
    return (CTFontSymbolicTraits)[[traits objectForKey: (NSString *) kCTFontSymbolicTrait] unsignedIntValue];
}

CFDictionaryRef CTFontCopyTraits(CTFontRef font) {
    return (CFDictionaryRef) [KTFontTraitsForFont(font) copy];
}

CFArrayRef CTFontCopyDefaultCascadeListForLanguages(CTFontRef font, CFArrayRef languagePrefList) {
    NSDictionary *attributes = KTFontDescriptorAttributes(font);
    NSMutableArray *result = [NSMutableArray array];

    (void) languagePrefList;

    if (attributes != nil) {
        NSString *family = [attributes objectForKey: (NSString *) kCTFontFamilyNameAttribute];
        if (family != nil) {
            CTFontDescriptorRef query = (CTFontDescriptorRef) [[KTFontDescriptor alloc] initWithAttributes:
                    [NSDictionary dictionaryWithObject: family forKey: (NSString *) kCTFontFamilyNameAttribute]];
            CFArrayRef matches = KTFontDescriptorCreateMatchingFontDescriptors(query, NULL);
            NSString *selfName = [attributes objectForKey: (NSString *) kCTFontNameAttribute];

            for (id match in (NSArray *) matches) {
                NSDictionary *matchAttributes = [(KTFontDescriptor *) match attributes];
                NSString *matchName = [matchAttributes objectForKey: (NSString *) kCTFontNameAttribute];
                if (selfName != nil && [selfName isEqualToString: matchName])
                    continue;
                [result addObject: match];
            }

            if (matches != NULL)
                CFRelease(matches);
            CFRelease(query);
        }
    }

    return (CFArrayRef) [result copy];
}

//
// names
//

CFStringRef CTFontCopyPostScriptName(CTFontRef font) {
    id value = KTFontDescriptorAttribute(font, kCTFontNameAttribute);

    if (value != nil)
        return (CFStringRef) [value retain];

    {
        FT_Face face = KTFontFace(font);
        const char *name = face != NULL ? FT_Get_Postscript_Name(face) : NULL;
        if (name != NULL)
            return (CFStringRef) [[NSString alloc] initWithUTF8String: name];
    }

    return nil;
}

CFStringRef CTFontCopyFamilyName(CTFontRef font) {
    id value = KTFontDescriptorAttribute(font, kCTFontFamilyNameAttribute);

    if (value != nil)
        return (CFStringRef) [value retain];

    {
        FT_Face face = KTFontFace(font);
        if (face != NULL && face->family_name != NULL)
            return (CFStringRef) [[NSString alloc] initWithUTF8String: face->family_name];
    }

    return nil;
}

CFStringRef CTFontCopyFullName(CTFontRef self) {
    id value = KTFontDescriptorAttribute(self, kCTFontDisplayNameAttribute);

    if (value != nil)
        return (CFStringRef) [value retain];

    return [self copyName];
}

CFStringRef CTFontCopyDisplayName(CTFontRef font) {
    return CTFontCopyFullName(font);
}

CFStringRef _Nullable CTFontCopyName(CTFontRef font, CFStringRef nameKey) {
    if (nameKey == NULL)
        return nil;

    if (CFEqual(nameKey, kCTFontPostScriptNameKey))
        return CTFontCopyPostScriptName(font);
    if (CFEqual(nameKey, kCTFontFamilyNameKey))
        return CTFontCopyFamilyName(font);
    if (CFEqual(nameKey, kCTFontFullNameKey))
        return CTFontCopyFullName(font);
    if (CFEqual(nameKey, kCTFontStyleNameKey) || CFEqual(nameKey, kCTFontSubFamilyNameKey)) {
        id value = KTFontDescriptorAttribute(font, kCTFontStyleNameAttribute);
        if (value != nil)
            return (CFStringRef) [value retain];
        {
            FT_Face face = KTFontFace(font);
            if (face != NULL && face->style_name != NULL)
                return (CFStringRef) [[NSString alloc] initWithUTF8String: face->style_name];
        }
    }

    {
        id value = KTFontDescriptorAttribute(font, nameKey);
        if (value != nil)
            return (CFStringRef) [value retain];
    }

    return nil;
}

CFStringRef CTFontCopyLocalizedName(CTFontRef font, CFStringRef nameKey,
                                    CFStringRef *actualLanguage)
{
    if (actualLanguage != NULL)
        *actualLanguage = NULL;
    return CTFontCopyName(font, nameKey);
}

CFCharacterSetRef CTFontCopyCharacterSet(CTFontRef font) {
    FT_Face face = KTFontFace(font);
    CFMutableCharacterSetRef characterSet;
    FT_UInt glyphIndex;
    FT_ULong character;

    if (face == NULL)
        return NULL;

    characterSet = CFCharacterSetCreateMutable(NULL);
    character = FT_Get_First_Char(face, &glyphIndex);

    while (glyphIndex != 0) {
        CFCharacterSetAddCharactersInRange(characterSet, CFRangeMake(character, 1));
        character = FT_Get_Next_Char(face, character, &glyphIndex);
    }

    return characterSet;
}

CFStringEncoding CTFontGetStringEncoding(CTFontRef font) {
    (void) font;
    return kCFStringEncodingUnicode;
}

CFArrayRef CTFontCopySupportedLanguages(CTFontRef font) {
    (void) font;
    return (CFArrayRef) [[NSArray array] copy];
}

//
// metrics
//

CGFloat CTFontGetAscent(CTFontRef self) {
    return [self ascender];
}

CGFloat CTFontGetDescent(CTFontRef self) {
    return [self descender];
}

CGFloat CTFontGetLeading(CTFontRef self) {
    return [self leading];
}

unsigned int CTFontGetUnitsPerEm(CTFontRef font) {
    return [(KTFont *) font unitsPerEm];
}

CFIndex CTFontGetGlyphCount(CTFontRef font) {
    return [font numberOfGlyphs];
}

CGRect CTFontGetBoundingBox(CTFontRef self) {
    return [self boundingRect];
}

CGFloat CTFontGetUnderlinePosition(CTFontRef self) {
    return [self underlinePosition];
}

CGFloat CTFontGetUnderlineThickness(CTFontRef self) {
    return [self underlineThickness];
}

CGFloat CTFontGetSlantAngle(CTFontRef self) {
    return [self italicAngle];
}

CGFloat CTFontGetCapHeight(CTFontRef self) {
    return [self capHeight];
}

CGFloat CTFontGetXHeight(CTFontRef self) {
    return [self xHeight];
}

//
// glyphs
//

CGPathRef CTFontCreatePathForGlyph(CTFontRef self, CGGlyph glyph, CGAffineTransform *xform) {
    return (CGPathRef) [self createPathForGlyph: glyph transform: xform];
}

CGGlyph CTFontGetGlyphWithName(CTFontRef font, CFStringRef glyphName) {
    KTFont *ktf = (KTFont *) font;

    if (ktf == nil || glyphName == NULL)
        return 0;

    return O2FontGetGlyphWithGlyphName((O2FontRef) [ktf font], glyphName);
}

CGRect CTFontGetBoundingRectsForGlyphs(CTFontRef font, CTFontOrientation orientation,
                                       const CGGlyph *glyphs, CGRect *boundingRects,
                                       CFIndex count)
{
    FT_Face face = KTFontFace(font);
    CGFloat scale = CTFontGetUnitsPerEm(font) != 0 ? CTFontGetSize(font) / (CGFloat) CTFontGetUnitsPerEm(font) : 1;
    CGFloat minX = 0, minY = 0, maxX = 0, maxY = 0;
    BOOL hasBounds = NO;
    CFIndex i;

    (void) orientation;

    if (face == NULL || glyphs == NULL || count <= 0)
        return CGRectZero;

    for (i = 0; i < count; i++) {
        CGRect rect = CGRectZero;

        if (FT_Load_Glyph(face, glyphs[i], FT_LOAD_NO_SCALE) == 0) {
            FT_Glyph_Metrics *metrics = &face->glyph->metrics;

            rect = CGRectMake(metrics->horiBearingX * scale,
                              (metrics->horiBearingY - metrics->height) * scale,
                              metrics->width * scale,
                              metrics->height * scale);
        }

        if (boundingRects != NULL)
            boundingRects[i] = rect;

        if (rect.size.width != 0 || rect.size.height != 0) {
            if (!hasBounds) {
                minX = CGRectGetMinX(rect);
                minY = CGRectGetMinY(rect);
                maxX = CGRectGetMaxX(rect);
                maxY = CGRectGetMaxY(rect);
                hasBounds = YES;
            } else {
                if (CGRectGetMinX(rect) < minX) minX = CGRectGetMinX(rect);
                if (CGRectGetMinY(rect) < minY) minY = CGRectGetMinY(rect);
                if (CGRectGetMaxX(rect) > maxX) maxX = CGRectGetMaxX(rect);
                if (CGRectGetMaxY(rect) > maxY) maxY = CGRectGetMaxY(rect);
            }
        }
    }

    if (!hasBounds)
        return CGRectZero;
    return CGRectMake(minX, minY, maxX - minX, maxY - minY);
}

double CTFontGetAdvancesForGlyphs(CTFontRef font, CTFontOrientation orientation,
                                  const CGGlyph *glyphs, CGSize *advances,
                                  CFIndex count)
{
    KTFont *ktf = (KTFont *) font;
    double sum = 0;
    CFIndex i;

    (void) orientation;

    if (ktf == nil || glyphs == NULL || count <= 0)
        return 0;

    for (i = 0; i < count; i++) {
        CGSize advance = CGSizeZero;

        [ktf getAdvancements: &advance forGlyphs: &glyphs[i] count: 1];
        if (advances != NULL)
            advances[i] = advance;
        sum += advance.width;
    }

    return sum;
}

CGRect CTFontGetOpticalBoundsForGlyphs(CTFontRef font, const CGGlyph *glyphs,
                                       CGRect *boundingRects, CFIndex count,
                                       CFOptionFlags options)
{
    (void) options;
    return CTFontGetBoundingRectsForGlyphs(font, kCTFontOrientationDefault, glyphs, boundingRects, count);
}

void CTFontGetVerticalTranslationsForGlyphs(CTFontRef font, const CGGlyph *glyphs,
                                            CGSize *translations, CFIndex count)
{
    CFIndex i;

    (void) font;
    (void) glyphs;

    for (i = 0; i < count; i++)
        translations[i] = CGSizeZero;
}

bool CTFontGetGlyphsForCharacters(CTFontRef font, const UniChar *characters,
                                  CGGlyph *glyphs, CFIndex count)
{
    FT_Face face = KTFontFace(font);
    BOOL all = YES;
    CFIndex i;

    if (face == NULL || characters == NULL || glyphs == NULL)
        return false;

    for (i = 0; i < count; i++) {
        uint32_t code = characters[i];

        if (code >= 0xD800 && code <= 0xDBFF && i + 1 < count &&
            characters[i + 1] >= 0xDC00 && characters[i + 1] <= 0xDFFF) {
            code = 0x10000 + ((code - 0xD800) << 10) + (characters[i + 1] - 0xDC00);
            glyphs[i] = FT_Get_Char_Index(face, code);
            glyphs[i + 1] = 0;
            if (glyphs[i] == 0)
                all = NO;
            ++i;
        } else {
            glyphs[i] = FT_Get_Char_Index(face, code);
            if (glyphs[i] == 0)
                all = NO;
        }
    }

    return all;
}

void CTFontDrawGlyphs(CTFontRef font, const CGGlyph *glyphs, const CGPoint *positions,
                      size_t count, CGContextRef context)
{
    KTFont *ktf = (KTFont *) font;
    CGFontRef cgFont;
    CGAffineTransform textMatrix;
    size_t i;

    if (ktf == nil || glyphs == NULL || positions == NULL || count == 0 || context == NULL)
        return;

    cgFont = [ktf font];
    if (cgFont == NULL)
        return;

    CGContextSaveGState(context);
    CGContextSetFont(context, cgFont);
    CGContextSetFontSize(context, [ktf pointSize]);

    textMatrix = CGContextGetTextMatrix(context);
    textMatrix = CGAffineTransformConcat([ktf matrix], textMatrix);
    CGContextSetTextMatrix(context, textMatrix);

    for (i = 0; i < count; i++)
        CGContextShowGlyphsAtPoint(context, positions[i].x, positions[i].y, &glyphs[i], 1);

    CGContextRestoreGState(context);
}

CFIndex CTFontGetLigatureCaretPositions(CTFontRef font, CGGlyph glyph, CGFloat *positions,
                                        CFIndex maxPositions)
{
    (void) font;
    (void) glyph;
    (void) positions;
    (void) maxPositions;
    return 0;
}

//
// graphics / platform fonts
//

CGFontRef CTFontCopyGraphicsFont(CTFontRef font, CTFontDescriptorRef *attributes) {
    KTFont *ktf = (KTFont *) font;

    if (ktf == nil)
        return NULL;

    if (attributes != NULL)
        *attributes = CTFontCopyFontDescriptor(font);

    return CGFontRetain([ktf font]);
}

CTFontRef
CTFontCreateWithGraphicsFont(CGFontRef cgFont, CGFloat size,
                             CGAffineTransform *xform,
                             CTFontDescriptorRef attributes)
{
    CGAffineTransform transform = xform != NULL ? *xform : CGAffineTransformIdentity;

    if (cgFont == NULL)
        return NULL;

    if (size == 0)
        size = 12.0;

    return (CTFontRef) [[KTFont alloc] initWithFont: cgFont
                                         descriptor: attributes
                                               size: size
                                             matrix: &transform];
}

ATSFontRef CTFontGetPlatformFont(CTFontRef font, CTFontDescriptorRef *attributes) {
    (void) font;
    if (attributes != NULL)
        *attributes = NULL;
    return 0;
}

CTFontRef CTFontCreateWithPlatformFont(ATSFontRef platformFont, CGFloat size,
                                       const CGAffineTransform *matrix,
                                       CTFontDescriptorRef attributes)
{
    (void) platformFont;
    (void) size;
    (void) matrix;
    (void) attributes;
    return nil;
}

CTFontRef CTFontCreateWithQuickdrawInstance(ConstStr255Param name, int16_t identifier,
                                            uint8_t style, CGFloat size)
{
    (void) name;
    (void) identifier;
    (void) style;
    (void) size;
    return nil;
}

//
// tables
//

CFArrayRef CTFontCopyAvailableTables(CTFontRef font, CTFontTableOptions options) {
    NSDictionary *attributes = KTFontDescriptorAttributes(font);
    NSURL *url = [attributes objectForKey: (NSString *) kCTFontURLAttribute];
    NSData *data;
    NSMutableArray *tags;
    const uint8_t *bytes;
    NSUInteger length;
    uint16_t tableCount;
    uint16_t i;

    (void) options;

    if (![url isKindOfClass: [NSURL class]])
        return (CFArrayRef) [[NSArray array] copy];

    data = [NSData dataWithContentsOfURL: url];
    if (data == nil || [data length] < 12)
        return (CFArrayRef) [[NSArray array] copy];

    bytes = [data bytes];
    length = [data length];
    tableCount = (uint16_t) ((bytes[4] << 8) | bytes[5]);
    tags = [NSMutableArray array];

    for (i = 0; i < tableCount; i++) {
        NSUInteger offset = 12 + (NSUInteger) i * 16;
        FourCharCode tag;
        if (offset + 4 > length)
            break;
        tag = ((FourCharCode) bytes[offset] << 24) | ((FourCharCode) bytes[offset + 1] << 16) |
              ((FourCharCode) bytes[offset + 2] << 8) | ((FourCharCode) bytes[offset + 3]);
        [tags addObject: [NSNumber numberWithUnsignedInt: tag]];
    }

    return (CFArrayRef) [tags copy];
}

CFDataRef CTFontCopyTable(CTFontRef font, CTFontTableTag table, CTFontTableOptions options) {
    KTFont *ktf = (KTFont *) font;

    (void) options;

    if (ktf == nil)
        return NULL;

    return (CFDataRef) [ktf copyTableForTag: (uint32_t) table];
}

//
// variations / features
//

CFArrayRef CTFontCopyVariationAxes(CTFontRef font) {
    (void) font;
    return NULL;
}

CFDictionaryRef CTFontCopyVariation(CTFontRef font) {
    (void) font;
    return NULL;
}

CFArrayRef CTFontCopyFeatures(CTFontRef font) {
    (void) font;
    return (CFArrayRef) [[NSArray array] copy];
}

CFArrayRef CTFontCopyFeatureSettings(CTFontRef font) {
    (void) font;
    return (CFArrayRef) [[NSArray array] copy];
}

CFTypeID CTFontGetTypeID(void) {
    return (CFTypeID) [KTFont class];
}