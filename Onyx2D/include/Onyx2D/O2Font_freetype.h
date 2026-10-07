#import <Onyx2D/O2Defines_FreeType.h>
#import <Onyx2D/O2Font.h>

#ifdef FREETYPE_PRESENT

#ifdef DARLING
#define __linux__
#endif

#import <ft2build.h>
#import FT_FREETYPE_H
#import FT_RENDER_H

#import <fontconfig/fontconfig.h>

#ifdef DARLING
#undef __linux__
#endif

@interface O2Font_freetype : O2Font {
    FT_Face _face;
    FT_Encoding _ftEncoding;
    O2Encoding *_macRomanEncoding;
    O2Encoding *_macExpertEncoding;
    O2Encoding *_winAnsiEncoding;
}

- (instancetype) initWithFace: (FT_Face) face;
- (instancetype) initWithDataProvider: (O2DataProviderRef) provider;

- (FT_Face) face;

FT_Face O2FontFreeTypeFace(O2Font_freetype *self);

FT_Library O2FontSharedFreeTypeLibrary();
FcConfig *O2FontSharedFontConfig();

// Like FT_New_Face, but every face of a file shares one read-only mapping of it.
FT_Error O2FontFreeTypeNewFace(const char *path, FT_Long index, FT_Face *face);

// The fontconfig family ("monospace", "sans-serif", "serif") that stands in for a macOS font
// family Linux systems don't have, or NULL.
const char *O2FontGenericFamilyForFamily(NSString *family);

// Adds the families that stand in for a macOS family (if it is one) to a fontconfig pattern,
// after the family itself.
void O2FontAddFallbackFamilies(FcPattern *pattern, NSString *family);

@end

// FreeType faces (and the library they come from) must not be used by two threads at once,
// and the faces are shared by every font of one name and size. Everything that touches a face
// holds this lock (it is recursive). O2FontFreeTypeLockScope() holds it until the end of the
// enclosing block.
void O2FontFreeTypeLock(void);
void O2FontFreeTypeUnlock(void);

static inline void O2FontFreeTypeUnlockAtScopeEnd(int *unused) {
    O2FontFreeTypeUnlock();
}

#define O2FontFreeTypeLockScope()                                                      \
    O2FontFreeTypeLock();                                                              \
    int _o2FreeTypeLockScope __attribute__((cleanup(O2FontFreeTypeUnlockAtScopeEnd), unused)) = 0

#endif
