/*
   NSLayoutManager.m

   The text layout manager class

   Copyright (C) 1999 Free Software Foundation, Inc.

   Author:  Jonathan Gapen <jagapen@smithlab.chem.wisc.edu>
   Date: July 1999
   Author:  Michael Hanni <mhanni@sprintmail.com>
   Date: August 1999

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/
#include <AppKit/NSLayoutManager.h>

/*
 * A little utility function to determine the range of characters in a scanner
 * that are present in a specified character set.
 */
static inline NSRange
scanRange(NSScanner *scanner, NSCharacterSet* aSet)
{
  unsigned	start = [scanner scanLocation];
  unsigned	end = start;

  if ([scanner scanCharactersFromSet: aSet intoString: 0] == YES)
    {
      end = [scanner scanLocation];
    }
  return NSMakeRange(start, end - start);
}


// _GSRunSearchKey is an internal class which serves as the foundation for
// all our searching. This may not be an elegant way to go about this, so
// if someone wants to optimize this out, please do.

@interface _GSRunSearchKey : NSObject
{
@public
  NSRange glyphRange;
}
@end

@implementation _GSRunSearchKey
- (id) init
{
  return [super init];
}

- (void) dealloc
{
  [super dealloc];
}
@end

@interface GSGlyphLocation : _GSRunSearchKey
{
@public
  NSPoint point;
}
@end

@implementation GSGlyphLocation
- (id) init
{
  return [super init];
}

- (void) dealloc
{
  [super dealloc];
}
@end

@interface GSLineLayoutInfo : _GSRunSearchKey
{
@public
  NSRect lineFragmentRect;
  NSRect usedRect;
}
@end

@implementation GSLineLayoutInfo
- (id) init
{
  return [super init];
}

- (void) dealloc
{
  [super dealloc];
}
@end

@interface GSTextContainerLayoutInfo : _GSRunSearchKey
{
@public
  NSTextContainer	*textContainer;
  NSString		*testString;
}
@end

@implementation GSTextContainerLayoutInfo
- (id) init
{
  return [super init];
}

- (void) dealloc
{
  [super dealloc];
}
@end

#define GSI_ARRAY_TYPES       GSUNION_OBJ

#ifdef GSIArray
#undef GSIArray
#endif
#include <base/GSIArray.h>

static NSComparisonResult aSort(GSIArrayItem i0, GSIArrayItem i1)
{
  if (((_GSRunSearchKey*)(i0.obj))->glyphRange.location
    < ((_GSRunSearchKey*)(i1.obj))->glyphRange.location)
    return NSOrderedAscending;
  else if (((_GSRunSearchKey*)(i0.obj))->glyphRange.location
    >= NSMaxRange(((_GSRunSearchKey*)(i1.obj))->glyphRange))
    return NSOrderedDescending;
  else
    return NSOrderedSame;
}

@interface GSRunStorage : NSObject
{
  unsigned int _count;
  void *_runs;
}
- (void) insertObject: (id)anObject;
- (void) insertObject: (id)anObject atIndex: (unsigned)theIndex;
- (id) objectAtIndex: (unsigned)theIndex;
- (unsigned) indexOfObject: (id)anObject;
- (unsigned) indexOfObjectContainingLocation: (unsigned)aLocation;
- (id) objectContainingLocation: (unsigned)aLocation;
- (int) count;
@end

@implementation GSRunStorage
- (id) init
{
  NSZone *z;

  [super init];

  z = [self zone];

  _runs = NSZoneMalloc(z, sizeof(GSIArray_t));
  GSIArrayInitWithZoneAndCapacity((GSIArray)_runs, z, 8);

  return self;
}

- (void) insertObject: (id)anObject
{
  _GSRunSearchKey *aKey = [_GSRunSearchKey new];
  _GSRunSearchKey *aObject = (_GSRunSearchKey*)anObject;
  int position;

  aKey->glyphRange.location = aObject->glyphRange.location;

  position = GSIArrayInsertionPosition(_runs, (GSIArrayItem)aKey, aSort);

//  NSLog(@"key: %d aObject: %d position: %d", aKey->glyphRange.location,
//aObject->glyphRange.location, position);

  if (position > 0)
    {
      _GSRunSearchKey *anKey = GSIArrayItemAtIndex(_runs, (unsigned)position - 1).obj;

      if (anKey->glyphRange.location == aObject->glyphRange.location)
        {
//          GSIArrayInsertSorted(_runs, (GSIArrayItem)anObject, aSort);
//	  NSLog(@"=========> duplicated item.");
	  GSIArraySetItemAtIndex(_runs, (GSIArrayItem)anObject, position-1);
        }
      else
	{
//	  NSLog(@"=========> not duplicated item.");
	  GSIArrayInsertItem(_runs, (GSIArrayItem)anObject, position);
	}
    }
  else if (position == 0)
    {
//	NSLog(@"=========> first item (zero index).");
	GSIArrayInsertItem(_runs, (GSIArrayItem)anObject, position);
//      GSIArrayInsertSorted(_runs, (GSIArrayItem)anObject, aSort);
//      [self insertObject: anObject atIndex: position];
    }
  else
    NSLog(@"dead. VERY DEAD DEAD DEAD DEAD.");

//  NSLog(@"==> %d item(s)", GSIArrayCount(_runs));
}

