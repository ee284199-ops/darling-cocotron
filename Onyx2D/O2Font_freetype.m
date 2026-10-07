#import <Onyx2D/O2Font_freetype.h>
#ifdef FREETYPE_PRESENT
#import <Onyx2D/O2Encoding.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSLock.h>
#include <dispatch/dispatch.h>
#include <fcntl.h>
#include <pthread.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

@implementation O2Font_freetype

#ifdef DARLING

O2FontRef O2FontCreateWithFontName_platform(NSString *name) {
    return [[O2Font_freetype alloc] initWithFontName: name];
}

O2FontRef O2FontCreateWithDataProvider_platform(O2DataProviderRef provider) {
    return [[O2Font_freetype alloc] initWithDataProvider: provider];
}

#endif

static pthread_mutex_t O2FontFreeTypeMutex;

static void O2FontFreeTypeMutexInit(void) {
    pthread_mutexattr_t attributes;

    pthread_mutexattr_init(&attributes);
    pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&O2FontFreeTypeMutex, &attributes);
    pthread_mutexattr_destroy(&attributes);
}

void O2FontFreeTypeLock(void) {
    static pthread_once_t once = PTHREAD_ONCE_INIT;

    pthread_once(&once, O2FontFreeTypeMutexInit);
    pthread_mutex_lock(&O2FontFreeTypeMutex);
}

void O2FontFreeTypeUnlock(void) {
    pthread_mutex_unlock(&O2FontFreeTypeMutex);
}

FT_Library O2FontSharedFreeTypeLibrary() {
    static FT_Library library = NULL;

    if (library == NULL) {
        if (FT_Init_FreeType(&library) != 0) {
            NSLog(@"FT_Init_FreeType failed");
        }
    }

    return library;
}

// Font objects are created per size (CoreText, and Skia through it, makes a CTFont for every size
// and transform), and each FT_New_Face mapped the whole file again: 31 MB each time for Noto Sans
// CJK. Faces keep their own state, but share one mapping of their file, kept for the process's life.
FT_Error O2FontFreeTypeNewFace(const char *path, FT_Long index, FT_Face *face) {
    static NSMutableDictionary *files = nil;
    static NSLock *lock = nil;
    static dispatch_once_t once;
    NSString *key;
    NSData *data;

    dispatch_once(&once, ^{
        files = [[NSMutableDictionary alloc] init];
        lock = [[NSLock alloc] init];
    });

    key = [NSString stringWithUTF8String: path];
    [lock lock];
    data = [files objectForKey: key];
    if (data == nil) {
        int fd = open(path, O_RDONLY | O_CLOEXEC);
        struct stat info;

        // fontconfig runs natively and lists host paths; the host's root is /Volumes/SystemRoot
        if (fd < 0 && strncmp(path, "/Volumes/SystemRoot/", 20) != 0) {
            char hostPath[PATH_MAX];

            snprintf(hostPath, sizeof(hostPath), "/Volumes/SystemRoot%s", path);
            fd = open(hostPath, O_RDONLY | O_CLOEXEC);
        }

        if (fd >= 0 && fstat(fd, &info) == 0 && info.st_size > 0) {
            void *bytes = mmap(NULL, (size_t) info.st_size, PROT_READ, MAP_PRIVATE, fd, 0);

            if (bytes != MAP_FAILED) {
                data = [NSData dataWithBytesNoCopy: bytes
                                            length: (NSUInteger) info.st_size
                                      freeWhenDone: NO];
                [files setObject: data forKey: key];
            }
        }
        if (fd >= 0)
            close(fd);
    }
    [lock unlock];

    if (data == nil)
        return FT_Err_Cannot_Open_Resource;

    O2FontFreeTypeLockScope();
    return FT_New_Memory_Face(O2FontSharedFreeTypeLibrary(), [data bytes],
                              (FT_Long) [data length], index, face);
}

static void addAppFont(FcConfig *config, NSString *path) {
    path = [[NSBundle mainBundle] pathForResource: path ofType: nil];
    if (path == nil) {
        NSLog(@"Cannot find font %@ in resources", path);
        return;
    }
    BOOL isDirectory;
    [[NSFileManager defaultManager] fileExistsAtPath: path
                                         isDirectory: &isDirectory];
    if (isDirectory) {
        FcConfigAppFontAddDir(config, (const FcChar8 *) [path UTF8String]);
    } else {
        FcConfigAppFontAddFile(config, (const FcChar8 *) [path UTF8String]);
    }
}

