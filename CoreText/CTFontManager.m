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

#import <CoreText/CTFontManager.h>
#import "KTFontDescriptorInternal.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNumber.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#include <stdlib.h>

const CFStringRef kCTFontManagerRegisteredFontsChangedNotification = CFSTR("CTFontManagerFontChangedNotification");

enum {
    kKTFontFormatTrueType = 3,
};

// graphics fonts registered for the process (PostScript name -> CGFontRef)
static NSMutableDictionary *KTFontManagerGraphicsFonts(void) {
    static NSMutableDictionary *fonts = nil;

    if (fonts == nil) {
        @synchronized ([KTFontDescriptor class]) {
            if (fonts == nil)
                fonts = [NSMutableDictionary new];
        }
    }
    return fonts;
}

CGFontRef KTFontManagerCopyGraphicsFontForName(CFStringRef name) {
    CGFontRef font;

    if (name == NULL)
        return NULL;

    @synchronized (KTFontManagerGraphicsFonts()) {
        font = [KTFontManagerGraphicsFonts() objectForKey: (NSString *) name];
    }

    return font != NULL ? CGFontRetain(font) : NULL;
}

static NSString *KTManagerPostScriptNameForGraphicsFont(CGFontRef font) {
    O2Font_freetype *ftFont = (O2Font_freetype *) (O2FontRef) font;

    if ([ftFont isKindOfClass: [O2Font_freetype class]]) {
        FT_Face face = [ftFont face];
        const char *name = face != NULL ? FT_Get_Postscript_Name(face) : NULL;
        if (name != NULL)
            return [NSString stringWithUTF8String: name];
    }

    return [(NSString *) CGFontCopyFullName(font) autorelease];
}

static NSDictionary *KTManagerTraitsForFTFace(FT_Face face) {
    uint32_t symbolic = 0;

    if (face->style_flags & FT_STYLE_FLAG_BOLD)
        symbolic |= kCTFontTraitBold;
    if (face->style_flags & FT_STYLE_FLAG_ITALIC)
        symbolic |= kCTFontTraitItalic;
    if (face->face_flags & FT_FACE_FLAG_FIXED_WIDTH)
        symbolic |= kCTFontTraitMonoSpace;

    double weight = (face->style_flags & FT_STYLE_FLAG_BOLD) ? 0.5 : 0.0;
    double slant = (face->style_flags & FT_STYLE_FLAG_ITALIC) ? 1.0 : 0.0;

    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedInt: symbolic], (NSString *) kCTFontSymbolicTrait,
            [NSNumber numberWithDouble: weight], (NSString *) kCTFontWeightTrait,
            [NSNumber numberWithDouble: 0.0], (NSString *) kCTFontWidthTrait,
            [NSNumber numberWithDouble: slant], (NSString *) kCTFontSlantTrait,
            nil];
}

static NSDictionary *KTManagerAttributesFromFace(FT_Face face, NSURL *url, int index, NSData *data) {
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

    if (url != nil)
        [attributes setObject: url forKey: (NSString *) kCTFontURLAttribute];
    if (data != nil)
        [attributes setObject: data forKey: (NSString *) kKTFontDataAttribute];
    if (index >= 0)
        [attributes setObject: [NSNumber numberWithInt: index] forKey: (NSString *) kKTFontFileIndexAttribute];

    if (face->family_name != NULL)
        [attributes setObject: [NSString stringWithUTF8String: face->family_name] forKey: (NSString *) kCTFontFamilyNameAttribute];
    if (face->style_name != NULL)
        [attributes setObject: [NSString stringWithUTF8String: face->style_name] forKey: (NSString *) kCTFontStyleNameAttribute];

    {
        const char *postScriptName = FT_Get_Postscript_Name(face);
        if (postScriptName != NULL)
            [attributes setObject: [NSString stringWithUTF8String: postScriptName] forKey: (NSString *) kCTFontNameAttribute];
    }

    {
        NSString *family = [attributes objectForKey: (NSString *) kCTFontFamilyNameAttribute];
        NSString *style = [attributes objectForKey: (NSString *) kCTFontStyleNameAttribute];
        NSString *display = nil;
        if (family != nil)
            display = style != nil ? [NSString stringWithFormat: @"%@ %@", family, style] : family;
        if (display == nil)
            display = [attributes objectForKey: (NSString *) kCTFontNameAttribute];
        if (display != nil)
            [attributes setObject: display forKey: (NSString *) kCTFontDisplayNameAttribute];
    }

    [attributes setObject: KTManagerTraitsForFTFace(face) forKey: (NSString *) kCTFontTraitsAttribute];
    [attributes setObject: [NSNumber numberWithInt: kKTFontFormatTrueType] forKey: (NSString *) kCTFontFormatAttribute];
    [attributes setObject: [NSNumber numberWithBool: YES] forKey: (NSString *) kCTFontEnabledAttribute];

    return attributes;
}

//
// enumeration
//

