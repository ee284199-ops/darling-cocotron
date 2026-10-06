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

#import "NSNibArchiveUnarchiver.h"
#import <AppKit/NSRaise.h>
#import <Foundation/Foundation.h>

#include <stdlib.h>
#include <string.h>

/*
 * The format: the magic "NIBArchive", ten little-endian 32-bit integers
 * (two format versions, then the count and offset of the objects, keys,
 * values and class names), and those four tables.
 *
 *   object:     class name index, index of its first value, value count (varints)
 *   key:        length (varint), UTF-8 bytes
 *   value:      key index (varint), type (byte), then the payload for the type
 *   class name: length (varint), count of extra 32-bit integers (varint),
 *               the extras, the name with a terminating NUL
 *
 * Varints carry 7 bits per byte, least significant first; the byte with the
 * high bit set is the last one.
 */

enum {
    NIBValueInt8 = 0,
    NIBValueInt16 = 1,
    NIBValueInt32 = 2,
    NIBValueInt64 = 3,
    NIBValueFalse = 4,
    NIBValueTrue = 5,
    NIBValueFloat = 6,
    NIBValueDouble = 7,
    NIBValueData = 8,
    NIBValueNil = 9,
    NIBValueObject = 10,
};

typedef struct {
    unsigned classIndex;
    unsigned firstValue;
    unsigned valueCount;
} NIBObject;

typedef struct {
    unsigned key;
    unsigned type;
    union {
        int64_t integer;
        double real;
        unsigned object;
        struct {
            const uint8_t *bytes;
            unsigned length;
        } data;
    };
} NIBValue;

static NSString *const NIBArchiveMagic = @"NIBArchive";

// what _decoded[i] holds: nothing yet; a borrowed pointer to the object whose decoding is
// under way (its allocated instance, or what replaceObject:withObject: put in its place);
// or the finished object, which the table owns
enum {
    NIBObjectUndecoded = 0,
    NIBObjectDecoding = 1,
    NIBObjectDecoded = 2,
};

@interface NSNibArchiveUnarchiver ()
- (BOOL) parse;
- (unsigned) keyIndexForKey: (NSString *) key;
- (NIBValue *) nibValueForKey: (NSString *) key;
- (Class) classForObjectAtIndex: (unsigned) index;
- (NSMutableArray *) inlinedElementsOfObjectAtIndex: (unsigned) index;
- (NSData *) bytesValueOfObjectAtIndex: (unsigned) index key: (NSString *) key;
- (id) newSpecialObjectAtIndex: (unsigned) index className: (NSString *) name;
- (id) objectAtIndex: (unsigned) index;
- (id) objectForValue: (NIBValue *) value;
@end

@implementation NSNibArchiveUnarchiver

+ (BOOL) isNibArchive: (NSData *) data {
    return [data length] >= 50 && memcmp([data bytes], "NIBArchive", 10) == 0;
}

static BOOL readUInt32(const uint8_t *bytes, NSUInteger length,
                       NSUInteger *position, uint32_t *result)
{
    if (*position + 4 > length)
        return NO;
    *result = bytes[*position] | (bytes[*position + 1] << 8) |
              (bytes[*position + 2] << 16) |
              ((uint32_t) bytes[*position + 3] << 24);
    *position += 4;
    return YES;
}

static BOOL readVarint(const uint8_t *bytes, NSUInteger length,
                       NSUInteger *position, unsigned *result)
{
    unsigned value = 0;
    int shift = 0;

    while (*position < length && shift < 32) {
        uint8_t byte = bytes[(*position)++];
        value |= (unsigned) (byte & 0x7f) << shift;
        shift += 7;
        if (byte & 0x80) {
            *result = value;
            return YES;
        }
    }
    return NO;
}