FcConfig *O2FontSharedFontConfig() {
    static FcConfig *fontConfig = NULL;

    if (fontConfig == NULL) {
        fontConfig = FcInitLoadConfigAndFonts();

        id appFontsPath = [[NSBundle mainBundle]
                objectForInfoDictionaryKey: @"ATSApplicationFontsPath"];
        if ([appFontsPath isKindOfClass: [NSString class]]) {
            addAppFont(fontConfig, appFontsPath);
        } else if ([appFontsPath isKindOfClass: [NSArray class]]) {
            for (NSString *path in appFontsPath) {
                addAppFont(fontConfig, path);
            }
        }
    }

    return fontConfig;
}

- (instancetype) initWithDataProvider: (O2DataProviderRef) provider {
    self = [super initWithDataProvider: provider];
    if (self == nil) {
        return nil;
    }

    const void *bytes = [provider bytes];
    size_t length = [provider length];

    FT_Face face;
    O2FontFreeTypeLock();
    int error = FT_New_Memory_Face(O2FontSharedFreeTypeLibrary(), bytes, length,
                                   0, &face);
    O2FontFreeTypeUnlock();

    if (error != 0) {
        NSLog(@"FT_New_Memory_Face() = %d", error);
        [self release];
        return nil;
    }

    return [self initWithFace: face];
}

// macOS fonts that Linux systems don't have, and the fontconfig family that stands in for them.
// fontconfig's own configuration already maps Helvetica, Arial, Times and Courier to
// metric-compatible fonts; these it would replace with the locale's default sans-serif font.
static const struct {
    const char *family;
    const char *generic;
} O2FontGenericFallbacks[] = {
    { "Menlo", "monospace" },
    { "Monaco", "monospace" },
    { "SF Mono", "monospace" },
    { "Andale Mono", "monospace" },
    { "PT Mono", "monospace" },
    { ".AppleSystemUIFont", "sans-serif" },
    { ".AppleSystemUIFontMonospaced", "monospace" },
    { ".SF NS", "sans-serif" },
    { ".SF NS Text", "sans-serif" },
    { ".SF NS Display", "sans-serif" },
    { ".SF NS Mono", "monospace" },
    { ".SFNS", "sans-serif" },
    { ".SFNSText", "sans-serif" },
    { ".SFNSDisplay", "sans-serif" },
    { ".SFNSMono", "monospace" },
    { "SF Pro", "sans-serif" },
    { "SF Pro Text", "sans-serif" },
    { "SF Pro Display", "sans-serif" },
    { "San Francisco", "sans-serif" },
    { "Helvetica Neue", "sans-serif" },
    { "HelveticaNeue", "sans-serif" },
    { "Lucida Grande", "sans-serif" },
    { "LucidaGrande", "sans-serif" },
    { "Geneva", "sans-serif" },
    { "Avenir", "sans-serif" },
    { "Avenir Next", "sans-serif" },
    { "AvenirNext", "sans-serif" },
    { "New York", "serif" },
    { "Georgia", "serif" },
    { "Palatino", "serif" },
};

const char *O2FontGenericFamilyForFamily(NSString *family) {
    size_t i;

    for (i = 0; i < sizeof(O2FontGenericFallbacks) / sizeof(O2FontGenericFallbacks[0]); i++) {
        if ([family caseInsensitiveCompare: [NSString stringWithUTF8String: O2FontGenericFallbacks[i].family]] == NSOrderedSame)
            return O2FontGenericFallbacks[i].generic;
    }
    return NULL;
}

// Families tried before the generic one: fonts whose Latin letters are like the macOS fonts'
// (DejaVu Sans Mono is what Menlo was made from). Locales such as Korean otherwise make the
// generic family a CJK font, whose Latin letters are narrow and whose widest glyphs are three
// characters wide.
// Monospaced fonts first whose glyphs all share one width, like Menlo's: apps size columns
// with the widest glyph (Noto Sans Mono has some 1.8 em wide).
static const char *const O2FontMonospaceFamilies[] = {
    "DejaVu Sans Mono", "Adwaita Mono", "Source Code Pro", "Liberation Mono", "Noto Sans Mono", NULL
};
static const char *const O2FontSansSerifFamilies[] = {
    "Noto Sans", "DejaVu Sans", "Adwaita Sans", "Liberation Sans", "Cantarell", NULL
};
static const char *const O2FontSerifFamilies[] = {
    "Noto Serif", "DejaVu Serif", "Liberation Serif", NULL
};

