//
//  ShortcutRecorderCell.h
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

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <CoreServices/CoreServices.h>

typedef struct _KeyCombo {
	unsigned int flags; // 0 for no flags
	signed short code; // -1 for no code
} KeyCombo;

static KeyCombo SRMakeKeyCombo(signed short code, unsigned int flags) {
	KeyCombo kc;
	kc.code = code;
	kc.flags = flags;
	return kc;
}

#define SRMinWidth 50
#define SRMaxHeight 22

@class ShortcutRecorder, CTGradient;

@interface ShortcutRecorderCell : NSActionCell <NSCoding>
{	
	CTGradient *recordingGradient;
	NSString *autosaveName;

	BOOL isRecording;
	BOOL mouseInsideTrackingArea;
	BOOL mouseDown;
	
	NSTrackingRectTag removeTrackingRectTag;
	NSTrackingRectTag snapbackTrackingRectTag;
	
	KeyCombo keyCombo;
	
	unsigned int allowedFlags;
	unsigned int requiredFlags;
	unsigned int recordingFlags;
	
	NSSet *cancelCharacterSet;
	NSDictionary *keyCodeToStringDict;
	NSArray *padKeysArray;
	
	IBOutlet id delegate;
}

- (void)resetTrackingRects;

#pragma mark *** Delegate ***

- (id)delegate;
- (void)setDelegate:(id)aDelegate;

#pragma mark *** Key Combination Control ***

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent;
- (void)flagsChanged:(NSEvent *)theEvent;

- (unsigned int)allowedFlags;
- (void)setAllowedFlags:(unsigned int)flags;

- (unsigned int)requiredFlags;
- (void)setRequiredFlags:(unsigned int)flags;

- (KeyCombo)keyCombo;
- (void)setKeyCombo:(KeyCombo)aKeyCombo;

#pragma mark *** Autosave Control ***

- (NSString *)autosaveName;
- (void)setAutosaveName:(NSString *)aName;

// Returns the displayed key combination if set
- (NSString *)keyComboString;

#pragma mark *** Conversion Methods ***

- (unsigned int)cocoaToCarbonFlags:(unsigned int)cocoaFlags;
- (unsigned int)carbonToCocoaFlags:(unsigned int)carbonFlags;

@end

// Delegate Methods
@interface NSObject (ShortcutRecorderCellDelegate)
- (BOOL)shortcutRecorderCell:(ShortcutRecorderCell *)aRecorderCell isKeyCode:(signed short)keyCode andFlagsTaken:(unsigned int)flags reason:(NSString **)aReason;
- (void)shortcutRecorderCell:(ShortcutRecorderCell *)aRecorderCell keyComboDidChange:(KeyCombo)newCombo;
@end