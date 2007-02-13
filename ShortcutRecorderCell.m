//
//  ShortcutRecorderCell.m
//  ShortcutRecorder
//
//  Copyright 2006 Contributors. All rights reserved.
//
//  License: BSD
//
//  Contributors:
//      David Dauer
//      Jesper
//
//  Revisions:
//      2006-03-12 Created.

#import "ShortcutRecorderCell.h"
#import "ShortcutRecorder.h"
#import "CTGradient.h"

// Unicode values of some keyboard glyphs
enum {
	KeyboardTabRightGlyph = 0x21E5,
	KeyboardTabLeftGlyph = 0x21E4,
	
	KeyboardCommandGlyph = kCommandUnicode,
	KeyboardOptionGlyph = kOptionUnicode,
	KeyboardShiftGlyph = kShiftUnicode,
	KeyboardControlGlyph = kControlUnicode,

	KeyboardReturnGlyph = 0x2305,
	KeyboardReturnR2LGlyph = 0x21A9,
	
	KeyboardDeleteLeftGlyph = 0x232B,
	KeyboardDeleteRightGlyph = 0x2326,
	
	KeyboardPadClearGlyph = 0x2327,
	
	KeyboardLeftArrowGlyph = 0x2190,
	KeyboardRightArrowGlyph = 0x2192,
	KeyboardUpArrowGlyph = 0x2191,
	KeyboardDownArrowGlyph = 0x2193,
		
	KeyboardPageDownGlyph = 0x21DF,
	KeyboardPageUpGlyph = 0x21DE,
	
	KeyboardNorthwestArrowGlyph = 0x2196,
	KeyboardSoutheastArrowGlyph = 0x2198,
	
	KeyboardEscapeGlyph = 0x238B,
	KeyboardHelpGlyph = 0x003F,

	KeyboardUpArrowheadGlyph = 0x2303,
};

// Localization macros, for use in any bundle
#define SRLoc(key) SRLocalizedString(key, nil)
#define SRLocalizedString(key, comment) NSLocalizedStringFromTableInBundle(key, nil, [NSBundle bundleForClass: [self class]], comment)

// Image macros, for use in any bundle
#define SRImage(name) [[[NSImage alloc] initWithContentsOfFile: [[NSBundle bundleForClass: [self class]] pathForImageResource: name]] autorelease]

// Macros for glyps
#define SRInt(x) [NSNumber numberWithInt: x]
#define SRChar(x) [NSString stringWithFormat: @"%C", x]

// Some default values
#define ShortcutRecorderEmptyFlags 0
#define ShortcutRecorderAllFlags ShortcutRecorderEmptyFlags + (NSCommandKeyMask + NSAlternateKeyMask + NSControlKeyMask + NSShiftKeyMask)
#define ShortcutRecorderEmptyCode -1

// These keys will cancel the recoding mode if not pressed with any modifier
#define ShortcutRecorderEscapeKey 53
#define ShortcutRecorderBackspaceKey 51
#define ShortcutRecorderDeleteKey 117

// This segment is a category on NSBezierPath to supply roundrects. It's a common thing if you're drawing,
// so to integrate well, we use an oddball method signature to not implement the same method twice.

// This code is originally from http://www.cocoadev.com/index.pl?RoundedRectangles and no license demands
// (or Copyright demands) are stated, so we pretend it's public domain. 

// This used to be in a separate file (like CTGradient) but it's beneficial (ie short enough) to bring inline here.

@interface NSBezierPath (ShortcutRecorderCellNSBezierPathAdditions)
+ (NSBezierPath*)bezierPathWithSRCRoundRectInRect:(NSRect)aRect radius:(float)radius;
@end

@implementation NSBezierPath (ShortcutRecorderCellNSBezierPathAdditions)

+ (NSBezierPath*)bezierPathWithSRCRoundRectInRect:(NSRect)aRect radius:(float)radius
{
	NSBezierPath* path = [self bezierPath];
	radius = MIN(radius, 0.5f * MIN(NSWidth(aRect), NSHeight(aRect)));
	NSRect rect = NSInsetRect(aRect, radius, radius);
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMinY(rect)) radius:radius startAngle:180.0 endAngle:270.0];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMinY(rect)) radius:radius startAngle:270.0 endAngle:360.0];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMaxY(rect)) radius:radius startAngle:  0.0 endAngle: 90.0];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMaxY(rect)) radius:radius startAngle: 90.0 endAngle:180.0];
	[path closePath];
	return path;
}

@end

@interface ShortcutRecorderCell (Private)
- (void)_privateInit;
- (void)_createGradient;
- (NSString *)_defaultsKeyForAutosaveName:(NSString *)name;
- (void)_saveKeyCombo;
- (void)_loadKeyCombo;

- (NSRect)_removeButtonRectForFrame:(NSRect)cellFrame;
- (NSRect)_snapbackRectForFrame:(NSRect)cellFrame;

- (unsigned int)_filteredCocoaFlags:(unsigned int)flags;
- (unsigned int)_filteredCocoaToCarbonFlags:(unsigned int)cocoaFlags;
- (BOOL)_validModifierFlags:(unsigned int)flags;

- (NSString *)_stringForKeyCode:(signed short)keyCode;

- (NSString *)_stringForCocoaModifierFlags:(unsigned int)flags;
- (NSString *)_stringForCocoaModifierFlags:(unsigned int)flags andKeyCode:(signed short)keyCode;
- (NSString *)_readableStringForCocoaModifierFlags:(unsigned int)flags andKeyCode:(signed short)keyCode;

- (NSString *)_stringForCarbonModifierFlags:(unsigned int)flags;
- (NSString *)_stringForCarbonModifierFlags:(unsigned int)flags andKeyCode:(signed short)keyCode;
- (NSString *)_readableStringForCarbonModifierFlags:(unsigned int)flags andKeyCode:(signed short)keyCode;

- (BOOL)_isKeyCode:(signed short)keyCode andFlagsTaken:(unsigned int)flags alert:(NSAlert **)alert;
- (BOOL)_isKeyCode:(signed short)keyCode andFlags:(unsigned int)flags takenInMenu:(NSMenu *)menu alert:(NSAlert **)alert;

- (BOOL)_isEmpty;
@end

#pragma mark -

@implementation ShortcutRecorderCell

- (id)init
{
    self = [super init];
	
	[self _privateInit];
	
    return self;
}

