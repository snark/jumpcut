//
//  ShortcutRecorder.m
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

#import "ShortcutRecorder.h"

#define SRCell (ShortcutRecorderCell *)[self cell]

@interface ShortcutRecorder (Private)
- (void)resetTrackingRects;
@end

@implementation ShortcutRecorder

+ (void)initialize
{
    if (self == [ShortcutRecorder class])
	{
        [self setCellClass: [ShortcutRecorderCell class]];
    }
}

+ (Class)cellClass
{
    return [ShortcutRecorderCell class];
}

- (id)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame: frameRect];
	
	[SRCell setDelegate: self];
	
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder: aDecoder];
	
	[SRCell setDelegate: self];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[super encodeWithCoder: aCoder];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

#pragma mark *** Cell Behavior ***

// We need keyboard access
- (BOOL)acceptsFirstResponder
{
    return YES;
}

// Allow the control to be activated with the first click on it even if it's window isn't the key window
- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	return YES;
}

#pragma mark *** Interface Stuff ***

// If the control is set to be resizeable in width, this will make sure that the tracking rects are always updated
- (void)viewDidMoveToWindow
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center removeObserver: self];
	[center addObserver:self selector:@selector(viewFrameDidChange:) name:NSViewFrameDidChangeNotification object:self];
	
	[self resetTrackingRects];
}

- (void)viewFrameDidChange:(NSNotification *)aNotification
{
	[self resetTrackingRects];
}

// Prevent from being too small
- (void)setFrameSize:(NSSize)newSize
{
	NSSize correctedSize = newSize;
	correctedSize.height = SRMaxHeight;
	if (correctedSize.width < SRMinWidth) correctedSize.width = SRMinWidth;
	
	[super setFrameSize: correctedSize];
}

- (void)setFrame:(NSRect)frameRect
{
	NSRect correctedFrarme = frameRect;
	correctedFrarme.size.height = SRMaxHeight;
	if (correctedFrarme.size.width < SRMinWidth) correctedFrarme.size.width = SRMinWidth;

	[super setFrame: correctedFrarme];
}

#pragma mark *** Key Interception ***

// Like most NSControls, pass things on to the cell
- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{	
	if ([SRCell performKeyEquivalent:theEvent]) return YES;

	return [super performKeyEquivalent: theEvent];
}

- (void)flagsChanged:(NSEvent *)theEvent
{
	[SRCell flagsChanged:theEvent];
}

- (void)keyDown:(NSEvent *)theEvent
{
	[self performKeyEquivalent: theEvent];
}

#pragma mark *** Key Combination Control ***

- (unsigned int)allowedFlags
{
	return [SRCell allowedFlags];
}

- (void)setAllowedFlags:(unsigned int)flags
{
	[SRCell setAllowedFlags: flags];
}

- (unsigned int)requiredFlags
{
	return [SRCell requiredFlags];
}

- (void)setRequiredFlags:(unsigned int)flags
{
	[SRCell setRequiredFlags: flags];
}

- (KeyCombo)keyCombo
{
	return [SRCell keyCombo];
}

- (void)setKeyCombo:(KeyCombo)aKeyCombo
{
	[SRCell setKeyCombo: aKeyCombo];
}

#pragma mark *** Autosave Control ***

- (NSString *)autosaveName
{
	return [SRCell autosaveName];
}

- (void)setAutosaveName:(NSString *)aName
{
	[SRCell setAutosaveName: aName];
}

#pragma mark -

- (NSString *)keyComboString
{
	return [SRCell keyComboString];
}

#pragma mark *** Conversion Methods ***

- (unsigned int)cocoaToCarbonFlags:(unsigned int)cocoaFlags
{
	return [SRCell cocoaToCarbonFlags: cocoaFlags];
}

- (unsigned int)carbonToCocoaFlags:(unsigned int)carbonFlags;
{
	return [SRCell carbonToCocoaFlags: carbonFlags];
}

#pragma mark *** Delegate ***

// Only the delegate will be handled by the control
- (id)delegate
{
	return delegate;
}

- (void)setDelegate:(id)aDelegate
{
	delegate = aDelegate;
}

#pragma mark *** Delegate pass-through ***

- (BOOL)shortcutRecorderCell:(ShortcutRecorderCell *)aRecorderCell isKeyCode:(signed short)keyCode andFlagsTaken:(unsigned int)flags reason:(NSString **)aReason
{
	if (delegate != nil && [delegate respondsToSelector: @selector(shortcutRecorder:isKeyCode:andFlagsTaken:reason:)])
		return [delegate shortcutRecorder:self isKeyCode:keyCode andFlagsTaken:flags reason:aReason];
	else
		return NO;
}

- (void)shortcutRecorderCell:(ShortcutRecorderCell *)aRecorderCell keyComboDidChange:(KeyCombo)newKeyCombo
{
	if (delegate != nil && [delegate respondsToSelector: @selector(shortcutRecorder:keyComboDidChange:)])
		[delegate shortcutRecorder:self keyComboDidChange:newKeyCombo];
}

@end

@implementation ShortcutRecorder (Private)

- (void)resetTrackingRects
{
	[SRCell resetTrackingRects];
}

@end