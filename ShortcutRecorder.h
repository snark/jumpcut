//
//  ShortcutRecorder.h
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
#import "ShortcutRecorderCell.h"

@interface ShortcutRecorder : NSControl
{
	IBOutlet id delegate;
}

#pragma mark *** Delegate ***
- (id)delegate;
- (void)setDelegate:(id)aDelegate;

#pragma mark *** Key Combination Control ***

- (unsigned int)allowedFlags;
- (void)setAllowedFlags:(unsigned int)flags;

- (unsigned int)requiredFlags;
- (void)setRequiredFlags:(unsigned int)flags;

- (KeyCombo)keyCombo;
- (void)setKeyCombo:(KeyCombo)aKeyCombo;

#pragma mark *** Autosave Control ***

- (NSString *)autosaveName;
- (void)setAutosaveName:(NSString *)aName;

#pragma mark -

// Returns the displayed key combination if set
- (NSString *)keyComboString;

#pragma mark *** Conversion Methods ***

- (unsigned int)cocoaToCarbonFlags:(unsigned int)cocoaFlags;
- (unsigned int)carbonToCocoaFlags:(unsigned int)carbonFlags;

@end

// Delegate Methods
@interface NSObject (ShortcutRecorderDelegate)
- (BOOL)shortcutRecorder:(ShortcutRecorder *)aRecorder isKeyCode:(signed short)keyCode andFlagsTaken:(unsigned int)flags reason:(NSString **)aReason;
- (void)shortcutRecorder:(ShortcutRecorder *)aRecorder keyComboDidChange:(KeyCombo)newKeyCombo;
@end