void O2FontAddFallbackFamilies(FcPattern *pattern, NSString *family) {
    const char *generic = O2FontGenericFamilyForFamily(family);
    const char *const *preferred = NULL;

    if (generic == NULL)
        return;

    if (strcmp(generic, "monospace") == 0)
        preferred = O2FontMonospaceFamilies;
    else if (strcmp(generic, "sans-serif") == 0)
        preferred = O2FontSansSerifFamilies;
    else if (strcmp(generic, "serif") == 0)
        preferred = O2FontSerifFamilies;

    for (; preferred != NULL && *preferred != NULL; preferred++)
        FcPatternAddString(pattern, FC_FAMILY, (const FcChar8 *) *preferred);
    FcPatternAddString(pattern, FC_FAMILY, (const FcChar8 *) generic);
}

// The fonts' PostScript names, each with its file and face index ("file", "index"). Built once
// from fontconfig's font list: fontconfig doesn't find fonts by PostScript name reliably.
static NSDictionary *O2FontPostScriptNameIndex(void) {
    static NSDictionary *index = nil;
    static dispatch_once_t once;

    dispatch_once(&once, ^{
        FcConfig *config = O2FontSharedFontConfig();
        FcPattern *all = FcPatternCreate();
        FcObjectSet *objects = FcObjectSetBuild(FC_POSTSCRIPT_NAME, FC_FILE, FC_INDEX, NULL);
        FcFontSet *fonts = FcFontList(config, all, objects);
        NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
        int i;

        for (i = 0; fonts != NULL && i < fonts->nfont; i++) {
            FcChar8 *name = NULL;
            FcChar8 *file = NULL;
            int faceIndex = 0;
            NSString *key;

            if (FcPatternGetString(fonts->fonts[i], FC_POSTSCRIPT_NAME, 0, &name) != FcResultMatch ||
                FcPatternGetString(fonts->fonts[i], FC_FILE, 0, &file) != FcResultMatch || name[0] == 0)
                continue;
            FcPatternGetInteger(fonts->fonts[i], FC_INDEX, 0, &faceIndex);

            key = [NSString stringWithUTF8String: (const char *) name];
            if (key != nil && [result objectForKey: key] == nil)
                [result setObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSString stringWithUTF8String: (const char *) file], @"file",
                                            [NSNumber numberWithInt: faceIndex], @"index", nil]
                           forKey: key];
        }

        if (fonts != NULL)
            FcFontSetDestroy(fonts);
        FcObjectSetDestroy(objects);
        FcPatternDestroy(all);
        index = result;
    });
    return index;
}

// The font file and the face in it for a name as macOS apps use them: a PostScript name
// ("Menlo-Bold", "Helvetica"), a family name or a fontconfig pattern (with a colon).
static NSString *O2FontFreeTypePathForName(NSString *name, int *index) {
    FcConfig *config = O2FontSharedFontConfig();
    FcPattern *pattern;
    FcPattern *match;
    FcResult result;
    FcChar8 *file = NULL;
    NSString *path = nil;

    *index = 0;

    if ([name length] == 0 || [name rangeOfString: @":"].location != NSNotFound) {
        pattern = FcNameParse((const FcChar8 *) [name UTF8String]);
    } else {
        // a font with exactly this PostScript name
        NSDictionary *exact = [O2FontPostScriptNameIndex() objectForKey: name];

        if (exact != nil) {
            *index = [[exact objectForKey: @"index"] intValue];
            return [exact objectForKey: @"file"];
        }

        // otherwise the family before the dash, with the style after it
        NSString *family = name;
        NSString *style = @"";
        NSRange dash = [name rangeOfString: @"-" options: NSBackwardsSearch];

        if (dash.location != NSNotFound && dash.location > 0) {
            family = [name substringToIndex: dash.location];
            style = [[name substringFromIndex: NSMaxRange(dash)] lowercaseString];
        }

        pattern = FcPatternCreate();
        FcPatternAddString(pattern, FC_FAMILY, (const FcChar8 *) [family UTF8String]);
        O2FontAddFallbackFamilies(pattern, family);

        if ([style rangeOfString: @"bold"].location != NSNotFound ||
            [style rangeOfString: @"black"].location != NSNotFound ||
            [style rangeOfString: @"heavy"].location != NSNotFound)
            FcPatternAddInteger(pattern, FC_WEIGHT, FC_WEIGHT_BOLD);
        else if ([style rangeOfString: @"semibold"].location != NSNotFound ||
                 [style rangeOfString: @"medium"].location != NSNotFound)
            FcPatternAddInteger(pattern, FC_WEIGHT, FC_WEIGHT_MEDIUM);
        else if ([style rangeOfString: @"light"].location != NSNotFound ||
                 [style rangeOfString: @"thin"].location != NSNotFound)
            FcPatternAddInteger(pattern, FC_WEIGHT, FC_WEIGHT_LIGHT);
        if ([style rangeOfString: @"italic"].location != NSNotFound ||
            [style rangeOfString: @"oblique"].location != NSNotFound)
            FcPatternAddInteger(pattern, FC_SLANT, FC_SLANT_ITALIC);
    }

    if (pattern == NULL)
        return nil;

    FcConfigSubstitute(config, pattern, FcMatchPattern);
    FcDefaultSubstitute(pattern);
    match = FcFontMatch(config, pattern, &result);
    FcPatternDestroy(pattern);
    if (match == NULL)
        return nil;

    if (FcPatternGetString(match, FC_FILE, 0, &file) == FcResultMatch) {
        path = [NSString stringWithUTF8String: (const char *) file];
        FcPatternGetInteger(match, FC_INDEX, 0, index);
    }
    FcPatternDestroy(match);
    return path;
}