- (void) insertObject: (id)anObject
	      atIndex: (unsigned)theIndex
{
  NSLog(@"insertObject: atIndex: called. %d item(s)", GSIArrayCount(_runs));
  GSIArrayInsertSorted(_runs, (GSIArrayItem)anObject, aSort);
//  GSIArrayInsertItem(_runs, (GSIArrayItem)anObject, theIndex);
  NSLog(@"insertObject: atIndex: ended. %d item(s)", GSIArrayCount(_runs));
}

- (void) removeObjectAtIndex: (int)theIndex
{
  GSIArrayRemoveItemAtIndex(_runs, theIndex);
}

- (id) objectAtIndex: (unsigned)theIndex
{
  return GSIArrayItemAtIndex(_runs, (unsigned)theIndex).obj;
}

- (unsigned) indexOfObject: (id)anObject
{
  return NSNotFound;
}

- (unsigned) indexOfObjectContainingLocation: (unsigned)aLocation
{
  _GSRunSearchKey *aKey = [_GSRunSearchKey new];
  int position;

  aKey->glyphRange.location = aLocation;

  position = GSIArrayInsertionPosition(_runs, (GSIArrayItem)aKey, aSort);

  if (position >= 0 && position - 1 >= 0)
    {
      aKey = GSIArrayItemAtIndex(_runs, (unsigned)position - 1).obj;

      if (NSLocationInRange(aLocation, aKey->glyphRange))
        {
	  return (position - 1);
        }
    }

  return -1;
}

- (id) objectContainingLocation: (unsigned)aLocation
{
  _GSRunSearchKey *aKey = [_GSRunSearchKey new];
  int position;

  aKey->glyphRange.location = aLocation;

  position = GSIArrayInsertionPosition(_runs, (GSIArrayItem)aKey, aSort);

  if (position >= 0 && position - 1 >= 0)
    {
      aKey = GSIArrayItemAtIndex(_runs, (unsigned)position - 1).obj;

      if (NSLocationInRange(aLocation, aKey->glyphRange))
        {
	  return aKey;
        }
    }

  return nil;  
}

- (id) lastObject
{
  return GSIArrayItemAtIndex(_runs, GSIArrayCount(_runs) - 1).obj;
}

- (int) count
{
  return GSIArrayCount(_runs);
}
@end



@implementation NSLayoutManager

- (id) init
{
  [super init];

  _backgroundLayout = YES;
  _delegate = nil;
  _textContainers = [[NSMutableArray alloc] initWithCapacity: 2];

  _containerRuns = [GSRunStorage new];
  _fragmentRuns = [GSRunStorage new];
  _locationRuns = [GSRunStorage new];

  return self;
}

- (void) dealloc
{
  [super dealloc];
}

//
// Setting the text storage
//
- (void) setTextStorage: (NSTextStorage*)aTextStorage
{
  ASSIGN(_textStorage, aTextStorage);
}

- (NSTextStorage*) textStorage
{
  return _textStorage;
}

- (void) replaceTextStorage: (NSTextStorage*)newTextStorage
{
  NSArray *layoutManagers = [_textStorage layoutManagers];
  NSEnumerator *enumerator = [layoutManagers objectEnumerator];
  NSLayoutManager *object;

  // Remove layout managers from old NSTextStorage object and add them to the
  // new one.  NSTextStorage's addLayoutManager invokes NSLayoutManager's
  // setTextStorage method automatically, and that includes self.

  while( (object = (NSLayoutManager*)[enumerator nextObject]) )
  {
    [_textStorage removeLayoutManager: object];
    [newTextStorage addLayoutManager: object];
  }
}

//
// Setting text containers
//
- (NSArray*) textContainers
{
  return _textContainers;
}

- (void) addTextContainer: (NSTextContainer*)obj
{
  if ( [_textContainers indexOfObjectIdenticalTo: obj] == NSNotFound )
  {
    [_textContainers addObject: obj];
    [obj setLayoutManager: self];
  }
}

- (void) insertTextContainer: (NSTextContainer*)aTextContainer
		     atIndex: (unsigned)index
{
  [_textContainers insertObject: aTextContainer atIndex: index];
}

- (void) removeTextContainerAtIndex: (unsigned)index
{
  [_textContainers removeObjectAtIndex: index];
}

