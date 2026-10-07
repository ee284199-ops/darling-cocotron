/* Internal CoreText font machinery shared between CTFont, CTFontDescriptor,
   CTFontCollection and CTFontManager.  Not part of the public framework headers. */

#ifndef CORETEXT_KTFONTDESCRIPTORINTERNAL_H
#define CORETEXT_KTFONTDESCRIPTORINTERNAL_H

#import <CoreText/CTFont.h>
#import <CoreText/CTFontDescriptor.h>
#import <CoreText/CTFontCollection.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSLock.h>
#import <Onyx2D/O2Font.h>
#import <Onyx2D/O2Font_freetype.h>

#include <fontconfig/fontconfig.h>

// private attribute keys (their values are NSObject/CFType objects)
extern const CFStringRef kKTFontFileIndexAttribute; // NSNumber, fontconfig face index (FC_INDEX)
extern const CFStringRef kKTFontDataAttribute;      // NSData, an in-memory font file

// defined in constants.c
extern const CFStringRef kCTFontSymbolicTrait;
extern const CFStringRef kCTFontWeightTrait;
extern const CFStringRef kCTFontWidthTrait;
extern const CFStringRef kCTFontSlantTrait;

@interface KTFontDescriptor : NSObject {
    NSDictionary *_attributes;
}

- initWithAttributes: (NSDictionary *)attributes;
- (NSDictionary *) attributes;

@end

// the process-wide lock guarding O2FontSharedFontConfig()
NSLock *KTFontFontConfigLock(void);

// Build a complete descriptor from a fontconfig pattern (which should carry
// FC_FILE/FC_INDEX/FC_FAMILY/...).  Returns a retained descriptor.
CTFontDescriptorRef KTFontDescriptorCreateWithFcPattern(FcPattern *pattern);

// Every font fontconfig knows about, as complete descriptors.
CFArrayRef KTFontDescriptorCreateFontDescriptorsForAllFonts(void);

// A descriptor that matches a PostScript/full/family name.
CTFontDescriptorRef KTFontDescriptorCreateWithFontName(CFStringRef name);

// Find fonts matching a descriptor.  Returns complete descriptors; never
// includes fontconfig's fallbacks.
CFArrayRef KTFontDescriptorCreateMatchingFontDescriptors(CTFontDescriptorRef descriptor, CFSetRef mandatoryAttributes);
CTFontDescriptorRef KTFontDescriptorCreateMatchingFontDescriptor(CTFontDescriptorRef descriptor, CFSetRef mandatoryAttributes);

// Find a font that covers the given Unicode character, starting from the given
// descriptor (which is used as a hint).  Returns a retained descriptor or NULL.
CTFontDescriptorRef KTFontDescriptorCreateForCharacter(CTFontDescriptorRef descriptor, uint32_t character);

// Create the concrete font for a descriptor: from in-memory data, from a
// file URL + face index, or by matching.  Returns NULL if none.
CGFontRef KTFontDescriptorCopyGraphicsFont(CTFontDescriptorRef descriptor);

// Look up a graphics font registered with CTFontManager by name.
CGFontRef KTFontManagerCopyGraphicsFontForName(CFStringRef name);

#endif