- (BOOL) parse {
    const uint8_t *bytes = [_data bytes];
    NSUInteger length = [_data length];
    NSUInteger position = 10;
    uint32_t header[10];
    unsigned i;

    for (i = 0; i < 10; i++)
        if (!readUInt32(bytes, length, &position, &header[i]))
            return NO;

    _objectCount = header[2];
    _keyCount = header[4];
    _valueCount = header[6];
    _classNameCount = header[8];

    // every entry takes at least one byte, which bounds the allocations below
    if (_objectCount > length || _keyCount > length || _valueCount > length ||
        _classNameCount > length)
        return NO;

    NIBObject *objects = calloc(_objectCount ? _objectCount : 1, sizeof(NIBObject));
    NIBValue *values = calloc(_valueCount ? _valueCount : 1, sizeof(NIBValue));
    _objects = objects;
    _values = values;
    _keys = calloc(_keyCount ? _keyCount : 1, sizeof(NSString *));
    _classNames = calloc(_classNameCount ? _classNameCount : 1, sizeof(NSString *));
    _decoded = calloc(_objectCount ? _objectCount : 1, sizeof(id));
    _states = calloc(_objectCount ? _objectCount : 1, 1);

    position = header[3];
    for (i = 0; i < _objectCount; i++) {
        if (!readVarint(bytes, length, &position, &objects[i].classIndex) ||
            !readVarint(bytes, length, &position, &objects[i].firstValue) ||
            !readVarint(bytes, length, &position, &objects[i].valueCount))
            return NO;
        if (objects[i].classIndex >= _classNameCount ||
            (unsigned long long) objects[i].firstValue + objects[i].valueCount > _valueCount)
            return NO;
    }

    position = header[5];
    for (i = 0; i < _keyCount; i++) {
        unsigned keyLength;
        if (!readVarint(bytes, length, &position, &keyLength) ||
            position + keyLength > length)
            return NO;
        _keys[i] = [[NSString alloc] initWithBytes: bytes + position
                                            length: keyLength
                                          encoding: NSUTF8StringEncoding];
        if (_keys[i] == nil)
            _keys[i] = [@"" retain];
        position += keyLength;
    }

    position = header[7];
    for (i = 0; i < _valueCount; i++) {
        NIBValue *value = &values[i];

        if (!readVarint(bytes, length, &position, &value->key) ||
            value->key >= _keyCount || position >= length)
            return NO;
        value->type = bytes[position++];

        switch (value->type) {
        case NIBValueInt8:
            if (position + 1 > length)
                return NO;
            value->integer = (int8_t) bytes[position];
            position += 1;
            break;
        case NIBValueInt16:
            if (position + 2 > length)
                return NO;
            value->integer = (int16_t) (bytes[position] | (bytes[position + 1] << 8));
            position += 2;
            break;
        case NIBValueInt32:
        case NIBValueObject: {
            uint32_t word;
            if (!readUInt32(bytes, length, &position, &word))
                return NO;
            if (value->type == NIBValueObject) {
                if (word >= _objectCount)
                    return NO;
                value->object = word;
            } else
                value->integer = (int32_t) word;
            break;
        }
        case NIBValueInt64: {
            uint32_t low, high;
            if (!readUInt32(bytes, length, &position, &low) ||
                !readUInt32(bytes, length, &position, &high))
                return NO;
            value->integer = (int64_t) (((uint64_t) high << 32) | low);
            break;
        }
        case NIBValueFalse:
        case NIBValueTrue:
        case NIBValueNil:
            break;
        case NIBValueFloat: {
            uint32_t word;
            float real;
            if (!readUInt32(bytes, length, &position, &word))
                return NO;
            memcpy(&real, &word, sizeof(real));
            value->real = real;
            break;
        }
        case NIBValueDouble: {
            uint32_t low, high;
            uint64_t word;
            if (!readUInt32(bytes, length, &position, &low) ||
                !readUInt32(bytes, length, &position, &high))
                return NO;
            word = ((uint64_t) high << 32) | low;
            memcpy(&value->real, &word, sizeof(value->real));
            break;
        }
        case NIBValueData: {
            unsigned dataLength;
            if (!readVarint(bytes, length, &position, &dataLength) ||
                position + dataLength > length)
                return NO;
            value->data.bytes = bytes + position;
            value->data.length = dataLength;
            position += dataLength;
            break;
        }
        default:
            NSLog(@"NIBArchive: unknown value type %u", value->type);
            return NO;
        }
    }

    position = header[9];
    for (i = 0; i < _classNameCount; i++) {
        unsigned nameLength, extraCount;
        if (!readVarint(bytes, length, &position, &nameLength) ||
            !readVarint(bytes, length, &position, &extraCount))
            return NO;
        // the extras aren't needed to decode
        if (position + 4ULL * extraCount + nameLength > length)
            return NO;
        position += 4 * extraCount;
        while (nameLength > 0 && bytes[position + nameLength - 1] == 0)
            nameLength--;
        _classNames[i] = [[NSString alloc] initWithBytes: bytes + position
                                                  length: nameLength
                                                encoding: NSUTF8StringEncoding];
        if (_classNames[i] == nil)
            _classNames[i] = [@"" retain];
        position += nameLength;
        while (position < length && bytes[position] == 0)
            position++;
    }

    _keyIndexes = [[NSMutableDictionary alloc] initWithCapacity: _keyCount];
    for (i = 0; i < _keyCount; i++)
        if ([_keyIndexes objectForKey: _keys[i]] == nil)
            [_keyIndexes setObject: [NSNumber numberWithUnsignedInt: i]
                            forKey: _keys[i]];

    _emptyKey = [self keyIndexForKey: @"UINibEncoderEmptyKey"];
    _inlinedKey = [self keyIndexForKey: @"NSInlinedValue"];
    return YES;
}