//
// Invalidating glyphs and layout
//
- (void) invalidateGlyphsForCharacterRange: (NSRange)aRange
			    changeInLength: (int)lengthChange
		      actualCharacterRange: (NSRange*)actualRange
{
  // FIXME

  // Currently we don't have context information
  if (actualRange)
    {
      *actualRange = aRange;
    }
}

- (void) invalidateLayoutForCharacterRange: (NSRange)aRange
				    isSoft: (BOOL)flag
		      actualCharacterRange: (NSRange*)actualRange
{

  [self _doLayout];
}

- (void) invalidateDisplayForCharacterRange: (NSRange)aRange
{
}

- (void) invalidateDisplayForGlyphRange: (NSRange)aRange
{
}

- (void) textContainerChangedGeometry: (NSTextContainer*)aContainer
{
  unsigned first = 0;

  // find the first character in that text container

  // invalidate the layout from here on
  [self invalidateLayoutForCharacterRange: 
	    NSMakeRange(first, [_textStorage length] - first)
	isSoft: NO
	actualCharacterRange: NULL];
}

- (void) textContainerChangedTextView: (NSTextContainer*)aContainer
{
}

- (void) textStorage: (NSTextStorage*)aTextStorage
	      edited: (unsigned)mask
	       range: (NSRange)range
      changeInLength: (int)lengthChange
    invalidatedRange: (NSRange)invalidatedRange
{
/*
  NSLog(@"NSLayoutManager was just notified that a change in the text
storage occured.");
  NSLog(@"range: (%d, %d) changeInLength: %d invalidatedRange (%d, %d)",
range.location, range.length, lengthChange, invalidatedRange.location,
invalidatedRange.length);
*/
  int delta = 0;
  unsigned last = NSMaxRange(invalidatedRange);

  if (mask & NSTextStorageEditedCharacters)
    {
      delta = lengthChange;
    }

  // hard invalidation occures here.
  [self invalidateGlyphsForCharacterRange: range 
	changeInLength: delta
	actualCharacterRange: NULL];
  [self invalidateLayoutForCharacterRange: invalidatedRange 
	isSoft: NO
	actualCharacterRange: NULL];

  // the following range is soft invalidated
  [self invalidateLayoutForCharacterRange: 
	    NSMakeRange(last, [_textStorage length] - last)
	isSoft: YES
	actualCharacterRange: NULL];
}

//
// Turning on/off background layout
//

- (void) setBackgroundLayoutEnabled: (BOOL)flag
{
  _backgroundLayout = flag;
}

- (BOOL) backgroundLayoutEnabled
{
  return _backgroundLayout;
}

//
// Accessing glyphs
//
- (void) insertGlyph: (NSGlyph)aGlyph
	atGlyphIndex: (unsigned)glyphIndex
      characterIndex: (unsigned)charIndex
{
}

- (NSGlyph) glyphAtIndex: (unsigned)index
{
  return NSNullGlyph;
}

- (NSGlyph) glyphAtIndex: (unsigned)index
	    isValidIndex: (BOOL*)flag
{
  *flag = NO;
  return NSNullGlyph;
}

- (void) replaceGlyphAtIndex: (unsigned)index
		   withGlyph: (NSGlyph)newGlyph
{
}

- (unsigned) getGlyphs: (NSGlyph*)glyphArray
		 range: (NSRange)glyphRange
{
  return (unsigned)0;
}

- (void) deleteGlyphsInRange: (NSRange)aRange
{
}

- (unsigned) numberOfGlyphs
{
  return 0;
}

//
// Mapping characters to glyphs
//
- (void) setCharacterIndex: (unsigned)charIndex
	   forGlyphAtIndex: (unsigned)glyphIndex
{
}

- (unsigned) characterIndexForGlyphAtIndex: (unsigned)glyphIndex
{
  return 0;
}

- (NSRange) characterRangeForGlyphRange: (NSRange)glyphRange
		       actualGlyphRange: (NSRange*)actualGlyphRange
{
  return NSMakeRange(0, 0);
}

- (NSRange) glyphRangeForCharacterRange: (NSRange)charRange
		   actualCharacterRange: (NSRange*)actualCharRange
{
  return NSMakeRange(0, 0);
}

//
// Setting glyph attributes 
//

// Each NSGlyph has an attribute field, yes?

- (void) setIntAttribute: (int)attribute
		   value: (int)anInt
	 forGlyphAtIndex: (unsigned)glyphIndex
{
}

- (int) intAttribute: (int)attribute
     forGlyphAtIndex: (unsigned)glyphIndex
{
  return 0;
}

//
// Handling layout for text containers 
//
- (void) setTextContainer: (NSTextContainer*)aTextContainer
	    forGlyphRange: (NSRange)glyphRange
{
  GSTextContainerLayoutInfo	*theLine = [GSTextContainerLayoutInfo new];

  theLine->glyphRange = glyphRange;
  ASSIGN(theLine->textContainer, aTextContainer);
  
  [_containerRuns insertObject: theLine];
}

