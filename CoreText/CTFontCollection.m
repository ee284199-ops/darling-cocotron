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

#import <CoreText/CTFontCollection.h>
#import "KTFontDescriptorInternal.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNumber.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

const CFStringRef kCTFontCollectionRemoveDuplicatesOption = CFSTR("NSFontCollectionRemoveDuplicates");

@interface KTFontCollection : NSObject {
    NSArray *_queryDescriptors;
    NSDictionary *_options;
}

- initWithQueryDescriptors: (NSArray *)queryDescriptors options: (NSDictionary *)options;

- (NSArray *) queryDescriptors;
- (NSDictionary *) options;

@end

@implementation KTFontCollection

- initWithQueryDescriptors: (NSArray *)queryDescriptors options: (NSDictionary *)options {
    _queryDescriptors = [queryDescriptors retain];
    _options = [options copy];
    return self;
}

- (void) dealloc {
    [_queryDescriptors release];
    [_options release];
    [super dealloc];
}

- (NSArray *) queryDescriptors {
    return _queryDescriptors;
}

- (NSDictionary *) options {
    return _options;
}

// what CFGetTypeID() asks Objective-C objects for
- (CFTypeID) _cfTypeID {
    return CTFontCollectionGetTypeID();
}

@end

static CFArrayRef KTCollectionCopyDescriptors(KTFontCollection *collection) {
    NSArray *queries = [collection queryDescriptors];
    NSDictionary *options = [collection options];
    NSMutableArray *descriptors;

    if (queries == nil || [queries count] == 0) {
        NSArray *all = (NSArray *) KTFontDescriptorCreateFontDescriptorsForAllFonts();
        descriptors = [NSMutableArray arrayWithArray: all];
        [all release];
    } else {
        descriptors = [NSMutableArray array];
        for (id query in queries) {
            CFArrayRef matches = KTFontDescriptorCreateMatchingFontDescriptors((CTFontDescriptorRef) query, NULL);
            if (matches != NULL) {
                [descriptors addObjectsFromArray: (NSArray *) matches];
                CFRelease(matches);
            }
        }
    }

    if ([[options objectForKey: (NSString *) kCTFontCollectionRemoveDuplicatesOption] boolValue]) {
        NSMutableArray *unique = [NSMutableArray array];
        NSMutableSet *seen = [NSMutableSet set];

        for (id descriptor in descriptors) {
            NSDictionary *attributes = [(KTFontDescriptor *) descriptor attributes];
            NSString *name = [attributes objectForKey: (NSString *) kCTFontNameAttribute];
            id key = name != nil ? name : [NSValue valueWithPointer: descriptor];

            if ([seen containsObject: key])
                continue;
            [seen addObject: key];
            [unique addObject: descriptor];
        }

        descriptors = unique;
    }

    return (CFArrayRef) [descriptors copy];
}

typedef struct {
    CTFontCollectionSortDescriptorsCallback callback;
    void *refCon;
} KTCollectionSortContext;

static NSInteger KTCollectionDescriptorComparator(id first, id second, void *context) {
    KTCollectionSortContext *sortContext = (KTCollectionSortContext *) context;
    return (NSInteger) sortContext->callback((CTFontDescriptorRef) first, (CTFontDescriptorRef) second, sortContext->refCon);
}

CTFontCollectionRef CTFontCollectionCreateFromAvailableFonts(CFDictionaryRef options) {
    return (CTFontCollectionRef) [[KTFontCollection alloc] initWithQueryDescriptors: nil options: (NSDictionary *) options];
}

CTFontCollectionRef CTFontCollectionCreateWithFontDescriptors(CFArrayRef queryDescriptors, CFDictionaryRef options) {
    return (CTFontCollectionRef) [[KTFontCollection alloc] initWithQueryDescriptors: (NSArray *) queryDescriptors options: (NSDictionary *) options];
}

CTFontCollectionRef CTFontCollectionCreateCopyWithFontDescriptors(CTFontCollectionRef collection, CFArrayRef queryDescriptors, CFDictionaryRef options) {
    KTFontCollection *original = (KTFontCollection *) collection;
    NSArray *queries = (NSArray *) queryDescriptors;

    if (queries == nil)
        queries = [original queryDescriptors];

    return (CTFontCollectionRef) [[KTFontCollection alloc] initWithQueryDescriptors: queries options: (NSDictionary *) options];
}

CFArrayRef CTFontCollectionCreateMatchingFontDescriptors(CTFontCollectionRef collection) {
    return KTCollectionCopyDescriptors((KTFontCollection *) collection);
}

CFArrayRef CTFontCollectionCreateMatchingFontDescriptorsSortedWithCallback(CTFontCollectionRef collection, CTFontCollectionSortDescriptorsCallback sortCallback, void *refCon) {
    CFArrayRef descriptors = KTCollectionCopyDescriptors((KTFontCollection *) collection);

    if (descriptors == NULL || sortCallback == NULL)
        return descriptors;

    {
        KTCollectionSortContext context = { sortCallback, refCon };
        NSArray *sorted = [(NSArray *) descriptors sortedArrayUsingFunction: KTCollectionDescriptorComparator context: &context];
        CFRelease(descriptors);
        return (CFArrayRef) [sorted copy];
    }
}

CFTypeID CTFontCollectionGetTypeID(void) {
    return (CFTypeID) [KTFontCollection class];
}