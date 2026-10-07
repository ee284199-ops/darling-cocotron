#import <Foundation/NSGeometry.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSRange.h>

@class NSArray, NSAttributedString;

@protocol NSTextInputClient <NSObject>

- (void) insertText: string replacementRange: (NSRange) replacementRange;
- (void) doCommandBySelector: (SEL) selector;
- (void) setMarkedText: string
         selectedRange: (NSRange) selectedRange
      replacementRange: (NSRange) replacementRange;
- (void) unmarkText;
- (NSRange) selectedRange;
- (NSRange) markedRange;
- (BOOL) hasMarkedText;
- (NSAttributedString *) attributedSubstringForProposedRange: (NSRange) range
                                                 actualRange: (NSRangePointer) actualRange;
- (NSArray *) validAttributesForMarkedText;
- (NSRect) firstRectForCharacterRange: (NSRange) range
                          actualRange: (NSRangePointer) actualRange;
- (NSUInteger) characterIndexForPoint: (NSPoint) point;

@optional
- (NSAttributedString *) attributedString;
- (CGFloat) fractionOfDistanceThroughGlyphForPoint: (NSPoint) point;
- (CGFloat) baselineDeltaForCharacterAtIndex: (NSUInteger) anIndex;
- (NSInteger) windowLevel;
- (BOOL) drawsVerticallyForCharacterAtIndex: (NSUInteger) charIndex;

@end