- initForReadingWithData: (NSData *) data {
    [super init];
    _data = [data copy];
    _classMap = [NSMutableDictionary new];
    _current = 0;

    if (![[self class] isNibArchive: _data] || ![self parse]) {
        NSLog(@"NIBArchive: the data is not a valid NIBArchive");
        [self release];
        return nil;
    }
    return self;
}

- (void) dealloc {
    unsigned i;

    for (i = 0; i < _objectCount && _decoded != NULL && _states != NULL; i++)
        if (_states[i] == NIBObjectDecoded)
            [_decoded[i] release];
    for (i = 0; i < _keyCount && _keys != NULL; i++)
        [_keys[i] release];
    for (i = 0; i < _classNameCount && _classNames != NULL; i++)
        [_classNames[i] release];

    free(_decoded);
    free(_states);
    free(_keys);
    free(_classNames);
    free(_objects);
    free(_values);
    [_keyIndexes release];
    [_classMap release];
    [_data release];
    [super dealloc];
}

- (void) setDelegate: delegate {
    _delegate = delegate;
}

- delegate {
    return _delegate;
}

- (void) setClass: (Class) cls forClassName: (NSString *) className {
    [_classMap setObject: cls forKey: className];
}

// like NSKeyedUnarchiver's: later references to `object` get `replacement`
- (void) replaceObject: object withObject: replacement {
    unsigned i;

    if (object == replacement)
        return;

    for (i = 0; i < _objectCount; i++) {
        if (_decoded[i] != object)
            continue;

        if (_delegate != nil &&
            [_delegate respondsToSelector: @selector(unarchiver:willReplaceObject:withObject:)])
            [_delegate unarchiver: (id) self willReplaceObject: object withObject: replacement];

        if (_states[i] == NIBObjectDecoded) {
            _decoded[i] = [replacement retain];
            [object release];
        } else {
            // still being decoded (an NSClassSwapper standing in for the real object,
            // say): the table doesn't own it yet
            _decoded[i] = replacement;
        }
        return;
    }
}

- (BOOL) allowsKeyedCoding {
    return YES;
}

- (BOOL) requiresSecureCoding {
    return NO;
}

- (unsigned) keyIndexForKey: (NSString *) key {
    NSNumber *index = [_keyIndexes objectForKey: key];
    return index == nil ? (unsigned) -1 : [index unsignedIntValue];
}

// the value for `key` in the object being decoded
- (NIBValue *) nibValueForKey: (NSString *) key {
    NIBObject *object = &((NIBObject *) _objects)[_current];
    NIBValue *values = _values;
    unsigned keyIndex = [self keyIndexForKey: key];
    unsigned i;

    if (keyIndex == (unsigned) -1)
        return NULL;

    for (i = 0; i < object->valueCount; i++)
        if (values[object->firstValue + i].key == keyIndex)
            return &values[object->firstValue + i];
    return NULL;
}