- (void)dealloc
{
	[recordingGradient release];
	[autosaveName release];
	
	[cancelCharacterSet release];
	[keyCodeToStringDict release];
	[padKeysArray release];
	
	[super dealloc];
}

#pragma mark *** Coding Support ***

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder: aDecoder];
	
	[self _privateInit];

	if ([aDecoder allowsKeyedCoding])
	{
		autosaveName = [[aDecoder decodeObjectForKey: @"autosaveName"] retain];
		
		keyCombo.code = [[aDecoder decodeObjectForKey: @"keyComboCode"] shortValue];
		keyCombo.flags = [[aDecoder decodeObjectForKey: @"keyComboFlags"] unsignedIntValue];

		allowedFlags = [[aDecoder decodeObjectForKey: @"allowedFlags"] unsignedIntValue];
		requiredFlags = [[aDecoder decodeObjectForKey: @"requiredFlags"] unsignedIntValue];
	} 
	else 
	{
		autosaveName = [[aDecoder decodeObject] retain];
		
		keyCombo.code = [[aDecoder decodeObject] shortValue];
		keyCombo.flags = [[aDecoder decodeObject] unsignedIntValue];
		
		allowedFlags = [[aDecoder decodeObject] unsignedIntValue];
		requiredFlags = [[aDecoder decodeObject] unsignedIntValue];
	}
	
	[self _loadKeyCombo];

	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[super encodeWithCoder: aCoder];
	
	if ([aCoder allowsKeyedCoding])
	{
		[aCoder encodeObject:[self autosaveName] forKey:@"autosaveName"];
		[aCoder encodeObject:[NSNumber numberWithShort: keyCombo.code] forKey:@"keyComboCode"];
		[aCoder encodeObject:[NSNumber numberWithUnsignedInt: keyCombo.flags] forKey:@"keyComboFlags"];
	
		[aCoder encodeObject:[NSNumber numberWithUnsignedInt: allowedFlags] forKey:@"allowedFlags"];
		[aCoder encodeObject:[NSNumber numberWithUnsignedInt: requiredFlags] forKey:@"requiredFlags"];
	}
	else
	{
		[aCoder encodeObject: [self autosaveName]];
		[aCoder encodeObject: [NSNumber numberWithShort: keyCombo.code]];
		[aCoder encodeObject: [NSNumber numberWithUnsignedInt: keyCombo.flags]];
		
		[aCoder encodeObject: [NSNumber numberWithUnsignedInt: allowedFlags]];
		[aCoder encodeObject: [NSNumber numberWithUnsignedInt: requiredFlags]];
	}
}

- (id)copyWithZone:(NSZone *)zone
{
    ShortcutRecorderCell *cell;
    cell = (ShortcutRecorderCell *)[super copyWithZone: zone];
	
	cell->recordingGradient = [recordingGradient retain];
	cell->autosaveName = [autosaveName retain];

	cell->isRecording = isRecording;
	cell->mouseInsideTrackingArea = mouseInsideTrackingArea;
	cell->mouseDown = mouseDown;

	cell->removeTrackingRectTag = removeTrackingRectTag;
	cell->snapbackTrackingRectTag = snapbackTrackingRectTag;

	cell->keyCombo = keyCombo;

	cell->allowedFlags = allowedFlags;
	cell->requiredFlags = requiredFlags;
	cell->recordingFlags = recordingFlags;

	cell->cancelCharacterSet = [cancelCharacterSet retain];
	cell->keyCodeToStringDict = [keyCodeToStringDict retain];
	cell->padKeysArray = [padKeysArray retain];

	cell->delegate = delegate;
	
    return cell;
}

#pragma mark *** Drawing ***

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
{
	NSRect whiteRect = cellFrame;
	NSBezierPath *roundedRect;

	// Draw gradient when in recording mode
	if (isRecording)
	{
		roundedRect = [NSBezierPath bezierPathWithSRCRoundRectInRect:cellFrame radius:NSHeight(cellFrame)/2.0];
		
		// Fill background with gradient
		[[NSGraphicsContext currentContext] saveGraphicsState];
		[roundedRect addClip];
		[recordingGradient fillRect:cellFrame angle:90.0];
		[[NSGraphicsContext currentContext] restoreGraphicsState];
		
		// Highlight if inside or down
		if (mouseInsideTrackingArea)
		{
			[[[NSColor blackColor] colorWithAlphaComponent: (mouseDown ? 0.4 : 0.2)] set];
			[roundedRect fill];
		}
		
		// Draw snapback image
		NSImage *snapBackArrow = SRImage(@"Snapback");	
		[snapBackArrow dissolveToPoint:[self _snapbackRectForFrame: cellFrame].origin fraction:1.0];

		// Because of the gradient and snapback image, the white rounded rect will be smaller
		whiteRect = NSInsetRect(cellFrame, 9.5, 2.0);
		whiteRect.origin.x -= 7.5;
	}
	
	// Draw white rounded box
	roundedRect = [NSBezierPath bezierPathWithSRCRoundRectInRect:whiteRect radius:NSHeight(whiteRect)/2.0];
	[[NSGraphicsContext currentContext] saveGraphicsState];
	[roundedRect addClip];
	[[NSColor whiteColor] set];
	[NSBezierPath fillRect: whiteRect];

	// Draw border and remove badge if needed
	if (!isRecording)
	{
		[[NSColor windowFrameColor] set];
		[roundedRect stroke];
	
		// If key combination is set and valid, draw remove image
		if (![self _isEmpty] && [self isEnabled])
		{
			NSString *removeImageName = [NSString stringWithFormat: @"RemoveShortcut%@", (mouseInsideTrackingArea ? (mouseDown ? @"Pressed" : @"Rollover") : (mouseDown ? @"Rollover" : @""))];
			NSImage *removeImage = SRImage(removeImageName);
			[removeImage dissolveToPoint:[self _removeButtonRectForFrame: cellFrame].origin fraction:1.0];
		}
	}
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
	
	// Draw text
	NSMutableParagraphStyle *style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[style setLineBreakMode: NSLineBreakByTruncatingTail];
	[style setAlignment: NSCenterTextAlignment];

	// Only the KeyCombo should be black and in a bigger font size
	BOOL recordingOrEmpty = (isRecording || [self _isEmpty]);
	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys: style, NSParagraphStyleAttributeName,
		[NSFont systemFontOfSize: (recordingOrEmpty ? [NSFont labelFontSize] : [NSFont smallSystemFontSize])], NSFontAttributeName,
		(recordingOrEmpty ? [NSColor disabledControlTextColor] : [NSColor blackColor]), NSForegroundColorAttributeName, 
		nil];
	
	NSString *displayString;
	
	if (isRecording)
	{
		// Recording, but no modifier keys down
		if (![self _validModifierFlags: recordingFlags])
		{
			if (mouseInsideTrackingArea)
			{
				// Mouse over snapback
				displayString = SRLoc(@"Use old shortcut");
			}
			else
			{
				// Mouse elsewhere
				displayString = SRLoc(@"Type shortcut");
			}
		}
		else
		{
			// Display currently pressed modifier keys
			displayString = [self _stringForCocoaModifierFlags: recordingFlags];
		}
	}
	else
	{
		// Not recording...
		if ([self _isEmpty])
		{
			displayString = SRLoc(@"Click to record shortcut");
		}
		else
		{
			// Display current key combination
			displayString = [self keyComboString];
		}
	}
	
	// Calculate rect in which to draw the text in...
	NSRect textRect = cellFrame;
	textRect.size.width -= 6;
	textRect.size.width -= ((!isRecording && [self _isEmpty]) ? 6 : (isRecording ? [self _snapbackRectForFrame: cellFrame].size.width : [self _removeButtonRectForFrame: cellFrame].size.width) + 6);
	textRect.origin.x += 6;
	textRect.origin.y = -(NSMidY(cellFrame) - [displayString sizeWithAttributes: attributes].height/2);

	// Finally draw it
	[displayString drawInRect:textRect withAttributes:attributes];
}

