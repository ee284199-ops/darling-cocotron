/* Copyright (c) 2008 Johannes Fortmann

 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 of the Software, and to permit persons to whom the Software is furnished to do
 so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE. */

#import <CoreText/KTFont_FT.h>
#import <Onyx2D/O2Font_freetype.h>

#import <Foundation/NSData.h>
#import <Foundation/NSString.h>

#include <stdlib.h>

#import FT_OUTLINE_H
#import FT_GLYPH_H
#import FT_TRUETYPE_TABLES_H

typedef struct {
    CGMutablePathRef path;
    CGFloat scale;
    CGAffineTransform fontMatrix;
    CGAffineTransform userTransform;
} KTFTOutlineContext;

static CGPoint KTFTTransformPoint(KTFTOutlineContext *context, const FT_Vector *vector) {
    CGPoint point = CGPointMake(vector->x * context->scale, vector->y * context->scale);

    point = CGPointApplyAffineTransform(point, context->fontMatrix);
    point = CGPointApplyAffineTransform(point, context->userTransform);
    return point;
}

static int KTFTMoveTo(const FT_Vector *to, void *user) {
    KTFTOutlineContext *context = (KTFTOutlineContext *) user;
    CGPoint point = KTFTTransformPoint(context, to);

    CGPathMoveToPoint(context->path, NULL, point.x, point.y);
    return 0;
}

static int KTFTLineTo(const FT_Vector *to, void *user) {
    KTFTOutlineContext *context = (KTFTOutlineContext *) user;
    CGPoint point = KTFTTransformPoint(context, to);

    CGPathAddLineToPoint(context->path, NULL, point.x, point.y);
    return 0;
}

static int KTFTConicTo(const FT_Vector *control, const FT_Vector *to, void *user) {
    KTFTOutlineContext *context = (KTFTOutlineContext *) user;
    CGPoint controlPoint = KTFTTransformPoint(context, control);
    CGPoint point = KTFTTransformPoint(context, to);

    CGPathAddQuadCurveToPoint(context->path, NULL, controlPoint.x, controlPoint.y, point.x, point.y);
    return 0;
}

static int KTFTCubicTo(const FT_Vector *control1, const FT_Vector *control2, const FT_Vector *to, void *user) {
    KTFTOutlineContext *context = (KTFTOutlineContext *) user;
    CGPoint point1 = KTFTTransformPoint(context, control1);
    CGPoint point2 = KTFTTransformPoint(context, control2);
    CGPoint point = KTFTTransformPoint(context, to);

    CGPathAddCurveToPoint(context->path, NULL, point1.x, point1.y, point2.x, point2.y, point.x, point.y);
    return 0;
}

@implementation KTFont (KTFont_FT)
+ (id) allocWithZone: (NSZone *) zone {
    return NSAllocateObject([KTFont_FT class], 0, NULL);
}
@end

@implementation KTFont_FT

- initWithUIFontType: (CTFontUIFontType) uiFontType
                size: (CGFloat) size
            language: (NSString *) language
{
    NSString *name = nil;
    O2Font *font;

    (void) language;

    // macOS's names, which the font lookup maps to similar fonts that the system has
    switch (uiFontType) {
    case kCTFontUIFontUserFixedPitch:
        name = @"Menlo";
        break;

    case kCTFontUIFontEmphasizedSystem:
    case kCTFontUIFontSmallEmphasizedSystem:
    case kCTFontUIFontMiniEmphasizedSystem:
    case kCTFontUIFontEmphasizedSystemDetail:
    case kCTFontUIFontAlertHeader:
        name = @".AppleSystemUIFont-Bold";
        break;

    case kCTFontUIFontSystem:
    case kCTFontUIFontSmallSystem:
    case kCTFontUIFontMiniSystem:
    case kCTFontUIFontViews:
    case kCTFontUIFontApplication:
    case kCTFontUIFontLabel:
    case kCTFontUIFontMenuTitle:
    case kCTFontUIFontMenuItem:
    case kCTFontUIFontMenuItemMark:
    case kCTFontUIFontMenuItemCmdKey:
    case kCTFontUIFontWindowTitle:
    case kCTFontUIFontPushButton:
    case kCTFontUIFontUtilityWindowTitle:
    case kCTFontUIFontSystemDetail:
    case kCTFontUIFontToolbar:
    case kCTFontUIFontSmallToolbar:
    case kCTFontUIFontMessage:
    case kCTFontUIFontPalette:
    case kCTFontUIFontToolTip:
    case kCTFontUIFontControlContent:
    default:
        name = @".AppleSystemUIFont";
        break;
    }

    if (size == 0)
        size = 12;

    font = O2FontCreateWithFontName(name);
    if (font == nil)
        return nil;

    self = [self initWithFont: (CGFontRef) font size: size];
    [font release];
    return self;
}