- (BOOL) containsValueForKey: (NSString *) key {
    return [self nibValueForKey: key] != NULL;
}

- (Class) classForObjectAtIndex: (unsigned) index {
    NSString *name = _classNames[((NIBObject *) _objects)[index].classIndex];
    Class cls = [_classMap objectForKey: name];

    if (cls == Nil)
        cls = NSClassFromString(name);
    return cls;
}

// the decoded values for UINibEncoderEmptyKey, which is how collections store their elements
- (NSMutableArray *) inlinedElementsOfObjectAtIndex: (unsigned) index {
    NIBObject *object = &((NIBObject *) _objects)[index];
    NIBValue *values = _values;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity: object->valueCount];
    unsigned i;

    for (i = 0; i < object->valueCount; i++) {
        NIBValue *value = &values[object->firstValue + i];
        id element;

        if (value->key != _emptyKey)
            continue;
        element = [self objectForValue: value];
        [result addObject: element ? element : [NSNull null]];
    }
    return result;
}

- (NSData *) bytesValueOfObjectAtIndex: (unsigned) index key: (NSString *) key {
    unsigned saved = _current;
    NIBValue *value;
    NSData *result = nil;

    _current = index;
    value = [self nibValueForKey: key];
    if (value != NULL && value->type == NIBValueData)
        result = [NSData dataWithBytes: value->data.bytes length: value->data.length];
    _current = saved;
    return result;
}

// objects that NIBArchive encodes differently from their initWithCoder:
- (id) newSpecialObjectAtIndex: (unsigned) index className: (NSString *) name {
    unsigned saved = _current;
    id result = nil;

    if ([name isEqualToString: @"NSString"] ||
        [name isEqualToString: @"NSLocalizableString"] ||
        [name isEqualToString: @"NSMutableString"]) {
        NSData *bytes = [self bytesValueOfObjectAtIndex: index key: @"NS.bytes"];
        Class cls = [name isEqualToString: @"NSMutableString"] ? [NSMutableString class]
                                                               : [NSString class];
        result = [[cls alloc] initWithData: bytes ? bytes : [NSData data]
                                  encoding: NSUTF8StringEncoding];
        if (result == nil)
            result = [[cls alloc] initWithString: @""];
        return result;
    }

    if ([name isEqualToString: @"NSData"] || [name isEqualToString: @"NSMutableData"]) {
        NSData *bytes = [self bytesValueOfObjectAtIndex: index key: @"NS.bytes"];
        Class cls = [name isEqualToString: @"NSMutableData"] ? [NSMutableData class]
                                                             : [NSData class];
        return [[cls alloc] initWithData: bytes ? bytes : [NSData data]];
    }

    if ([name isEqualToString: @"NSNumber"]) {
        NIBValue *value;
        _current = index;
        if ((value = [self nibValueForKey: @"NS.intval"]) != NULL ||
            (value = [self nibValueForKey: @"NS.boolval"]) != NULL ||
            (value = [self nibValueForKey: @"NS.dblval"]) != NULL ||
            (value = [self nibValueForKey: @"NS.floatval"]) != NULL) {
            switch (value->type) {
            case NIBValueFalse:
            case NIBValueTrue:
                result = [[NSNumber alloc] initWithBool: value->type == NIBValueTrue];
                break;
            case NIBValueFloat:
            case NIBValueDouble:
                result = [[NSNumber alloc] initWithDouble: value->real];
                break;
            case NIBValueInt8:
            case NIBValueInt16:
            case NIBValueInt32:
            case NIBValueInt64:
                result = [[NSNumber alloc] initWithLongLong: value->integer];
                break;
            }
        }
        _current = saved;
        return result ? result : [[NSNumber alloc] initWithInt: 0];
    }

    BOOL inlined = NO;
    _current = index;
    {
        NIBValue *value = [self nibValueForKey: @"NSInlinedValue"];
        inlined = value != NULL && value->type == NIBValueTrue;
    }
    _current = saved;

    if (!inlined)
        return nil;

    if ([name isEqualToString: @"NSArray"] || [name isEqualToString: @"NSMutableArray"]) {
        NSMutableArray *elements = [self inlinedElementsOfObjectAtIndex: index];
        Class cls = [name isEqualToString: @"NSMutableArray"] ? [NSMutableArray class]
                                                              : [NSArray class];
        return [[cls alloc] initWithArray: elements];
    }

    if ([name isEqualToString: @"NSSet"] || [name isEqualToString: @"NSMutableSet"]) {
        NSMutableArray *elements = [self inlinedElementsOfObjectAtIndex: index];
        Class cls = [name isEqualToString: @"NSMutableSet"] ? [NSMutableSet class]
                                                            : [NSSet class];
        return [[cls alloc] initWithArray: elements];
    }

    if ([name isEqualToString: @"NSOrderedSet"] ||
        [name isEqualToString: @"NSMutableOrderedSet"]) {
        NSMutableArray *elements = [self inlinedElementsOfObjectAtIndex: index];
        Class cls = [name isEqualToString: @"NSMutableOrderedSet"]
                            ? [NSMutableOrderedSet class]
                            : [NSOrderedSet class];
        return [[cls alloc] initWithArray: elements];
    }

    if ([name isEqualToString: @"NSDictionary"] ||
        [name isEqualToString: @"NSMutableDictionary"]) {
        // keys and values alternate
        NSMutableArray *elements = [self inlinedElementsOfObjectAtIndex: index];
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        NSUInteger i;

        for (i = 0; i + 1 < [elements count]; i += 2)
            [dictionary setObject: [elements objectAtIndex: i + 1]
                           forKey: [elements objectAtIndex: i]];
        if ([name isEqualToString: @"NSMutableDictionary"])
            return [dictionary retain];
        return [[NSDictionary alloc] initWithDictionary: dictionary];
    }

    return nil;
}