#pragma mark *** Mouse Tracking ***

- (void)resetTrackingRects
{	
	ShortcutRecorder *controlView = (ShortcutRecorder *)[self controlView];
	NSRect cellFrame = [controlView bounds];
	NSPoint mouseLocation = [controlView convertPoint:[[NSApp currentEvent] locationInWindow] fromView:nil];

	// We're not to be tracked if we're not enabled
	if (![self isEnabled])
	{
		if (removeTrackingRectTag != 0) [controlView removeTrackingRect: removeTrackingRectTag];
		if (snapbackTrackingRectTag != 0) [controlView removeTrackingRect: snapbackTrackingRectTag];
		
		return;
	}
	
	// We're either in recording or normal display mode
	if (!isRecording)
	{
		// Create and register tracking rect for the remove badge if shortcut is not empty
		NSRect removeButtonRect = [self _removeButtonRectForFrame: cellFrame];
		BOOL mouseInside = [controlView mouse:mouseLocation inRect:removeButtonRect];
		
		if (removeTrackingRectTag != 0) [controlView removeTrackingRect: removeTrackingRectTag];
		removeTrackingRectTag = [controlView addTrackingRect:removeButtonRect owner:self userData:nil assumeInside:mouseInside];
		
		if (mouseInsideTrackingArea != mouseInside) mouseInsideTrackingArea = mouseInside;
	}
	else
	{
		// Create and register tracking rect for the snapback badge if we're in recording mode
		NSRect snapbackRect = [self _snapbackRectForFrame: cellFrame];
		BOOL mouseInside = [controlView mouse:mouseLocation inRect:snapbackRect];

		if (snapbackTrackingRectTag != 0) [controlView removeTrackingRect: snapbackTrackingRectTag];
		snapbackTrackingRectTag = [controlView addTrackingRect:snapbackRect owner:self userData:nil assumeInside:mouseInside];	
		
		if (mouseInsideTrackingArea != mouseInside) mouseInsideTrackingArea = mouseInside;
	}
}

- (void)mouseEntered:(NSEvent *)theEvent
{
	NSView *view = [self controlView];

	if ([[view window] isKeyWindow] || [view acceptsFirstMouse: theEvent])
	{
		mouseInsideTrackingArea = YES;
		[view display];
	}
}

- (void)mouseExited:(NSEvent*)theEvent
{
	NSView *view = [self controlView];
	
	if ([[view window] isKeyWindow] || [view acceptsFirstMouse: theEvent])
	{
		mouseInsideTrackingArea = NO;
		[view display];
	}
}

- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(ShortcutRecorder *)controlView untilMouseUp:(BOOL)flag
{		
	NSEvent *currentEvent = theEvent;
	NSPoint mouseLocation = [controlView convertPoint:[currentEvent locationInWindow] fromView:nil];
	
	NSRect trackingRect = (isRecording ? [self _snapbackRectForFrame: cellFrame] : [self _removeButtonRectForFrame: cellFrame]);
	NSRect leftRect = cellFrame;

	// Determine the area without any badge
	if (!NSEqualRects(trackingRect,NSZeroRect)) leftRect.size.width -= NSWidth(trackingRect) + 4;
		
	do {
        mouseLocation = [controlView convertPoint: [currentEvent locationInWindow] fromView:nil];
		
		switch ([currentEvent type])
		{
			case NSLeftMouseDown:
			{
				// Check if mouse is over remove/snapback image
				if ([controlView mouse:mouseLocation inRect:trackingRect])
				{
					mouseDown = YES;
					[controlView setNeedsDisplayInRect: cellFrame];
				}
				
				break;
			}
			case NSLeftMouseDragged:
			{				
				// Recheck if mouse is still over the image while dragging 
				mouseInsideTrackingArea = [controlView mouse:mouseLocation inRect:trackingRect];
				[controlView setNeedsDisplayInRect: cellFrame];
				
				break;
			}
			default: // NSLeftMouseUp
			{
				mouseDown = NO;
				mouseInsideTrackingArea = [controlView mouse:mouseLocation inRect:trackingRect];

				if (mouseInsideTrackingArea)
				{
					if (isRecording)
					{
						// Mouse was over snapback, just redraw
						isRecording = NO;
					}
					else
					{
						// Mouse was over the remove image, reset all
						[self setKeyCombo: SRMakeKeyCombo(ShortcutRecorderEmptyCode, ShortcutRecorderEmptyFlags)];
					}
				}
				else if ([controlView mouse:mouseLocation inRect:leftRect] && !isRecording)
				{
					if ([self isEnabled]) 
					{
						// Jump into recording mode if mouse was inside the control but not over any image
						isRecording = YES;
						// Reset recording flags and determine which are required
						recordingFlags = [self _filteredCocoaFlags: ShortcutRecorderEmptyFlags];
					}
					/* maybe beep if not editable?
					 else
					{
						NSBeep();
					}
					 */
				}
				
				// Any click inside will make us firstResponder
				if ([self isEnabled]) [[controlView window] makeFirstResponder: controlView];

				// Reset tracking rects and redisplay
				[self resetTrackingRects];
				[controlView setNeedsDisplayInRect: cellFrame];
				
				return YES;
			}
		}
		
    } while ((currentEvent = [[controlView window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask) untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES]));
	
    return YES;
}

