//
//  BezelWindow.m
//  Jumpcut
//
//  Created by Steve Cook on 4/3/06.
//  Copyright 2006 Steve Cook. All rights reserved.
//
//  This code is open-source software subject to the MIT License; see the homepage
//  at <http://jumpcut.sourceforge.net/> for details.

#import "BezelWindow.h"

@implementation BezelWindow

- (id)initWithContentRect:(NSRect)contentRect
				styleMask:(unsigned int)aStyle
  				backing:(NSBackingStoreType)bufferingType
					defer:(BOOL)flag
{
	self = [super initWithContentRect:contentRect
							styleMask:NSBorderlessWindowMask
							backing:NSBackingStoreBuffered
							defer:NO];
	if ( self )
	{
		[self setBackgroundColor: [NSColor clearColor]];
		[self setOpaque:NO];
		[self setAlphaValue:1.0];
		[self setOpaque:NO];
		[self setHasShadow:NO];
		[self setMovableByWindowBackground:NO];
		[self setBackgroundColor:[self sizedBezelBackgroundWithRadius:25.0 withAlpha:0.25]];
		float textHeight = 128;
		NSRect textFrame = NSMakeRect(12, 12, [self frame].size.width - 24, textHeight);
		textField = [[[RoundRecTextField alloc] initWithFrame:textFrame] retain];
		[[self contentView] addSubview:textField];
		[textField setEditable:NO];
		[textField setTextColor:[NSColor whiteColor]];
		[textField setBackgroundColor:[NSColor colorWithCalibratedWhite:0.1 alpha:.45]];
		[textField setDrawsBackground:YES];
		[textField setBordered:NO];
		[textField setAlignment:NSCenterTextAlignment];
		[textField setStringValue:@"The way we set up our retains and releases results in a particular behavior. This behavior is that the previous path drawn will be cleared the next time we click and drag the mouse. You can juggle things around a bit to never clear the path and to always add elements to the path, or you might come up with something else."];
		[self setInitialFirstResponder:textField];
		return self;
	}
	return nil;
}

- (NSString *)title
{
	return title;
}

- (void)setTitle:(NSString *)newTitle
{
	title = newTitle;
}

- (void)setFrame:(NSRect)frameRect display:(BOOL)displayFlag animate:(BOOL)animationFlag
{
	[super setFrame:frameRect display:displayFlag animate:animationFlag];
}

- (NSColor *)roundedBackgroundWithRect:(NSRect)bgRect withRadius:(float)radius withAlpha:(float)alpha
{
	NSImage *bg = [[NSImage alloc] initWithSize:bgRect.size];
	[bg lockFocus];
	// I'm not at all clear why this seems to work
	NSRect dummyRect = NSMakeRect(0, 0, [bg size].width, [bg size].height);
	NSBezierPath *roundedRec = [NSBezierPath bezierPathWithRoundRectInRect:dummyRect radius:radius];
	[[NSColor colorWithCalibratedWhite:0.1 alpha:alpha] set];
    [roundedRec fill];
	[bg unlockFocus];
	return [NSColor colorWithPatternImage:[bg autorelease]];
}

- (NSColor *)sizedBezelBackgroundWithRadius:(float)radius withAlpha:(float)alpha
{
	return [self roundedBackgroundWithRect:[self frame] withRadius:radius withAlpha:alpha];
}

-(BOOL)canBecomeKeyWindow
{
	return YES;
}

- (void)dealloc
{
	[textField release];
	[super dealloc];
}

- (BOOL)performKeyEquivalent:(NSEvent*) theEvent
{
	if ( [self delegate] )
	{
		[delegate performSelector:@selector(processBezelKeyDown:) withObject:theEvent];
		return YES;
	}
	return NO;
}

- (void)keyDown:(NSEvent *)theEvent {
	if ( [self delegate] )
	{
		[delegate performSelector:@selector(processBezelKeyDown:) withObject:theEvent];
	}
}

- (void)flagsChanged:(NSEvent *)theEvent {
	if ( !    ( [theEvent modifierFlags] & NSCommandKeyMask )
		 && ! ( [theEvent modifierFlags] & NSAlternateKeyMask )
		 && ! ( [theEvent modifierFlags] & NSControlKeyMask )
		 && ! ( [theEvent modifierFlags] & NSShiftKeyMask )
		 && [ self delegate ]
		 )
	{
		[delegate performSelector:@selector(metaKeysReleased)];
	}
}
		
- (id)delegate {
    return delegate;
}

- (void)setDelegate:(id)newDelegate {
    delegate = newDelegate;
}


@end
