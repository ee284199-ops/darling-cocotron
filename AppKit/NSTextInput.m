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

#import <AppKit/NSApplication.h>
#import <AppKit/NSResponder.h>
#import <AppKit/NSTextInput.h>
#import <AppKit/NSTextInput_Internal.h>
#import <AppKit/NSView.h>
#import <AppKit/NSWindow.h>

NSString *const NSTextInputContextKeyboardSelectionDidChangeNotification = @"NSTextInputContextKeyboardSelectionDidChangeNotification";

NSString *const NSTextInputReplacementRangeAttributeName = @"NSTextInputReplacementRangeAttributeName";

static NSString *const _NSTextInputDefaultKeyboardInputSource =
        @"com.apple.keylayout.US";

@implementation NSTextInputContext

- initWithClient: (id<NSTextInputClient>) client {
    self = [super init];

    // Like on macOS, the client is not retained.
    _client = client;

    return self;
}

- (void) dealloc {
    [_allowedInputSourceLocales release];
    [super dealloc];
}

- (id<NSTextInputClient>) client {
    return _client;
}

+ (NSTextInputContext *) currentInputContext {
    id responder = [[NSApp keyWindow] firstResponder];

    if (responder != nil &&
        [responder respondsToSelector: @selector(inputContext)])
        return [responder inputContext];

    return nil;
}

- (void) activate {
    // There are no input methods to talk to.
}

- (void) deactivate {
    // There are no input methods to talk to.
}

- (BOOL) handleEvent: (NSEvent *) event {
    if ([event type] != NSKeyDown)
        return NO;

    [(NSResponder *) _client interpretKeyEvents:
                                   [NSArray arrayWithObject: event]];

    return YES;
}

- (void) discardMarkedText {
    if (_client == nil)
        return;

    if ([_client respondsToSelector: @selector(hasMarkedText)] &&
        [(id) _client hasMarkedText] &&
        [_client respondsToSelector: @selector(unmarkText)])
        [(id) _client unmarkText];
}

- (void) invalidateCharacterCoordinates {
    // Nothing to do without an input method.
}

- (NSArray<NSString *> *) keyboardInputSources {
    return @[ _NSTextInputDefaultKeyboardInputSource ];
}

- (NSString *) selectedKeyboardInputSource {
    return _NSTextInputDefaultKeyboardInputSource;
}

- (void) setSelectedKeyboardInputSource: (NSString *) inputSourceIdentifier {
    // Ignored, there is only the one input source.
}

+ (NSString *) localizedNameForInputSource:
        (NSString *) inputSourceIdentifier
{
    if ([inputSourceIdentifier
                        isEqualToString: _NSTextInputDefaultKeyboardInputSource])
        return @"U.S.";

    return nil;
}

- (BOOL) acceptsGlyphInfo {
    return _acceptsGlyphInfo;
}

- (void) setAcceptsGlyphInfo: (BOOL) acceptsGlyphInfo {
    _acceptsGlyphInfo = acceptsGlyphInfo;
}

- (NSArray<NSString *> *) allowedInputSourceLocales {
    return _allowedInputSourceLocales;
}

- (void) setAllowedInputSourceLocales:
        (NSArray<NSString *> *) allowedInputSourceLocales
{
    allowedInputSourceLocales = [allowedInputSourceLocales copy];
    [_allowedInputSourceLocales release];
    _allowedInputSourceLocales = allowedInputSourceLocales;
}

@end