#pragma mark *** Delegate ***

- (id)delegate
{
	return delegate;
}

- (void)setDelegate:(id)aDelegate
{
	delegate = aDelegate;
}

#pragma mark *** Key Combination Control ***

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{	
	unsigned int flags = [self _filteredCocoaFlags: [theEvent modifierFlags]];
	NSNumber *keyCodeNumber = [NSNumber numberWithUnsignedShort: [theEvent keyCode]];
	BOOL snapback = [cancelCharacterSet containsObject: keyCodeNumber];
	BOOL validModifiers = [self _validModifierFlags: (snapback) ? [theEvent modifierFlags] : flags]; // Snapback key shouldn't interfer with required flags!
	
	// Do something as long as we're in recording mode and a modifier key or cancel key is pressed
	if (isRecording && (validModifiers || snapback))
	{
		if (!snapback || validModifiers)
		{
			NSString *character = [[theEvent charactersIgnoringModifiers] uppercaseString];

			// accents like "´" or "`" will be ignored since we don't get a keycode
			if ([character length])
			{
				NSAlert *alert = nil;
				
				// Check if key combination is already used or not allowed by the delegate
				if ([self _isKeyCode:[theEvent keyCode] andFlagsTaken:[self _filteredCocoaToCarbonFlags: flags] alert:&alert])
				{
					if (alert) [alert runModal];
					
					// Recheck pressed modifier keys
					[self flagsChanged: [NSApp currentEvent]];
					
					return YES;
				}
				else
				{
					// All ok, set new combination
					keyCombo.flags = flags;
					keyCombo.code = [theEvent keyCode];
					
					// Notify delegate
					if (delegate != nil && [delegate respondsToSelector: @selector(shortcutRecorderCell:keyComboDidChange:)])
						[delegate shortcutRecorderCell:self keyComboDidChange:keyCombo];
							
					// Save if needed
					[self _saveKeyCombo];
				}
			}
			else
			{
				// invalid character
				NSBeep();
			}
		}
		
		// reset values and redisplay
		recordingFlags = ShortcutRecorderEmptyFlags;
		isRecording = NO;
		
		[self resetTrackingRects];
		[[self controlView] display];

		return YES;
	}
	
	return NO;
}

- (void)flagsChanged:(NSEvent *)theEvent
{
	if (isRecording)
	{
		recordingFlags = [self _filteredCocoaFlags: [theEvent modifierFlags]];
		[[self controlView] display];
	}
}

#pragma mark -

- (unsigned int)allowedFlags
{
	return allowedFlags;
}

- (void)setAllowedFlags:(unsigned int)flags
{
	allowedFlags = flags;
	
	// filter new flags and change keycombo if not recording
	if (isRecording)
	{
		recordingFlags = [self _filteredCocoaFlags: [[NSApp currentEvent] modifierFlags]];;
	}
	else
	{
		unsigned int originalFlags = keyCombo.flags;
		keyCombo.flags = [self _filteredCocoaFlags: keyCombo.flags];
		
		if (keyCombo.flags != originalFlags && keyCombo.code > ShortcutRecorderEmptyCode)
		{
			// Notify delegate if keyCombo changed
			if (delegate != nil && [delegate respondsToSelector: @selector(shortcutRecorderCell:keyComboDidChange:)])
				[delegate shortcutRecorderCell:self keyComboDidChange:keyCombo];
			
			// Save if needed
			[self _saveKeyCombo];
		}
	}
	
	[[self controlView] display];
}

- (unsigned int)requiredFlags
{
	return requiredFlags;
}

- (void)setRequiredFlags:(unsigned int)flags
{
	requiredFlags = flags;
	
	// filter new flags and change keycombo if not recording
	if (isRecording)
	{
		recordingFlags = [self _filteredCocoaFlags: [[NSApp currentEvent] modifierFlags]];
	}
	else
	{
		unsigned int originalFlags = keyCombo.flags;
		keyCombo.flags = [self _filteredCocoaFlags: keyCombo.flags];
		
		if (keyCombo.flags != originalFlags && keyCombo.code > ShortcutRecorderEmptyCode)
		{
			// Notify delegate if keyCombo changed
			if (delegate != nil && [delegate respondsToSelector: @selector(shortcutRecorderCell:keyComboDidChange:)])
				[delegate shortcutRecorderCell:self keyComboDidChange:keyCombo];
			
			// Save if needed
			[self _saveKeyCombo];
		}
	}
	
	[[self controlView] display];
}

- (KeyCombo)keyCombo
{
	return keyCombo;
}

- (void)setKeyCombo:(KeyCombo)aKeyCombo
{
	keyCombo = aKeyCombo;
	keyCombo.flags = [self _filteredCocoaFlags: aKeyCombo.flags];

	// Notify delegate
	if (delegate != nil && [delegate respondsToSelector: @selector(shortcutRecorderCell:keyComboDidChange:)])
		[delegate shortcutRecorderCell:self keyComboDidChange:keyCombo];
	
	// Save if needed
	[self _saveKeyCombo];
	
	[[self controlView] display];
}

#pragma mark *** Autosave Control ***

- (NSString *)autosaveName
{
	return autosaveName;
}

- (void)setAutosaveName:(NSString *)aName
{
	if (aName != autosaveName)
	{
		[autosaveName release];
		autosaveName = [aName copy];
	}
}

#pragma mark -

- (NSString *)keyComboString
{
	if ([self _isEmpty]) return nil;
	
	return [NSString stringWithFormat: @"%@%@",[self _stringForCocoaModifierFlags: keyCombo.flags], [self _stringForKeyCode: keyCombo.code]];
}

