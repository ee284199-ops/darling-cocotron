/* Copyright (c) 2007 Christopher J. W. Lloyd

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

#import "NSAnimationContext.h"
#import <AppKit/NSRaise.h>
#import <QuartzCore/CAMediaTimingFunction.h>

static NSAnimationContext *_currentAnimationContext = nil;

@implementation NSAnimationContext

- (id) copyWithZone: (NSZone *) zone {
    return self;
}

+ (void) beginGrouping {
}

+ (void) endGrouping {
}

+ (NSAnimationContext *) currentContext {
    if (_currentAnimationContext == nil)
        _currentAnimationContext = [[NSAnimationContext alloc] init];

    return _currentAnimationContext;
}

- (void) setDuration: (NSTimeInterval) duration {
    _duration = duration;
}

- (NSTimeInterval) duration {
    return _duration;
}

- (void) setTimingFunction: (CAMediaTimingFunction *) timingFunction {
    [timingFunction retain];
    [_timingFunction release];
    _timingFunction = timingFunction;
}

- (CAMediaTimingFunction *) timingFunction {
    return [[_timingFunction retain] autorelease];
}

- (void) setCompletionHandler: (void (^)(void)) completionHandler {
    id oldValue = _completionHandler;

    _completionHandler = [completionHandler copy];
    [oldValue release];
}

- (void (^)(void)) completionHandler {
    return _completionHandler;
}

- (BOOL) allowsImplicitAnimation {
    return _allowsImplicitAnimation;
}

- (void) setAllowsImplicitAnimation: (BOOL) flag {
    _allowsImplicitAnimation = flag;
}

+ (void) runAnimationGroup: (void (^)(NSAnimationContext *context)) changes
         completionHandler: (void (^)(void)) completionHandler
{
    NSAnimationContext *context = [self currentContext];

    if (changes != NULL)
        changes(context);

    if (completionHandler != NULL)
        completionHandler();
}

+ (void) runAnimationGroup: (void (^)(NSAnimationContext *context)) changes {
    [self runAnimationGroup: changes completionHandler: NULL];
}

- (void) dealloc {
    [_timingFunction release];
    [_completionHandler release];
    [super dealloc];
}

@end