- (id) objectAtIndex: (unsigned) index {
    id object;
    NSString *name;
    Class cls;
    unsigned saved;

    if (_states[index] == NIBObjectDecoded)
        return _decoded[index];
    if (_states[index] == NIBObjectDecoding) {
        // a reference back to an object whose decoding is under way: like NSKeyedUnarchiver,
        // hand out its allocated instance (collections and strings don't have one yet)
        if (_decoded[index] == nil)
            NSLog(@"NIBArchive: object %u refers back to itself while it's decoded", index);
        return _decoded[index];
    }

    name = _classNames[((NIBObject *) _objects)[index].classIndex];
    _states[index] = NIBObjectDecoding;
    _decoded[index] = nil;

    object = [self newSpecialObjectAtIndex: index className: name];
    if (object == nil) {
        cls = [self classForObjectAtIndex: index];
        if (cls == Nil) {
            NSLog(@"NIBArchive: no class %@ to decode an object with", name);
            _states[index] = NIBObjectDecoded;
            return nil;
        }

        object = [cls allocWithZone: NULL];
        _decoded[index] = object;

        saved = _current;
        _current = index;
        id initialized = [object initWithCoder: self];
        _current = saved;

        if (initialized != object) {
            if (initialized != nil && object != nil && _delegate != nil &&
                [_delegate respondsToSelector: @selector(unarchiver:willReplaceObject:withObject:)])
                [_delegate unarchiver: (id) self willReplaceObject: object withObject: initialized];
            // initWithCoder: released the original and returned a retained replacement
            object = initialized;
        }

        if (object != nil) {
            id awakened = [object awakeAfterUsingCoder: self];
            if (awakened != object) {
                if (awakened != nil && _delegate != nil &&
                    [_delegate respondsToSelector: @selector(unarchiver:willReplaceObject:withObject:)])
                    [_delegate unarchiver: (id) self willReplaceObject: object withObject: awakened];
                // likewise, awakeAfterUsingCoder: released the original and retained the replacement
                object = awakened;
            }
        }
    }

    if (object != nil && _delegate != nil &&
        [_delegate respondsToSelector: @selector(unarchiver:didDecodeObject:)]) {
        id replacement = [_delegate unarchiver: (id) self didDecodeObject: object];
        if (replacement != object) {
            [replacement retain];
            [object release];
            object = replacement;
        }
    }

    _decoded[index] = object;
    _states[index] = NIBObjectDecoded;
    return object;
}