- (FT_Face) face {
    return [(O2Font_freetype *) _font face];
}

// what the font says its widest glyph is (hhea's advanceWidthMax), without measuring them all
- (CGSize) maximumAdvancement {
    FT_Face face = [self face];

    if (face == NULL || face->max_advance_width <= 0)
        return [super maximumAdvancement];
    return CGSizeMake(face->max_advance_width * _size / _unitsPerEm, 0);
}

- (CGRect) boundingRect {
    FT_Face face = [self face];
    CGFloat scale;

    if (face == NULL)
        return CGRectZero;

    scale = _size / _unitsPerEm;

    return CGRectMake(face->bbox.xMin * scale, face->bbox.yMin * scale,
                      (face->bbox.xMax - face->bbox.xMin) * scale,
                      (face->bbox.yMax - face->bbox.yMin) * scale);
}

- (CGFloat) underlinePosition {
    FT_Face face = [self face];

    if (face == NULL)
        return 0;

    return face->underline_position * _size / _unitsPerEm;
}

- (CGFloat) underlineThickness {
    FT_Face face = [self face];

    if (face == NULL)
        return 0;

    return face->underline_thickness * _size / _unitsPerEm;
}

- (void) getGlyphs: (CGGlyph *) glyphs
        forCharacters: (const unichar *) characters
               length: (NSUInteger) length
{
    O2Font_freetype *o2Font = (O2Font_freetype *) _font;
    FT_Face face = [o2Font face];
    O2FontFreeTypeLockScope();

    int i;
    for (i = 0; i < length; i++) {
        glyphs[i] = FT_Get_Char_Index(face, characters[i]);
    }
}

- (void) getAdvancements: (CGSize *) advancements
               forGlyphs: (const CGGlyph *) glyphs
                   count: (NSUInteger) count
{
    O2Font_freetype *o2Font = (O2Font_freetype *) _font;
    FT_Face face = [o2Font face];
    O2FontFreeTypeLockScope();

    int i;
    FT_Set_Pixel_Sizes(face, _size, _size);

    for (i = 0; i < count; i++) {
        FT_Load_Glyph(face, glyphs[i], FT_LOAD_DEFAULT);
        advancements[i] = CGSizeMake(face->glyph->advance.x / (O2Float)(2 << 5),
                       face->glyph->advance.y / (O2Float)(2 << 5));
    }
}

- (CGPoint) positionOfGlyph: (CGGlyph) current
            precededByGlyph: (CGGlyph) previous
                  isNominal: (BOOL *) isNominalp
{
    O2Font_freetype *o2Font = (O2Font_freetype *) _font;
    FT_Face face = [o2Font face];
    O2FontFreeTypeLockScope();

    *isNominalp = YES;

    if (!current)
        return NSZeroPoint;

    FT_Set_Pixel_Sizes(face, _size, _size);

    FT_Load_Glyph(face, current, FT_LOAD_DEFAULT);
    return NSMakePoint(face->glyph->advance.x / (O2Float)(2 << 5),
                       face->glyph->advance.y / (O2Float)(2 << 5));
}

- (CGPathRef) createPathForGlyph: (CGGlyph) glyph
                       transform: (CGAffineTransform *) xform
{
    FT_Face face = [self face];
    O2FontFreeTypeLockScope();
    KTFTOutlineContext context;
    FT_Outline_Funcs functions = { KTFTMoveTo, KTFTLineTo, KTFTConicTo, KTFTCubicTo, 0, 0 };

    if (face == NULL)
        return NULL;

    if (FT_Load_Glyph(face, glyph, FT_LOAD_NO_SCALE | FT_LOAD_NO_BITMAP) != 0)
        return NULL;

    if (face->glyph->format != FT_GLYPH_FORMAT_OUTLINE)
        return NULL;

    context.path = CGPathCreateMutable();
    context.scale = _unitsPerEm != 0 ? _size / _unitsPerEm : 1;
    context.fontMatrix = _matrix;
    context.userTransform = (xform != NULL) ? *xform : CGAffineTransformIdentity;

    FT_Outline_Decompose(&face->glyph->outline, &functions, &context);

    return context.path;
}

- (NSData *) copyTableForTag: (uint32_t) tag {
    FT_Face face = [self face];
    O2FontFreeTypeLockScope();
    FT_ULong length = 0;
    void *buffer;
    NSData *data;

    if (face == NULL)
        return nil;

    if (FT_Load_Sfnt_Table(face, tag, 0, NULL, &length) != 0 || length == 0)
        return nil;

    buffer = malloc(length);
    if (FT_Load_Sfnt_Table(face, tag, 0, (FT_Byte *) buffer, &length) != 0) {
        free(buffer);
        return nil;
    }

    data = [[NSData alloc] initWithBytes: buffer length: length];
    free(buffer);
    return data;
}

@end