static CFArrayRef KTManagerCopyUniqueFontStrings(const char *object) {
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
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
            FcChar8 *value = NULL;

            if (FcPatternGetString(set->fonts[j], object, 0, &value) != FcResultMatch || value == NULL)
                continue;

            {
                NSString *string = [NSString stringWithUTF8String: (const char *) value];
                if (string == nil || [seen containsObject: string])
                    continue;
                [seen addObject: string];
                [result addObject: string];
            }
        }
    }

    [KTFontFontConfigLock() unlock];

    return (CFArrayRef) [result copy];
}

CFArrayRef CTFontManagerCopyAvailableFontFamilyNames(void) {
    return KTManagerCopyUniqueFontStrings(FC_FAMILY);
}

CFArrayRef CTFontManagerCopyAvailablePostScriptNames(void) {
    return KTManagerCopyUniqueFontStrings(FC_POSTSCRIPT_NAME);
}

CFArrayRef CTFontManagerCopyAvailableFontURLs(void) {
    CFArrayRef paths = KTManagerCopyUniqueFontStrings(FC_FILE);
    NSMutableArray *urls = [NSMutableArray array];

    for (NSString *path in (NSArray *) paths)
        [urls addObject: [NSURL fileURLWithPath: path]];

    CFRelease(paths);
    return (CFArrayRef) [urls copy];
}

//
// descriptors
//

CTFontDescriptorRef CTFontManagerCreateFontDescriptorFromData(CFDataRef data) {
    O2DataProviderRef provider;
    O2Font_freetype *font;
    FT_Face face;
    NSDictionary *attributes;
    id result;

    if (data == NULL)
        return NULL;

    provider = O2DataProviderCreateWithCFData(data);
    if (provider == NULL)
        return NULL;

    font = (O2Font_freetype *) O2FontCreateWithDataProvider(provider);
    O2DataProviderRelease(provider);

    if (font == NULL)
        return NULL;

    face = [font face];
    if (face == NULL) {
        [font release];
        return NULL;
    }

    attributes = KTManagerAttributesFromFace(face, nil, -1, (NSData *) data);
    result = [[KTFontDescriptor alloc] initWithAttributes: attributes];
    [font release];

    return (CTFontDescriptorRef) result;
}

CFArrayRef CTFontManagerCreateFontDescriptorsFromURL(CFURLRef url) {
    NSString *path = [(NSURL *) url path];
    FT_Face face;
    long faceCount;
    long i;
    NSMutableArray *result;

    if (path == nil)
        return NULL;

    if (FT_New_Face(O2FontSharedFreeTypeLibrary(), [path fileSystemRepresentation], 0, &face) != 0)
        return NULL;

    faceCount = face->num_faces;
    FT_Done_Face(face);

    result = [NSMutableArray array];

    for (i = 0; i < faceCount; i++) {
        if (FT_New_Face(O2FontSharedFreeTypeLibrary(), [path fileSystemRepresentation], (int) i, &face) != 0)
            continue;

        {
            NSDictionary *attributes = KTManagerAttributesFromFace(face, (NSURL *) url, (int) i, nil);
            KTFontDescriptor *descriptor = [[KTFontDescriptor alloc] initWithAttributes: attributes];
            [result addObject: descriptor];
            [descriptor release];
        }

        FT_Done_Face(face);
    }

    return (CFArrayRef) [result copy];
}

//
// registration
//

bool CTFontManagerRegisterFontsForURL(CFURLRef fontURL, CTFontManagerScope scope, CFErrorRef *error) {
    NSString *path = [(NSURL *) fontURL path];
    FcBool result;

    (void) scope;
    (void) error;

    if (path == nil)
        return false;

    [KTFontFontConfigLock() lock];
    result = FcConfigAppFontAddFile(O2FontSharedFontConfig(), (const FcChar8 *) [path fileSystemRepresentation]);
    [KTFontFontConfigLock() unlock];

    return result != FcFalse;
}

bool CTFontManagerUnregisterFontsForURL(CFURLRef fontURL, CTFontManagerScope scope, CFErrorRef *error) {
    // TODO: fontconfig has no API to remove an application font
    (void) fontURL;
    (void) scope;
    (void) error;
    return false;
}

bool CTFontManagerRegisterGraphicsFont(CGFontRef font, CFErrorRef *error) {
    NSString *name = KTManagerPostScriptNameForGraphicsFont(font);

    (void) error;

    if (name == nil)
        return false;

    @synchronized (KTFontManagerGraphicsFonts()) {
        [KTFontManagerGraphicsFonts() setObject: (id) font forKey: name];
    }
    return true;
}

bool CTFontManagerUnregisterGraphicsFont(CGFontRef font, CFErrorRef *error) {
    NSString *name = KTManagerPostScriptNameForGraphicsFont(font);

    (void) error;

    if (name == nil)
        return false;

    @synchronized (KTFontManagerGraphicsFonts()) {
        [KTFontManagerGraphicsFonts() removeObjectForKey: name];
    }
    return true;
}