#pragma mark *** Conversion Methods ***

- (unsigned int)cocoaToCarbonFlags:(unsigned int)cocoaFlags
{
	unsigned int carbonFlags = ShortcutRecorderEmptyFlags;
	
	if (cocoaFlags & NSCommandKeyMask) carbonFlags += cmdKey;
	if (cocoaFlags & NSAlternateKeyMask) carbonFlags += optionKey;
	if (cocoaFlags & NSControlKeyMask) carbonFlags += controlKey;
	if (cocoaFlags & NSShiftKeyMask) carbonFlags += shiftKey;
	
	return carbonFlags;
}

- (unsigned int)carbonToCocoaFlags:(unsigned int)carbonFlags
{
	unsigned int cocoaFlags = ShortcutRecorderEmptyFlags;
	
	if (carbonFlags & cmdKey) cocoaFlags += NSCommandKeyMask;
	if (carbonFlags & optionKey) cocoaFlags += NSAlternateKeyMask;
	if (carbonFlags & controlKey) cocoaFlags += NSControlKeyMask;
	if (carbonFlags & shiftKey) cocoaFlags += NSShiftKeyMask;
	
	return cocoaFlags;
}

@end

#pragma mark -

@implementation ShortcutRecorderCell (Private)

- (void)_privateInit
{
	// Allow all modifier keys by default, nothing is required
	allowedFlags = ShortcutRecorderAllFlags;
	requiredFlags = ShortcutRecorderEmptyFlags;
	recordingFlags = ShortcutRecorderEmptyFlags;
	
	// Create clean KeyCombo
	keyCombo.flags = ShortcutRecorderEmptyFlags;
	keyCombo.code = ShortcutRecorderEmptyCode;
	
	// These keys will cancel the recoding mode if not pressed with any modifier
	cancelCharacterSet = [[NSSet alloc] initWithObjects: [NSNumber numberWithInt:ShortcutRecorderEscapeKey], 
		[NSNumber numberWithInt:ShortcutRecorderBackspaceKey], [NSNumber numberWithInt:ShortcutRecorderDeleteKey], nil];
	
	// Some keys need a special glyph
	keyCodeToStringDict = [[NSDictionary alloc] initWithObjectsAndKeys:
		@"F1", SRInt(122),
		@"F2", SRInt(120),
		@"F3", SRInt(99),
		@"F4", SRInt(118),
		@"F5", SRInt(96),
		@"F6", SRInt(97),
		@"F7", SRInt(98),
		@"F8", SRInt(100),
		@"F9", SRInt(101),
		@"F10", SRInt(109),
		@"F11", SRInt(103),
		@"F12", SRInt(111),
		@"F13", SRInt(105),
		@"F14", SRInt(107),
		@"F15", SRInt(113),
		@"F16", SRInt(106),
		SRLoc(@"Space"), SRInt(49),
		SRChar(KeyboardDeleteLeftGlyph), SRInt(51),
		SRChar(KeyboardDeleteRightGlyph), SRInt(117),
		SRChar(KeyboardPadClearGlyph), SRInt(71),
		SRChar(KeyboardLeftArrowGlyph), SRInt(123),
		SRChar(KeyboardRightArrowGlyph), SRInt(124),
		SRChar(KeyboardUpArrowGlyph), SRInt(126),
		SRChar(KeyboardDownArrowGlyph), SRInt(125),
		SRChar(KeyboardSoutheastArrowGlyph), SRInt(119),
		SRChar(KeyboardNorthwestArrowGlyph), SRInt(115),
		SRChar(KeyboardEscapeGlyph), SRInt(53),
		SRChar(KeyboardPageDownGlyph), SRInt(121),
		SRChar(KeyboardPageUpGlyph), SRInt(116),
		SRChar(KeyboardReturnR2LGlyph), SRInt(36),
		SRChar(KeyboardReturnGlyph), SRInt(76),
		SRChar(KeyboardTabRightGlyph), SRInt(48),
		SRChar(KeyboardHelpGlyph), SRInt(114),
		// SRChar(KeyboardUpArrowheadGlyph), SRInt(10), can't map this because this key is keyboard layout dependent, damn
		nil];
	
	// We want to identify if the key was pressed on the numpad
	padKeysArray = [[NSArray alloc] initWithObjects: 
		SRInt(65), // ,
		SRInt(67), // *
		SRInt(69), // +
		SRInt(75), // /
		SRInt(78), // -
		SRInt(81), // =
		SRInt(82), // 0
		SRInt(83), // 1
		SRInt(84), // 2
		SRInt(85), // 3
		SRInt(86), // 4
		SRInt(87), // 5
		SRInt(88), // 6
		SRInt(89), // 7
		SRInt(91), // 8
		SRInt(92), // 9
		nil];
		
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self selector:@selector(_createGradient) name:NSSystemColorsDidChangeNotification object:nil]; // recreate gradient if needed
	[self _createGradient];

	[self _loadKeyCombo];
}

- (void)_createGradient
{
	NSColor *gradientStartColor = [[[NSColor alternateSelectedControlColor] shadowWithLevel: 0.2] colorWithAlphaComponent: 0.9];
	NSColor *gradientEndColor = [[[NSColor alternateSelectedControlColor] highlightWithLevel: 0.2] colorWithAlphaComponent: 0.9];
	
	CTGradient *newGradient = [CTGradient gradientWithBeginningColor:gradientStartColor endingColor:gradientEndColor];
	
	if (recordingGradient != newGradient)
	{
		[recordingGradient release];
		recordingGradient = [newGradient retain];
	}
	
	[[self controlView] display];
}

#pragma mark *** Autosave ***

- (NSString *)_defaultsKeyForAutosaveName:(NSString *)name
{
	return [NSString stringWithFormat: @"ShortcutRecorder %@", name];
}

- (void)_saveKeyCombo
{
	NSString *defaultsKey = [self autosaveName];

	if (defaultsKey != nil && [defaultsKey length])
	{
		id values = [[NSUserDefaultsController sharedUserDefaultsController] values];
		
		NSDictionary *defaultsValue = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithShort: keyCombo.code], @"keyCode",
			[NSNumber numberWithInt: keyCombo.flags], @"modifierFlags",
			nil];
		
		[values setValue:defaultsValue forKey:[self _defaultsKeyForAutosaveName: defaultsKey]];
	}
}