- (id) objectForValue: (NIBValue *) value {
    switch (value->type) {
    case NIBValueObject:
        return [self objectAtIndex: value->object];
    case NIBValueNil:
        return nil;
    case NIBValueData:
        return [NSData dataWithBytes: value->data.bytes length: value->data.length];
    case NIBValueFalse:
        return [NSNumber numberWithBool: NO];
    case NIBValueTrue:
        return [NSNumber numberWithBool: YES];
    case NIBValueFloat:
    case NIBValueDouble:
        return [NSNumber numberWithDouble: value->real];
    default:
        return [NSNumber numberWithLongLong: value->integer];
    }
}

- (id) decodeObjectForKey: (NSString *) key {
    NIBValue *value = [self nibValueForKey: key];

    if (value == NULL)
        return nil;
    return [self objectForValue: value];
}

- (id) decodeObjectOfClass: (Class) cls forKey: (NSString *) key {
    return [self decodeObjectForKey: key];
}

- (id) decodeObjectOfClasses: (NSSet *) classes forKey: (NSString *) key {
    return [self decodeObjectForKey: key];
}

- (id) decodeTopLevelObjectForKey: (NSString *) key error: (NSError **) error {
    return [self decodeObjectForKey: key];
}

- (id) decodeRootObject {
    if (_objectCount == 0)
        return nil;
    return [self objectAtIndex: 0];
}

static int64_t integerValue(NIBValue *value) {
    if (value == NULL)
        return 0;
    switch (value->type) {
    case NIBValueTrue:
        return 1;
    case NIBValueFloat:
    case NIBValueDouble:
        return (int64_t) value->real;
    case NIBValueInt8:
    case NIBValueInt16:
    case NIBValueInt32:
    case NIBValueInt64:
        return value->integer;
    default:
        return 0;
    }
}

static double realValue(NIBValue *value) {
    if (value == NULL)
        return 0;
    switch (value->type) {
    case NIBValueFloat:
    case NIBValueDouble:
        return value->real;
    default:
        return (double) integerValue(value);
    }
}

- (BOOL) decodeBoolForKey: (NSString *) key {
    return integerValue([self nibValueForKey: key]) != 0;
}

- (int) decodeIntForKey: (NSString *) key {
    return (int) integerValue([self nibValueForKey: key]);
}

- (int32_t) decodeInt32ForKey: (NSString *) key {
    return (int32_t) integerValue([self nibValueForKey: key]);
}

- (int64_t) decodeInt64ForKey: (NSString *) key {
    return integerValue([self nibValueForKey: key]);
}

- (NSInteger) decodeIntegerForKey: (NSString *) key {
    return (NSInteger) integerValue([self nibValueForKey: key]);
}

- (float) decodeFloatForKey: (NSString *) key {
    return (float) realValue([self nibValueForKey: key]);
}

- (double) decodeDoubleForKey: (NSString *) key {
    return realValue([self nibValueForKey: key]);
}

- (const uint8_t *) decodeBytesForKey: (NSString *) key
                       returnedLength: (NSUInteger *) lengthp
{
    NIBValue *value = [self nibValueForKey: key];

    if (value == NULL || value->type != NIBValueData) {
        if (lengthp != NULL)
            *lengthp = 0;
        return NULL;
    }
    if (lengthp != NULL)
        *lengthp = value->data.length;
    return value->data.bytes;
}

// geometry is stored as strings, like in keyed archives
- (NSPoint) decodePointForKey: (NSString *) key {
    id string = [self decodeObjectForKey: key];
    return [string isKindOfClass: [NSString class]] ? NSPointFromString(string) : NSZeroPoint;
}

- (NSSize) decodeSizeForKey: (NSString *) key {
    id string = [self decodeObjectForKey: key];
    return [string isKindOfClass: [NSString class]] ? NSSizeFromString(string) : NSZeroSize;
}

- (NSRect) decodeRectForKey: (NSString *) key {
    id string = [self decodeObjectForKey: key];
    return [string isKindOfClass: [NSString class]] ? NSRectFromString(string) : NSZeroRect;
}

- (NSInteger) versionForClassName: (NSString *) className {
    return 0;
}

@end