- (instancetype) initWithFontName: (NSString *) name {
    self = [super initWithFontName: name];

    int index = 0;
    NSString *filename = O2FontFreeTypePathForName(name, &index);
    if (filename == nil) {
        filename = O2FontFreeTypePathForName(@"", &index);
    }
    if (filename == nil) {
        NSLog(@"No font found for name %@", name);
        [self release];
        return nil;
    }

    FT_Face face;
    FT_Error error = O2FontFreeTypeNewFace([filename fileSystemRepresentation], index, &face);

    if (error != 0) {
        NSLog(@"FT_New_Face() = %d", error);
        [self release];
        return nil;
    }

    return [self initWithFace: face];
}

- (instancetype) initWithFace: (FT_Face) face {
    _face = face;
    _platformType = O2FontPlatformTypeFreeType;

    int i, numberOfCharMaps = face->num_charmaps;
    BOOL hasUnicode = FALSE;
    BOOL hasMacRoman = FALSE;

    for (i = 0; i < numberOfCharMaps; i++) {

        if (face->charmaps[i]->encoding == FT_ENCODING_UNICODE) {
            hasUnicode = TRUE;
        }
        if (face->charmaps[i]->encoding == FT_ENCODING_APPLE_ROMAN) {
            hasMacRoman = TRUE;
        }
    }
    if (hasUnicode) {
        _ftEncoding = FT_ENCODING_UNICODE;
    } else if (hasMacRoman) {
        _ftEncoding = FT_ENCODING_APPLE_ROMAN;
    } else {
        NSLog(@"encoding = %c %c %c %c", face->charmaps[0]->encoding >> 24,
              face->charmaps[0]->encoding >> 16,
              face->charmaps[0]->encoding >> 8, face->charmaps[0]->encoding);
        _ftEncoding = face->charmaps[0]->encoding;
    }

    if (FT_Select_Charmap(face, _ftEncoding) != 0) {
        NSLog(@"FT_Select_Charmap(%d) failed", _ftEncoding);
    }

    if (!(face->face_flags & FT_FACE_FLAG_SCALABLE)) {
        NSLog(@"FreeType font face is not scalable");
    }

    _unitsPerEm = (O2Float) face->units_per_EM;
    _ascent = face->ascender;
    _descent = face->descender;
    _leading = 0;
    _capHeight = face->height;
    _xHeight = face->height;
    _italicAngle = 0;
    _stemV = 0;
    _bbox.origin.x = face->bbox.xMin;
    _bbox.origin.y = face->bbox.yMin;
    _bbox.size.width = face->bbox.xMax - face->bbox.xMin;
    _bbox.size.height = face->bbox.yMax - face->bbox.yMin;
    _numberOfGlyphs = face->num_glyphs;
    _advances = NULL;
    return self;
}

- (void) dealloc {
    O2FontFreeTypeLock();
    FT_Done_Face(_face);
    O2FontFreeTypeUnlock();
    [_macRomanEncoding release];
    [_macExpertEncoding release];
    [_winAnsiEncoding release];
    [super dealloc];
}