- (void)_loadKeyCombo
{
	NSString *defaultsKey = [self autosaveName];

	if (defaultsKey != nil && [defaultsKey length])
	{
		id values = [[NSUserDefaultsController sharedUserDefaultsController] values];
		NSDictionary *savedCombo = [values valueForKey: [self _defaultsKeyForAutosaveName: defaultsKey]];
		
		signed short keyCode = [[savedCombo valueForKey: @"keyCode"] shortValue];
		unsigned int flags = [[savedCombo valueForKey: @"modifierFlags"] unsignedIntValue];
		
		keyCombo.flags = [self _filteredCocoaFlags: flags];
		keyCombo.code = keyCode;
		
		// Notify delegate
		if (delegate != nil && [delegate respondsToSelector: @selector(shortcutRecorderCell:keyComboDidChange:)])
			[delegate shortcutRecorderCell:self keyComboDidChange:keyCombo];
		
		[[self controlView] display];
	}
}

#pragma mark *** Drawing Helpers ***

- (NSRect)_removeButtonRectForFrame:(NSRect)cellFrame
{	
	if ([self _isEmpty] || ![self isEnabled]) return NSZeroRect;
	
	NSRect removeButtonRect;
	NSImage *removeImage = SRImage(@"RemoveShortcut");
	
	removeButtonRect.origin = NSMakePoint(NSMaxX(cellFrame) - [removeImage size].width - 4, (NSMaxY(cellFrame) - [removeImage size].height)/2);
	removeButtonRect.size = [removeImage size];

	return removeButtonRect;
}

- (NSRect)_snapbackRectForFrame:(NSRect)cellFrame
{	
	if (!isRecording) return NSZeroRect;

	NSRect snapbackRect;
	NSImage *snapbackImage = SRImage(@"Snapback");
	
	snapbackRect.origin = NSMakePoint(NSMaxX(cellFrame) - [snapbackImage size].width - 2, (NSMaxY(cellFrame) - [snapbackImage size].height)/2 + 1);
	snapbackRect.size = [snapbackImage size];

	return snapbackRect;
}

#pragma mark *** Filters ***

- (unsigned int)_filteredCocoaFlags:(unsigned int)flags
{
	unsigned int filteredFlags = ShortcutRecorderEmptyFlags;
	unsigned int a = allowedFlags;
	unsigned int m = requiredFlags;

	if (m & NSCommandKeyMask) filteredFlags += NSCommandKeyMask;
	else if ((flags & NSCommandKeyMask) && (a & NSCommandKeyMask)) filteredFlags += NSCommandKeyMask;
	
	if (m & NSAlternateKeyMask) filteredFlags += NSAlternateKeyMask;
	else if ((flags & NSAlternateKeyMask) && (a & NSAlternateKeyMask)) filteredFlags += NSAlternateKeyMask;
	
	if ((m & NSControlKeyMask)) filteredFlags += NSControlKeyMask;
	else if ((flags & NSControlKeyMask) && (a & NSControlKeyMask)) filteredFlags += NSControlKeyMask;
	
	if ((m & NSShiftKeyMask)) filteredFlags += NSShiftKeyMask;
	else if ((flags & NSShiftKeyMask) && (a & NSShiftKeyMask)) filteredFlags += NSShiftKeyMask;
	
	return filteredFlags;
}

- (BOOL)_validModifierFlags:(unsigned int)flags
{
	return ((flags & NSCommandKeyMask) || (flags & NSAlternateKeyMask) || (flags & NSControlKeyMask) || (flags & NSShiftKeyMask)) ? YES : NO;	
}

#pragma mark -

- (unsigned int)_filteredCocoaToCarbonFlags:(unsigned int)cocoaFlags
{
	unsigned int carbonFlags = ShortcutRecorderEmptyFlags;
	unsigned filteredFlags = [self _filteredCocoaFlags: cocoaFlags];
	
	if (filteredFlags & NSCommandKeyMask) carbonFlags += cmdKey;
	if (filteredFlags & NSAlternateKeyMask) carbonFlags += optionKey;
	if (filteredFlags & NSControlKeyMask) carbonFlags += controlKey;
	if (filteredFlags & NSShiftKeyMask) carbonFlags += shiftKey;
	
	return carbonFlags;
}

#pragma mark *** KeyCode Translation ***

- (NSString *)_stringForKeyCode:(signed short)keyCode
{
	// Can be -1 when empty
	if (keyCode < 0) return nil;
	
	// We have some special gylphs for some special keys...
	NSString *unmappedString = [keyCodeToStringDict objectForKey: SRInt(keyCode)];
	if (unmappedString != nil) return unmappedString;
	
	BOOL isPadKey = [padKeysArray containsObject: SRInt(keyCode)];	
	KeyboardLayoutRef currentLayoutRef;
	KeyboardLayoutKind currentLayoutKind;
    OSStatus err;
	
	err = KLGetCurrentKeyboardLayout(&currentLayoutRef);
    if (err != noErr) return nil;
	
	err = KLGetKeyboardLayoutProperty(currentLayoutRef,kKLKind,(const void **)&currentLayoutKind);
	if (err != noErr) return nil;

	UInt32 keysDown = 0;
	
	if (currentLayoutKind == kKLKCHRKind)
	{
		Handle kchrHandle;

		err = KLGetKeyboardLayoutProperty(currentLayoutRef,kKLKCHRData,(const void **)&kchrHandle);
		if (err != noErr) return nil;
		
		UInt32 charCode = KeyTranslate(kchrHandle,keyCode,&keysDown);
        char theChar = (charCode & 0x00FF);
		
		NSString *keyString = [[[[NSString alloc] initWithData:[NSData dataWithBytes:&theChar length:1] encoding:NSMacOSRomanStringEncoding] autorelease] uppercaseString];
		
        return (isPadKey ? [NSString stringWithFormat: SRLoc(@"Pad %@"), keyString] : keyString);
	}
	else // kKLuchrKind, kKLKCHRuchrKind
	{
		UCKeyboardLayout *keyboardLayout = NULL;
		err = KLGetKeyboardLayoutProperty(currentLayoutRef,kKLuchrData,(const void **)&keyboardLayout);
		if (err != noErr) return nil;
		
		UniCharCount length = 4, realLength;
        UniChar chars[4];

        err = UCKeyTranslate(keyboardLayout,keyCode,kUCKeyActionDisplay,0,LMGetKbdType(),kUCKeyTranslateNoDeadKeysBit,&keysDown,length,&realLength,chars);
        
		NSString *keyString = [[NSString stringWithCharacters:chars length:1] uppercaseString];
		
        return (isPadKey ? [NSString stringWithFormat: SRLoc(@"Pad %@"), keyString] : keyString);
	}

	return nil;
}