- (NSRange) glyphRangeForTextContainer: (NSTextContainer*)aTextContainer
{
  int i;

  NSLog(@"glyphRangeForTextContainer: called. There are %d
textContainer(s) in containerRuns.", [_containerRuns count]);

  for (i=0;i<[_containerRuns count];i++)
    {
      GSTextContainerLayoutInfo *aNewLine = [_containerRuns objectAtIndex: i];

/*
      NSLog(@"glyphRangeForTextContainer: (%d, %d)",
aNewLine->glyphRange.location,
aNewLine->glyphRange.length);
*/

      if ([aNewLine->textContainer isEqual: aTextContainer])
        {
/*
	  NSLog(@"glyphRangeForWantedTextContainer: (%d, %d)",
aNewLine->glyphRange.location,
aNewLine->glyphRange.length);
*/
	  return aNewLine->glyphRange;
        }
    }

  return NSMakeRange(NSNotFound, 0);
}

- (NSTextContainer*) textContainerForGlyphAtIndex: (unsigned)glyphIndex
                                   effectiveRange: (NSRange*)effectiveRange
{
  GSTextContainerLayoutInfo	*theLine;

  theLine = [_containerRuns objectContainingLocation: glyphIndex];
  if (theLine)
    {
      (NSRange*)effectiveRange = &theLine->glyphRange;
      return theLine->textContainer;
    }

  (NSRange*)effectiveRange = NULL;
  return nil;
}

//
// Handling line fragment rectangles 
//
- (void) setLineFragmentRect: (NSRect)fragmentRect
	       forGlyphRange: (NSRange)glyphRange
		    usedRect: (NSRect)usedRect
{
  GSLineLayoutInfo *aNewLine = [GSLineLayoutInfo new];

  aNewLine->glyphRange = glyphRange;
  aNewLine->lineFragmentRect = fragmentRect;
  aNewLine->usedRect = usedRect;

  [_fragmentRuns insertObject: aNewLine];
}

- (NSRect) lineFragmentRectForGlyphAtIndex: (unsigned)glyphIndex
			    effectiveRange: (NSRange*)lineFragmentRange
{
  GSLineLayoutInfo	*theLine;

  theLine = [_fragmentRuns objectContainingLocation: glyphIndex];
  if (theLine)
    {
      (NSRange*)lineFragmentRange = &theLine->glyphRange;
      return theLine->lineFragmentRect;
    }

  (NSRange*)lineFragmentRange = NULL;
  return NSZeroRect;
}

- (NSRect) lineFragmentUsedRectForGlyphAtIndex: (unsigned)glyphIndex
				effectiveRange: (NSRange*)lineFragmentRange
{
  GSLineLayoutInfo	*theLine;

  theLine = [_fragmentRuns objectContainingLocation: glyphIndex];
  if (theLine)
    {
      (NSRange*)lineFragmentRange = &theLine->glyphRange;
      return theLine->usedRect;
    }

  (NSRange*)lineFragmentRange = NULL;
  return NSZeroRect;
}

- (void) setExtraLineFragmentRect: (NSRect)aRect
			 usedRect: (NSRect)usedRect
		    textContainer: (NSTextContainer*)aTextContainer
{
}

- (NSRect) extraLineFragmentRect 
{
  return NSZeroRect;
}

- (NSRect) extraLineFragmentUsedRect 
{
  return NSZeroRect;
}

- (NSTextContainer*) extraLineFragmentTextContainer 
{
  return nil;
}

- (void) setDrawsOutsideLineFragment: (BOOL)flag
		     forGlyphAtIndex: (unsigned)glyphIndex
{
}

- (BOOL) drawsOutsideLineFragmentForGlyphAtIndex: (unsigned)glyphIndex
{
  return NO;
}

//
// Layout of glyphs 
//

- (void) setLocation: (NSPoint)aPoint
forStartOfGlyphRange: (NSRange)glyphRange
{
  GSGlyphLocation *aNewLine = [GSGlyphLocation new];

  aNewLine->glyphRange = glyphRange;
  aNewLine->point = aPoint;

  [_locationRuns insertObject: aNewLine];
}

- (NSPoint) locationForGlyphAtIndex: (unsigned)glyphIndex
{
  return NSZeroPoint;
}

- (NSRange) rangeOfNominallySpacedGlyphsContainingIndex: (unsigned)glyphIndex
{
  GSLineLayoutInfo	*theLine;

  theLine = [_locationRuns objectContainingLocation: glyphIndex];

  if (theLine)
    {
      return theLine->glyphRange;
    }

  return NSMakeRange(NSNotFound, 0);
}

- (NSRect*) rectArrayForCharacterRange: (NSRange)charRange
          withinSelectedCharacterRange: (NSRange)selChareRange
                       inTextContainer: (NSTextContainer*)aTextContainer
                             rectCount: (unsigned*)rectCount
{
/*
  GSLineLayoutInfo *theLine = [GSLineLayoutInfo new];
  int position, lastPosition;
  int i, j = 0;

  theLine->glyphRange.location = charRange.location;

  position = GSIArrayInsertionPosition(lineFragments, (GSIArrayItem)theLine, aSort);

  if (position < 0)
    {
      return NULL;
    }

  theLine->glyphRange.location = charRange.location + charRange.length;

  lastPosition = GSIArrayInsertionPosition(lineFragments, (GSIArrayItem)theLine, aSort);

  if (lastPosition > 0)
    {
      _cachedRectArray = NSZoneRealloc([self zone], _cachedRectArray,
				(lastPosition - position) * sizeof(NSRect));

      _cachedRectArrayCapacity = lastPosition - position;

      for (i = position - 1; i < lastPosition - 1; i++)
        {
          GSLineLayoutInfo *aLine = GSIArrayItemAtIndex(lineFragments, i).obj;

	  _cachedRectArray[j] = aLine->lineFragmentRect;
	  j++;
        }
    }

  (*rectCount) = (position - 1 + lastPosition - 1);
  return _cachedRectArray;
*/
}

- (NSRect*) rectArrayForGlyphRange: (NSRange)glyphRange
          withinSelectedGlyphRange: (NSRange)selectedGlyphRange
                   inTextContainer: (NSTextContainer*)aTextContainer
                         rectCount: (unsigned*)rectCount
{
  return _cachedRectArray;
}

- (NSRect) boundingRectForGlyphRange: (NSRange)glyphRange
		     inTextContainer: (NSTextContainer*)aTextContainer
{

/* Returns a single bounding rectangle enclosing all glyphs and other
marks drawn in aTextContainer for glyphRange, including glyphs that draw
outside their line fragment rectangles and text attributes such as
underlining. This method is useful for determining the area that needs to
be redrawn when a range of glyphs changes. */
/*
  unsigned rectCount;
  NSRect *rects = [self rectArrayForCharacterRange: [self glyphRangeForTextContainer: aTextContainer]
		      withinSelectedCharacterRange: NSMakeRange(0,0)
				   inTextContainer: aTextContainer
					 rectCount: &rectCount];
//  NSPoint aOrigin = [aTextContainer originPoint];
  NSRect rRect = NSZeroRect;
  int i;

  for (i=0;i<rectCount;i++)
    {
      NSRect aRect = rects[i];

      if (aRect.origin.y == rRect.size.height)
        rRect.size.height += aRect.size.width;

      if (rRect.size.width == aRect.origin.x)
        rRect.size.width += aRect.size.width;
    }

  return rRect;
*/
  return NSZeroRect;
}

- (NSRange) glyphRangeForBoundingRect: (NSRect)aRect
		      inTextContainer: (NSTextContainer*)aTextContainer
{
  return NSMakeRange(0, 0);
}

- (NSRange) glyphRangeForBoundingRectWithoutAdditionalLayout: (NSRect)bounds
                           inTextContainer: (NSTextContainer*)aTextContainer
{
  return NSMakeRange(0, 0);
}

- (unsigned) glyphIndexForPoint: (NSPoint)aPoint
		inTextContainer: (NSTextContainer*)aTextContainer
 fractionOfDistanceThroughGlyph: (float*)partialFraction
{
  return 0;
}

//
// Display of special glyphs 
//
- (void) setNotShownAttribute: (BOOL)flag
	      forGlyphAtIndex: (unsigned)glyphIndex
{
}

- (BOOL) notShownAttributeForGlyphAtIndex: (unsigned)glyphIndex
{
  return YES;
}

- (void) setShowsInvisibleCharacters: (BOOL)flag
{
  _showsInvisibleChars = flag;
}

- (BOOL) showsInvisibleCharacters 
{
  return _showsInvisibleChars;
}

- (void) setShowsControlCharacters: (BOOL)flag
{
  _showsControlChars = flag;
}

- (BOOL) showsControlCharacters
{
  return _showsControlChars;
}

//
// Controlling hyphenation 
//
- (void) setHyphenationFactor: (float)factor
{
  _hyphenationFactor = factor;
}

- (float) hyphenationFactor
{
  return _hyphenationFactor;
}

//
// Finding unlaid characters/glyphs 
//
- (void) getFirstUnlaidCharacterIndex: (unsigned*)charIndex
			   glyphIndex: (unsigned*)glyphIndex
{
  if (charIndex)
    *charIndex = [self firstUnlaidCharacterIndex];

  if (glyphIndex)
    *glyphIndex = [self firstUnlaidGlyphIndex];
}

- (unsigned int) firstUnlaidCharacterIndex
{
  return _firstUnlaidCharIndex;
}

- (unsigned int) firstUnlaidGlyphIndex
{
  return _firstUnlaidGlyphIndex;
}

//
// Using screen fonts 
//
- (void) setUsesScreenFonts: (BOOL)flag
{
  _usesScreenFonts = flag;
}

- (BOOL) usesScreenFonts 
{
  return _usesScreenFonts;
}

- (NSFont*) substituteFontForFont: (NSFont*)originalFont
{
  NSFont *replaceFont;

  if (_usesScreenFonts)
    return originalFont;

  // FIXME: Should check if any NSTextView is scalled or rotated
  replaceFont = [originalFont screenFont];
  
  if (replaceFont != nil)
    return replaceFont;
  else
    return originalFont;    
}

//
// Handling rulers 
//
- (NSView*) rulerAccessoryViewForTextView: (NSTextView*)aTextView
                           paragraphStyle: (NSParagraphStyle*)paragraphStyle
                                    ruler: (NSRulerView*)aRulerView
                                  enabled: (BOOL)flag
{
  return NULL;
}

- (NSArray*) rulerMarkersForTextView: (NSTextView*)aTextView
                      paragraphStyle: (NSParagraphStyle*)paragraphStyle
                               ruler: (NSRulerView*)aRulerView
{
  return NULL;
}

//
// Managing the responder chain 
//
- (BOOL) layoutManagerOwnsFirstResponderInWindow: (NSWindow*)aWindow
{
  return NO;
}

- (NSTextView*) firstTextView 
{
  return NULL;
}

- (NSTextView*) textViewForBeginningOfSelection
{
  return NULL;
}

//
// Drawing 
//
- (void) drawBackgroundForGlyphRange: (NSRange)glyphRange
			     atPoint: (NSPoint)containerOrigin
{
}

- (void) drawGlyphsForGlyphRange: (NSRange)glyphRange
			 atPoint: (NSPoint)containerOrigin
{
  int firstPosition, lastPosition, i;

  for (i=0;i<[_fragmentRuns count];i++)
    {
      GSLineLayoutInfo *info = [_fragmentRuns objectAtIndex: i];

/*
      NSLog(@"i: %d glyphRange: (%d, %d) lineFragmentRect: (%f, %f) (%f, %f)",
i,
info->glyphRange.location,
info->glyphRange.length,
info->lineFragmentRect.origin.x,  
info->lineFragmentRect.origin.y,    
info->lineFragmentRect.size.width,  
info->lineFragmentRect.size.height);
*/
    }

  firstPosition = [_fragmentRuns indexOfObjectContainingLocation: glyphRange.location];
  lastPosition = [_fragmentRuns 
		     indexOfObjectContainingLocation: (glyphRange.location+glyphRange.length-3)];

  NSLog(@"glyphRange: (%d, %d) position1: %d position2: %d",
glyphRange.location, glyphRange.length, firstPosition, lastPosition);

  if (firstPosition >= 0)
    {
      if (lastPosition == -1)
        {
          lastPosition = [_fragmentRuns count] - 1; // FIXME
	  NSLog(@"fixed lastPosition: %d", lastPosition);
        }

      for (i = firstPosition; i <= lastPosition; i++)
        {
	  GSLineLayoutInfo *aLine = [_fragmentRuns objectAtIndex: i];
	  NSRect aRect = aLine->lineFragmentRect;
	  aRect.size.height -= 4;

/*
NSLog(@"drawRange: (%d, %d) inRect (%f, %f) (%f, %f)",
aLine->glyphRange.location,
aLine->glyphRange.length,
aLine->lineFragmentRect.origin.x,
aLine->lineFragmentRect.origin.y,
aLine->lineFragmentRect.size.width,
aLine->lineFragmentRect.size.height);
*/

          NSEraseRect (aRect);
	  [_textStorage drawRange: aLine->glyphRange inRect: aLine->lineFragmentRect];
        }
    }
}

- (void) drawUnderlineForGlyphRange: (NSRange)glyphRange
		      underlineType: (int)underlineType
		     baselineOffset: (float)baselineOffset
		   lineFragmentRect: (NSRect)lineRect
	     lineFragmentGlyphRange: (NSRange)lineGlyphRange
		    containerOrigin: (NSPoint)containerOrigin
{
}

- (void) underlineGlyphRange: (NSRange)glyphRange
	       underlineType: (int)underlineType
	    lineFragmentRect: (NSRect)lineRect
      lineFragmentGlyphRange: (NSRange)lineGlyphRange
	     containerOrigin: (NSPoint)containerOrigin
{
}

//
// Setting the delegate 
//
- (void) setDelegate: (id)aDelegate
{
  _delegate = aDelegate;
}

- (id) delegate
{
  return _delegate;
}

@end /* NSLayoutManager */

/* The methods laid out here are not correct, however the code they
contain for the most part is. Therefore, my country and a handsome gift of
Ghiradelli chocolate to he who puts all the pieces together : ) */

@implementation NSLayoutManager (Private)
- (int) _rebuildLayoutForTextContainer: (NSTextContainer*)aContainer
		  startingAtGlyphIndex: (int)glyphIndex
{
  NSSize cSize = [aContainer containerSize];
  float i = 0.0;
  NSMutableArray *lineStarts = [NSMutableArray new];
  NSMutableArray *lineEnds = [NSMutableArray new];
  int indexToAdd;
  NSScanner		*lineScanner;
  NSScanner		*paragraphScanner;
  BOOL lastLineForContainerReached = NO;
  NSString *aString;
  int previousScanLocation;
  int previousParagraphLocation;
  int endScanLocation;
  int startIndex;
  NSRect firstProposedRect;
  NSRect secondProposedRect;
  NSFont *default_font = [NSFont systemFontOfSize: 0];
  int widthOfString;
  NSSize rSize;
  NSCharacterSet *selectionParagraphGranularitySet = [NSCharacterSet characterSetWithCharactersInString: @"\n"];
  NSCharacterSet *selectionWordGranularitySet = [NSCharacterSet characterSetWithCharactersInString: @" "];
  NSCharacterSet *invSelectionWordGranularitySet = [selectionWordGranularitySet invertedSet];
  NSCharacterSet *invSelectionParagraphGranularitySet = [selectionParagraphGranularitySet invertedSet];
  NSRange paragraphRange;
  NSRange leadingSpacesRange;
  NSRange currentStringRange;
  NSRange trailingSpacesRange;
  NSRange leadingNlRange;
  NSRange trailingNlRange;
  NSSize lSize;
  float lineWidth = 0.0;
  float ourLines = 0.0;
  int beginLineIndex = 0;

  NSLog(@"rebuilding Layout at index: %d.\n", glyphIndex);

  // 1.) figure out how many glyphs we can fit in our container by
  // breaking up glyphs from the first unlaid out glyph and breaking it
  // into lines.
  //
  // 2.) 
  //     a.) set the range for the container
  //     b.) for each line in step 1 we need to set a lineFragmentRect and
  //         an origin point.


  // Here we go at part 1.

  startIndex = glyphIndex;

  paragraphScanner = [NSScanner scannerWithString: [_textStorage string]];
  [paragraphScanner setCharactersToBeSkipped: nil];

  [paragraphScanner setScanLocation: startIndex];

  NSLog(@"length of textStorage: %d", [[_textStorage string] length]);

//  NSLog(@"buffer: %@", [_textStorage string]);

  /*
   * This scanner eats one word at a time, we should have it imbeded in
   * another scanner that snacks on paragraphs (i.e. lines that end with
   * \n). Look in NSText.
   */
  while (![paragraphScanner isAtEnd])
    {
      previousParagraphLocation = [paragraphScanner scanLocation];
      beginLineIndex = previousParagraphLocation;
      lineWidth = 0.0;

      leadingNlRange
	= scanRange(paragraphScanner, selectionParagraphGranularitySet);
      paragraphRange
	= scanRange(paragraphScanner, invSelectionParagraphGranularitySet);
      trailingNlRange
	= scanRange(paragraphScanner, selectionParagraphGranularitySet);

//      NSLog(@"leadingNlRange: (%d, %d)", leadingNlRange.location, leadingNlRange.length);

//      if (leadingNlRange.length)
//	paragraphRange = NSUnionRange (leadingNlRange,paragraphRange);
//      if (trailingNlRange.length)
//	paragraphRange = NSUnionRange (trailingNlRange,paragraphRange);

      NSLog(@"paragraphRange: (%d, %d)", paragraphRange.location, paragraphRange.length);

      lineScanner = [NSScanner scannerWithString:
	[[_textStorage string] substringWithRange: paragraphRange]];
      [lineScanner setCharactersToBeSkipped: nil];

      while (![lineScanner isAtEnd])
        {
          previousScanLocation = [lineScanner scanLocation];

           // snack next word
          leadingSpacesRange
	    = scanRange(lineScanner, selectionWordGranularitySet);
          currentStringRange
	    = scanRange(lineScanner, invSelectionWordGranularitySet);
          trailingSpacesRange
	    = scanRange(lineScanner, selectionWordGranularitySet);

          if (leadingSpacesRange.length)
	    currentStringRange = NSUnionRange(leadingSpacesRange,currentStringRange);
          if (trailingSpacesRange.length)
	    currentStringRange = NSUnionRange(trailingSpacesRange,currentStringRange);

	  lSize = [_textStorage sizeRange: currentStringRange];

//	  lSize = [_textStorage sizeRange: 
//NSMakeRange(currentStringRange.location+paragraphRange.location+startIndex,
//currentStringRange.length)];

	  if ((lineWidth + lSize.width) < cSize.width)
	    {
	      if ([lineScanner isAtEnd])
                {
		  NSLog(@"we are at end before finishing a line: %d.\n",  [lineScanner scanLocation]);
		NSLog(@"scanLocation = %d, previousParagraphLocation = %d, beginLineIndex = %d",
[lineScanner scanLocation],
previousParagraphLocation,
beginLineIndex);
		  [lineStarts addObject: [NSNumber
numberWithInt: beginLineIndex]];
	          [lineEnds addObject: [NSNumber
numberWithInt: (int)[lineScanner scanLocation] + previousParagraphLocation - (beginLineIndex)]];
	          lineWidth = 0.0;
                }

	      lineWidth += lSize.width;
	      //NSLog(@"lineWidth: %f", lineWidth);
	    }
	  else
	    {
	      if (ourLines > cSize.height)
                {
                   lastLineForContainerReached = YES;
                   break;
                 }

	      [lineScanner setScanLocation: previousScanLocation];
	      indexToAdd = previousScanLocation + previousParagraphLocation
- (beginLineIndex);

		NSLog(@"previousScanLocation = %d, previousParagraphLocation = %d, beginLineIndex = %d indexToAdd = %d",
previousScanLocation,
previousParagraphLocation,
beginLineIndex,
indexToAdd);

	      ourLines += 20.0;  // 14
	      lineWidth = 0.0;

	      [lineStarts addObject: [NSNumber
numberWithInt: beginLineIndex]];
	      [lineEnds addObject: [NSNumber numberWithInt: indexToAdd]];
	      beginLineIndex = previousScanLocation + previousParagraphLocation;
	    }
	}

      if (lastLineForContainerReached)
        break;
    }

  endScanLocation = [paragraphScanner scanLocation];

  NSLog(@"endScanLocation: %d", endScanLocation);

  // set this container for that glyphrange

  [self setTextContainer: aContainer
	forGlyphRange: NSMakeRange(startIndex, endScanLocation - startIndex)];

  NSLog(@"ok, move on to step 2.");

  // step 2. break the lines up and assign rects to them.

  for (i=0; i < [lineStarts count]; i++)
    {
      NSRect aRect, bRect;
      float padding = [aContainer lineFragmentPadding];
      NSRange ourRange;

//      NSLog(@"\t\t===> %d", [[lines objectAtIndex: i] intValue]);

      ourRange = NSMakeRange ([[lineStarts objectAtIndex: i] intValue],
			      [[lineEnds objectAtIndex: i] intValue]);

/*
      if (i == 0)
        {
          ourRange = NSMakeRange (startIndex, 
			[[lines objectAtIndex: i] intValue] - startIndex);
        }
      else
        {
          ourRange = NSMakeRange ([[lines objectAtIndex: i-1] intValue],
[[lines objectAtIndex: i] intValue] - [[lines objectAtIndex: i-1]
intValue]);
        }
*/
      NSLog(@"line: %@|", [[_textStorage string]
substringWithRange: ourRange]);

      firstProposedRect = NSMakeRect (0, i * 14, cSize.width, 14);

      // ask our textContainer to fix our lineFragment.

      secondProposedRect = [aContainer
	lineFragmentRectForProposedRect: firstProposedRect
                            sweepDirection: NSLineSweepLeft
                         movementDirection: NSLineMoveLeft
			     remainingRect: &bRect];

      // set the line fragmentRect for this range.

      [self setLineFragmentRect: secondProposedRect
		  forGlyphRange: ourRange
		       usedRect: aRect];

      // set the location for this string to be 'show'ed.

      [self setLocation: NSMakePoint(secondProposedRect.origin.x + padding,
				    secondProposedRect.origin.y + padding) 
	    forStartOfGlyphRange: ourRange];
    }

// bloody hack.
//      if (moreText)
//      	[delegate layoutManager: self
//	  didCompleteLayoutForTextContainer: [textContainers objectAtIndex: i]
//          atEnd: NO];
//      else
//      	[delegate layoutManager: self
//	  didCompleteLayoutForTextContainer: [textContainers objectAtIndex: i]
//          atEnd: YES];

  [lineStarts release];
  [lineEnds release];

  return endScanLocation;
}

- (void) _doLayout
{
  NSEnumerator		*enumerator;
  NSTextContainer	*container;
  int			gIndex = 0;

  NSLog(@"doLayout called.\n");

  enumerator = [_textContainers objectEnumerator];
  while ((container = [enumerator nextObject]) != nil)
    {
      gIndex = [self _rebuildLayoutForTextContainer: container
			       startingAtGlyphIndex: gIndex];
    }
}

@end
