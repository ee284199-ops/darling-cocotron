/* Copyright (c) 2026 Darling Developers

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

#import <Foundation/NSCoder.h>

@class NSData, NSMutableDictionary;

/*
 * Decodes compiled nibs in the "NIBArchive" format that Xcode has produced for years,
 * both as a .nib file and as the keyedobjects-*.nib files inside a .nib directory.
 * It's a flattened keyed archive: the same initWithCoder: code that reads keyed nibs
 * reads these, through the keyed NSCoder methods implemented here.
 *
 * Like NSKeyedUnarchiver, it tells its delegate about every decoded object
 * (unarchiver:didDecodeObject:, unarchiver:willReplaceObject:withObject:) and
 * can substitute classes for class names.
 */
@interface NSNibArchiveUnarchiver : NSCoder {
    NSData *_data;
    id _delegate;
    NSMutableDictionary *_classMap;
    NSMutableDictionary *_keyIndexes;

    void *_objects;
    unsigned _objectCount;
    void *_values;
    unsigned _valueCount;
    NSString **_keys;
    unsigned _keyCount;
    NSString **_classNames;
    unsigned _classNameCount;

    id *_decoded;
    unsigned char *_states;
    unsigned _current;
    unsigned _emptyKey;
    unsigned _inlinedKey;
}

+ (BOOL) isNibArchive: (NSData *) data;

- initForReadingWithData: (NSData *) data;

- delegate;
- (void) setDelegate: delegate;
- (void) setClass: (Class) cls forClassName: (NSString *) className;
- (void) replaceObject: object withObject: replacement;

// the archive's root object (the one that holds "IB.objectdata" in a nib)
- (id) decodeRootObject;

@end