#pragma mark *** Modifier Translation ***

- (NSString *)_stringForCocoaModifierFlags:(unsigned int)flags
{
	NSString *modifierFlagsString = [NSString stringWithFormat:@"%@%@%@%@", 
		(flags & NSControlKeyMask ? [NSString stringWithFormat:@"%C", KeyboardControlGlyph] : @""),
		(flags & NSAlternateKeyMask ? [NSString stringWithFormat:@"%C", KeyboardOptionGlyph] : @""),
		(flags & NSShiftKeyMask ? [NSString stringWithFormat:@"%C", KeyboardShiftGlyph] : @""),
		(flags & NSCommandKeyMask ? [NSString stringWithFormat:@"%C", KeyboardCommandGlyph] : @"")];
	
	return modifierFlagsString;
}

- (NSString *)_stringForCocoaModifierFlags:(unsigned int)flags andKeyCode:(signed short)keyCode
{
	return [NSString stringWithFormat: @"%@%@", [self _stringForCocoaModifierFlags: flags], [self _stringForKeyCode: keyCode]];
}

- (NSString *)_readableStringForCocoaModifierFlags:(unsigned int)flags andKeyCode:(signed short)keyCode
{
	NSString *readableString = [NSString stringWithFormat:@"%@%@%@%@%@", 
		(flags & NSCommandKeyMask ? SRLoc(@"Command + ") : @""),
		(flags & NSAlternateKeyMask ? SRLoc(@"Option + ") : @""),
		(flags & NSControlKeyMask ? SRLoc(@"Control + ") : @""),
		(flags & NSShiftKeyMask ? SRLoc(@"Shift + ") : @""),
		([self _stringForKeyCode: keyCode])];

	return readableString;
}

- (NSString *)_stringForCarbonModifierFlags:(unsigned int)flags
{
	NSString *modifierFlagsString = [NSString stringWithFormat:@"%@%@%@%@", 
		(flags & controlKey ? [NSString stringWithFormat:@"%C", KeyboardControlGlyph] : @""),
		(flags & optionKey ? [NSString stringWithFormat:@"%C", KeyboardOptionGlyph] : @""),
		(flags & shiftKey ? [NSString stringWithFormat:@"%C", KeyboardShiftGlyph] : @""),
		(flags & cmdKey ? [NSString stringWithFormat:@"%C", KeyboardCommandGlyph] : @"")];
	
	return modifierFlagsString;
}

- (NSString *)_stringForCarbonModifierFlags:(unsigned int)flags andKeyCode:(signed short)keyCode
{
	return [NSString stringWithFormat: @"%@%@", [self _stringForCarbonModifierFlags: flags], [self _stringForKeyCode: keyCode]];
}

- (NSString *)_readableStringForCarbonModifierFlags:(unsigned int)flags andKeyCode:(signed short)keyCode
{
	NSString *readableString = [NSString stringWithFormat:@"%@%@%@%@%@", 
		(flags & cmdKey ? SRLoc(@"Command + ") : @""),
		(flags & optionKey ? SRLoc(@"Option + ") : @""),
		(flags & controlKey ? SRLoc(@"Control + ") : @""),
		(flags & shiftKey ? SRLoc(@"Shift + ") : @""),
		([self _stringForKeyCode: keyCode])];

	return readableString;
}

#pragma mark *** Global KeyCode Check ***

