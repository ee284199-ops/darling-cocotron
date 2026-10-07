/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

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

#import <AppKit/NSDisplay.h>
#import <AppKit/NSPasteboard.h>
#import <Foundation/NSAttributedString.h>
#import <Foundation/NSURL.h>
#import <AppKit/NSRaise.h>

const NSPasteboardType NSPasteboardTypeString = @"NSStringPboardType";
const NSPasteboardType NSPasteboardTypePDF = @"NSPDFPboardType";
const NSPasteboardType NSPasteboardTypePNG = @"NSPDFPboardType";
const NSPasteboardType NSPasteboardTypeTIFF = @"NSTIFFPboardType";
const NSPasteboardType NSPasteboardTypeRTF = @"NSRTFPboardType";
const NSPasteboardType NSPasteboardTypeRTFD = @"NSRTFDPboardType";
const NSPasteboardType NSPasteboardTypeHTML = @"NSPasteboardTypeHTML";
const NSPasteboardType NSPasteboardTypeTabularText = @"NSTabularTextPboardType";
const NSPasteboardType NSPasteboardTypeFont = @"NSFontPboardType";
const NSPasteboardType NSPasteboardTypeRuler = @"NSRulerPboardType";
const NSPasteboardType NSPasteboardTypeURL = @"public.url";
const NSPasteboardType NSPasteboardTypeColor = @"NSColorPboardType";
const NSPasteboardType NSPasteboardTypeFileURL = @"public.file-url";
const NSPasteboardType NSPasteboardTypeMultipleTextSelection = @"com.apple.cocoa.pasteboard.multiple-text-selection";

const NSPasteboardType NSColorPboardType = @"NSColorPboardType";
const NSPasteboardType NSFileContentsPboardType = @"NSFileContentsPboardType";
const NSPasteboardType NSFilenamesPboardType = @"NSFilenamesPboardType";
const NSPasteboardType NSFontPboardType = @"NSFontPboardType";
const NSPasteboardType NSPDFPboardType = @"NSPDFPboardType";
const NSPasteboardType NSPICTPboardType = @"NSPICTPboardType";
const NSPasteboardType NSPostScriptPboardType = @"NSPostScriptPboardType";
const NSPasteboardType NSRTFDPboardType = @"NSRTFDPboardType";
const NSPasteboardType NSRTFPboardType = @"NSRTFPboardType";
const NSPasteboardType NSRulerPboardType = @"NSRulerPboardType";
const NSPasteboardType NSStringPboardType = @"NSStringPboardType";
const NSPasteboardType NSTabularTextPboardType = @"NSTabularTextPboardType";
const NSPasteboardType NSTIFFPboardType = @"NSTIFFPboardType";
const NSPasteboardType NSURLPboardType = @"NSURLPboardType";
const NSPasteboardType NSHTMLPboardType = @"Apple HTML pasteboard type";
const NSPasteboardType NSVCardPboardType = @"NSVCardPboardType";
const NSPasteboardType NSInkTextPboardType = @"Apple InkText pasteboard type";
const NSPasteboardType NSMultipleTextSelectionPboardType = @"Apple multiple text selection pasteboard type";

const NSPasteboardType NSFilesPromisePboardType =
        @"Apple files promise pasteboard type";

const NSPasteboardName NSPasteboardNameDrag = @"Apple CFPasteboard drag";
NSString *const NSPasteboardURLReadingFileURLsOnlyKey =
        @"NSPasteboardURLReadingFileURLsOnlyKey";

const NSPasteboardName NSDragPboard = @"NSDragPboard";
const NSPasteboardName NSFindPboard = @"NSFindPboard";
const NSPasteboardName NSFontPboard = @"NSFontPboard";
const NSPasteboardName NSGeneralPboard = @"NSGeneralPboard";
const NSPasteboardName NSRulerPboard = @"NSRulerPboard";

const NSPasteboardName NSPasteboardNameFind = @"Apple CFPasteboard find";
const NSPasteboardName NSPasteboardNameFont = @"Apple CFPasteboard font";
const NSPasteboardName NSPasteboardNameGeneral = @"Apple CFPasteboard general";

const NSPasteboardReadingOptionKey
        NSPasteboardURLReadingContentsConformToTypesKey =
                @"NSPasteboardURLReadingContentsConformToTypesKey";

@implementation NSPasteboard

+ (NSPasteboard *) generalPasteboard {
    return [self pasteboardWithName: NSGeneralPboard];
}

+ (NSPasteboard *) pasteboardWithName: (NSPasteboardName) name {
    return [[NSDisplay currentDisplay] pasteboardWithName: name];
}

- (NSPasteboardName) name {
    NSUnimplementedMethod();
    return nil;
}

- (NSInteger) changeCount {
    NSUnimplementedMethod();
    return 0;
}

- (NSInteger) clearContents {
    [self declareTypes: @[] owner: nil];

    return [self changeCount];
}

- (oneway void) releaseGlobally {
    NSUnimplementedMethod();
}

- (NSArray<NSPasteboardType> *) types {
    NSUnimplementedMethod();
    return nil;
}

- (NSPasteboardType) availableTypeFromArray: (NSArray<NSPasteboardType> *) types
{
    NSArray<NSPasteboardType> *available = [self types];
    for (NSPasteboardType type in types) {
        if ([available containsObject: type]) {
            return type;
        }
    }
    return nil;
}

- (NSData *) dataForType: (NSPasteboardType) type {
    NSUnimplementedMethod();
    return nil;
}