- (FT_Face) face {
    return _face;
}

FT_Face O2FontFreeTypeFace(O2Font_freetype *self) {
    return self->_face;
}

- (void) fetchAdvances {
    O2FontFreeTypeLockScope();
    FT_Set_Char_Size(_face, 0, _unitsPerEm * 64, 72, 72);

    _advances = NSZoneMalloc(NULL, sizeof(NSInteger) * _numberOfGlyphs);

    for (O2Glyph glyph = 0; glyph < _numberOfGlyphs; glyph++) {
        FT_Load_Glyph(_face, glyph, FT_LOAD_DEFAULT);

        _advances[glyph] = _face->glyph->advance.x / (O2Float)(2 << 5);
    }
}

- (O2Glyph) glyphWithGlyphName: (NSString *) name {
    O2FontFreeTypeLockScope();
    return FT_Get_Name_Index(_face, (char *) [name cString]);
}

- (NSString *) copyGlyphNameForGlyph: (O2Glyph) glyph {
    O2FontFreeTypeLockScope();
    unsigned char buffer[100];
    if (FT_Get_Glyph_Name(_face, glyph, buffer, sizeof(buffer)) != 0) {
        return nil;
    }
    return [[NSString alloc] initWithUTF8String: (const char *) buffer];
}

- (void) getGlyphs: (O2Glyph *) glyphs
        forCodePoints: (uint16_t *) codes
               length: (NSInteger) length
{
    O2FontFreeTypeLockScope();
    for (int i = 0; i < length; i++) {
        glyphs[i] = FT_Get_Char_Index(_face, codes[i]);
    }
}

- (O2Encoding *) unicode_createEncodingForTextEncoding:
        (O2TextEncoding) encoding
{
    unichar unicode[256];
    O2Glyph glyphs[256];

    switch (encoding) {
    case kO2EncodingFontSpecific:
    case kO2EncodingMacRoman:
        if (_macRomanEncoding == nil) {
            O2EncodingGetMacRomanUnicode(unicode);
            [self getGlyphs: glyphs forCodePoints: unicode length: 256];
            _macRomanEncoding = [[O2Encoding alloc] initWithGlyphs: glyphs
                                                           unicode: unicode];
        }
        return [_macRomanEncoding retain];

    case kO2EncodingMacExpert:
        if (_macExpertEncoding == nil) {
            O2EncodingGetMacExpertUnicode(unicode);
            [self getGlyphs: glyphs forCodePoints: unicode length: 256];
            _macExpertEncoding = [[O2Encoding alloc] initWithGlyphs: glyphs
                                                            unicode: unicode];
        }
        return [_macExpertEncoding retain];

    case kO2EncodingWinAnsi:
        if (_winAnsiEncoding == nil) {
            O2EncodingGetWinAnsiUnicode(unicode);
            [self getGlyphs: glyphs forCodePoints: unicode length: 256];
            _winAnsiEncoding = [[O2Encoding alloc] initWithGlyphs: glyphs
                                                          unicode: unicode];
        }
        return [_winAnsiEncoding retain];

    default:
        return nil;
    }
    return nil;
}

- (O2Encoding *) MacRoman_createEncodingForTextEncoding:
        (O2TextEncoding) encoding
{

    uint16_t codes[256];
    O2Glyph glyphs[256];
    unichar unicode[256];

    if (_macRomanEncoding == nil) {

        if (encoding != kO2EncodingMacRoman &&
            encoding != kO2EncodingFontSpecific) {
            NSLog(@"font encoding is MacRoman, requesting encoding %d failed",
                  encoding);
        }

        for (int i = 0; i < 256; i++) {
            codes[i] = i;
        }

        [self getGlyphs: glyphs forCodePoints: codes length: 256];

        O2EncodingGetMacExpertUnicode(unicode);

        _macRomanEncoding = [[O2Encoding alloc] initWithGlyphs: glyphs
                                                       unicode: unicode];
    }

    return [_macRomanEncoding retain];
}

- (O2Encoding *) createEncodingForTextEncoding: (O2TextEncoding) encoding {
    if (_ftEncoding == FT_ENCODING_APPLE_ROMAN) {
        return [self MacRoman_createEncodingForTextEncoding: encoding];
    }

    return [self unicode_createEncodingForTextEncoding: encoding];
}

@end
#endif