- (BOOL)_isKeyCode:(signed short)keyCode andFlagsTaken:(unsigned int)flags alert:(NSAlert **)alert
{
	// Delegate goes first
	// Check out delegate
	if (delegate != nil && [delegate respondsToSelector:@selector(shortcutRecorderCell:isKeyCode:andFlagsTaken:reason:)])
	{
		NSString *delegateReason = nil;
		
		if ([delegate shortcutRecorderCell:self isKeyCode:keyCode andFlagsTaken:[self carbonToCocoaFlags: flags] reason:&delegateReason])
		{
			// Alert will always be shown. Optionally check here for the existance of "delegateReson" and only display the alert if it exists
			// if (delegateReason != nil)
			// {
			
			*alert = [[[NSAlert alloc] init] autorelease];
			
			[*alert setMessageText: [NSString stringWithFormat: SRLoc(@"The key combination %@ couldn't be used!"), [self _stringForCarbonModifierFlags:flags andKeyCode:keyCode]]];
			[*alert setInformativeText: [NSString stringWithFormat: SRLoc(@"The key combination \"%@\" couldn't be used, because %@."), [self _readableStringForCarbonModifierFlags:flags andKeyCode:keyCode], (delegateReason != nil && [delegateReason length]) ? delegateReason : @"it's already used"]];
			[*alert setAlertStyle: NSWarningAlertStyle];
			
			[*alert addButtonWithTitle: @"OK"];
			
			// }
			
			return YES;
		}
	}
	
	// Then our implementation
	NSArray *globalHotKeys;
	
	// Get global hot keys
	if (CopySymbolicHotKeys((CFArrayRef *)&globalHotKeys) != noErr)
		return YES;
	
	NSEnumerator *globalHotKeysEnumerator = [globalHotKeys objectEnumerator];
	NSDictionary *globalHotKeyInfoDictionary;
	SInt32 gobalHotKeyFlags;
	signed short globalHotKeyCharCode;
	unichar globalHotKeyUniChar;
	unichar localHotKeyUniChar;
	BOOL globalCommandMod = NO, globalOptionMod = NO, globalShiftMod = NO, globalCtrlMod = NO;
	BOOL localCommandMod = NO, localOptionMod = NO, localShiftMod = NO, localCtrlMod = NO;
	
	// Prepare local carbon comparison flags
	if (flags & cmdKey) localCommandMod = YES;
	if (flags & optionKey) localOptionMod = YES;
	if (flags & shiftKey) localShiftMod = YES;
	if (flags & controlKey) localCtrlMod = YES;

	while ((globalHotKeyInfoDictionary = [globalHotKeysEnumerator nextObject]))
	{
		// Only check if global hotkey is enabled
		if ((CFBooleanRef)[globalHotKeyInfoDictionary objectForKey: (NSString *)kHISymbolicHotKeyEnabled] == kCFBooleanTrue)
		{
			globalCommandMod = NO;
			globalOptionMod = NO;
			globalShiftMod = NO;
			globalCtrlMod = NO;
			
			globalHotKeyCharCode = [(NSNumber *)[globalHotKeyInfoDictionary objectForKey: (NSString *)kHISymbolicHotKeyCode] unsignedShortValue];
			globalHotKeyUniChar = [[[NSString stringWithFormat:@"%C", globalHotKeyCharCode] uppercaseString] characterAtIndex: 0];

			CFNumberGetValue((CFNumberRef)[globalHotKeyInfoDictionary objectForKey: (NSString *)kHISymbolicHotKeyModifiers],kCFNumberSInt32Type,&gobalHotKeyFlags);
			
			if (gobalHotKeyFlags & cmdKey) globalCommandMod = YES;
			if (gobalHotKeyFlags & optionKey) globalOptionMod = YES;
			if (gobalHotKeyFlags & shiftKey) globalShiftMod = YES;
			if (gobalHotKeyFlags & controlKey) globalCtrlMod = YES;
			
			NSString *localKeyString = [self _stringForKeyCode: keyCode];
			if (![localKeyString length]) return YES;
			
			localHotKeyUniChar = [localKeyString characterAtIndex: 0];
		
			// Compare unichar value and modifier flags
			if ((globalHotKeyUniChar == localHotKeyUniChar) && (globalCommandMod == localCommandMod) &&
				(globalOptionMod == localOptionMod) && (globalShiftMod == localShiftMod) && (globalCtrlMod == localCtrlMod))
			{
				*alert = [[[NSAlert alloc] init] autorelease];
				
				[*alert setMessageText: [NSString stringWithFormat: SRLoc(@"The key combination %@ couldn't be used!"), [self _stringForCarbonModifierFlags:flags andKeyCode:keyCode]]];
				[*alert setInformativeText: [NSString stringWithFormat: SRLoc(@"The key combination \"%@\" couldn't be used, because it's already used by a system-wide keyboard shortcut. (If you really want to use this key combination, most shortcuts can be changed in the Keyboard & Mouse panel in System Preferences.)"), [self _readableStringForCarbonModifierFlags:flags andKeyCode:keyCode]]];
				[*alert setAlertStyle: NSWarningAlertStyle];
				
				[*alert addButtonWithTitle: @"OK"];
				
				return YES;
			}
		}
	}
	
	// Check menus too
	return [self _isKeyCode:keyCode andFlags:flags takenInMenu:[NSApp mainMenu] alert:alert];
}

#pragma mark *** Local Menu KeyCode Check ***

- (BOOL)_isKeyCode:(signed short)keyCode andFlags:(unsigned int)flags takenInMenu:(NSMenu *)menu alert:(NSAlert **)alert
{	
	NSArray *menuItemsArray = [menu itemArray];
	NSEnumerator *menuItemsEnumerator = [menuItemsArray objectEnumerator];
	NSMenuItem *menuItem;
	unsigned int menuItemModifierFlags;
	NSString *menuItemKeyEquivalent;
	
	BOOL menuItemCommandMod = NO, menuItemOptionMod = NO, menuItemShiftMod = NO, menuItemCtrlMod = NO;
	BOOL localCommandMod = NO, localOptionMod = NO, localShiftMod = NO, localCtrlMod = NO;
	
	// Prepare local carbon comparison flags
	if (flags & cmdKey) localCommandMod = YES;
	if (flags & optionKey) localOptionMod = YES;
	if (flags & shiftKey) localShiftMod = YES;
	if (flags & controlKey) localCtrlMod = YES;
	
	while ((menuItem = [menuItemsEnumerator nextObject]))
	{
		if ([menuItem hasSubmenu])
		{
			// go into all submenus
			if ([self _isKeyCode:keyCode andFlags:flags takenInMenu:[menuItem submenu] alert:alert]) 
			{
				return YES;
			}
		}
		
		if ((menuItemKeyEquivalent = [menuItem keyEquivalent]) && (![menuItemKeyEquivalent isEqualToString: @""]))
		{
			menuItemCommandMod = NO;
			menuItemOptionMod = NO;
			menuItemShiftMod = NO;
			menuItemCtrlMod = NO;
			
			menuItemModifierFlags = [menuItem keyEquivalentModifierMask];

			if (menuItemModifierFlags & NSCommandKeyMask) menuItemCommandMod = YES;
			if (menuItemModifierFlags & NSAlternateKeyMask) menuItemOptionMod = YES;
			if (menuItemModifierFlags & NSShiftKeyMask) menuItemShiftMod = YES;
			if (menuItemModifierFlags & NSControlKeyMask) menuItemCtrlMod = YES;
			
			NSString *localKeyString = [self _stringForKeyCode: keyCode];
			
			// Compare translated keyCode and modifier flags
			if (([[menuItemKeyEquivalent uppercaseString] isEqualToString: localKeyString]) && (menuItemCommandMod == localCommandMod) &&
				(menuItemOptionMod == localOptionMod) && (menuItemShiftMod == localShiftMod) && (menuItemCtrlMod == localCtrlMod))
			{
				*alert = [[[NSAlert alloc] init] autorelease];
				
				[*alert setMessageText: [NSString stringWithFormat: SRLoc(@"The key combination %@ couldn't be used!"), [self _stringForCarbonModifierFlags:flags andKeyCode:keyCode]]];
				[*alert setInformativeText: [NSString stringWithFormat: SRLoc(@"The key combination \"%@\" couldn't be used, because it's already used by the menu item \"%@\"."), [self _readableStringForCocoaModifierFlags:menuItemModifierFlags andKeyCode:keyCode], [menuItem title]]];
				[*alert setAlertStyle: NSWarningAlertStyle];
				
				[*alert addButtonWithTitle: @"OK"];
								
				return YES;
			}
		}
	}
	
	return NO;
}

#pragma mark *** Internal Check ***

- (BOOL)_isEmpty
{
	return (![self _validModifierFlags: keyCombo.flags] || ![[self _stringForKeyCode: keyCombo.code] length]);
}

@end