- (NSString *) stringForType: (NSPasteboardType) type {
    NSData *data = [self dataForType: type];

    return [[[NSString alloc] initWithData: data
                                  encoding: NSUnicodeStringEncoding]
            autorelease];
}

- (id) propertyListForType: (NSPasteboardType) type {
    NSData *data = [self dataForType: type];
    NSString *errorDesc = nil;
    id plist = [NSPropertyListSerialization
            propertyListFromData: data
                mutabilityOption: NSPropertyListImmutable
                          format: NULL
                errorDescription: &errorDesc];
    if (plist && errorDesc == nil) {
        return plist;
    }
    NSLog(@"propertyListForType: produced error: %@", errorDesc);
    return nil;
}

- (NSInteger) declareTypes: (NSArray<NSPasteboardType> *) types
                     owner: (id<NSPasteboardTypeOwner>) owner
{
    NSUnimplementedMethod();
    return 0;
}

- (NSInteger) addTypes: (NSArray<NSPasteboardType> *) types
                 owner: (id<NSPasteboardTypeOwner>) owner
{
    NSUnimplementedMethod();
    return 0;
}

- (BOOL) setData: (NSData *) data forType: (NSPasteboardType) type {
    NSUnimplementedMethod();
    return NO;
}

- (BOOL) setString: (NSString *) string forType: (NSPasteboardType) type {
    NSData *data = [string dataUsingEncoding: NSUnicodeStringEncoding];
    return [self setData: data forType: type];
}

- (BOOL) setPropertyList: (id) plist forType: (NSPasteboardType) type {
    NSString *errorDesc = nil;
    NSData *data = [NSPropertyListSerialization
            dataFromPropertyList: plist
                          format: NSPropertyListXMLFormat_v1_0
                errorDescription: &errorDesc];
    if (data && errorDesc == nil) {
        return [self setData: data forType: type];
    }
    NSLog(@"setPropertyList:forType: produced error: %@", errorDesc);
    return NO;
}

- (BOOL) canReadItemWithDataConformingToTypes: (NSArray<NSString *> *) types {
    if ([self availableTypeFromArray: types] != nil)
        return YES;

    // types only lists what this process put on the pasteboard; text that
    // another application owns has to be asked for
    if ([types containsObject: NSPasteboardTypeString])
        return [self stringForType: NSPasteboardTypeString] != nil;

    return NO;
}

// The pasteboard holds a single item, so this returns at most one object: the
// first class in classArray that can be made from the pasteboard's contents.
- (NSArray *) readObjectsForClasses: (NSArray<Class> *) classArray
                            options: (NSDictionary<NSPasteboardReadingOptionKey, id> *) options
{
    for (Class cls in classArray) {
        if ([cls isSubclassOfClass: [NSURL class]]) {
            NSString *string = [self stringForType: NSPasteboardTypeURL];
            NSURL *url = (string != nil) ? [NSURL URLWithString: string] : nil;

            if (url != nil)
                return [NSArray arrayWithObject: url];
        } else if ([cls isSubclassOfClass: [NSString class]]) {
            NSString *string = [self stringForType: NSPasteboardTypeString];

            if (string != nil)
                return [NSArray arrayWithObject: string];
        } else if ([cls isSubclassOfClass: [NSAttributedString class]]) {
            NSString *string = [self stringForType: NSPasteboardTypeString];

            if (string != nil)
                return [NSArray arrayWithObject: [[[NSAttributedString alloc] initWithString: string] autorelease]];
        }
    }

    return [NSArray array];
}

- (BOOL) canReadObjectForClasses: (NSArray<Class> *) classArray
                         options: (NSDictionary<NSPasteboardReadingOptionKey, id> *) options
{
    return [[self readObjectsForClasses: classArray options: options] count] > 0;
}

// Call clearContents first, like on macOS.
- (BOOL) writeObjects: (NSArray<id<NSPasteboardWriting>> *) objects {
    NSMutableDictionary *values = [NSMutableDictionary dictionary];

    // the pasteboard holds a single item: the first value of each type wins
    for (id object in objects) {
        if ([object isKindOfClass: [NSString class]]) {
            if (values[NSPasteboardTypeString] == nil)
                values[NSPasteboardTypeString] = object;
        } else if ([object isKindOfClass: [NSAttributedString class]]) {
            if (values[NSPasteboardTypeString] == nil)
                values[NSPasteboardTypeString] = [object string];
        } else if ([object isKindOfClass: [NSURL class]]) {
            NSString *string = [object absoluteString];

            if (values[NSPasteboardTypeURL] == nil)
                values[NSPasteboardTypeURL] = string;
            if (values[NSPasteboardTypeString] == nil)
                values[NSPasteboardTypeString] = string;
        } else if ([object respondsToSelector: @selector(writableTypesForPasteboard:)] &&
                   [object respondsToSelector: @selector(pasteboardPropertyListForType:)])
        {
            for (NSPasteboardType type in [object writableTypesForPasteboard: self]) {
                id value = [object pasteboardPropertyListForType: type];

                if (value != nil && values[type] == nil)
                    values[type] = value;
            }
        }
    }

    BOOL wrote = NO;

    for (NSPasteboardType type in values) {
        id value = values[type];

        if ([value isKindOfClass: [NSData class]])
            wrote |= [self setData: value forType: type];
        else if ([value isKindOfClass: [NSString class]])
            wrote |= [self setString: value forType: type];
        else
            wrote |= [self setPropertyList: value forType: type];
    }

    return wrote;
}

@end
