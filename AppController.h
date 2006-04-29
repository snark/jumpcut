//
//  AppController.h
//  Snapback
//
//  Created by Steve Cook on 4/3/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import "BezelWindow.h"
#import "ShortcutRecorder.h"
#import "JumpcutStore.h"

@class PTHotKey;

@interface AppController : NSObject {
    BezelWindow					*bezel;
	PTHotKey					*mainHotKey;
	IBOutlet ShortcutRecorder	*mainRecorder;
	IBOutlet NSPanel			*prefsPanel;
	int							mainHotkeyModifiers;
	NSNotificationCenter		*nc;
	BOOL						isBezelDisplayed;
	BOOL						isBezelPinned; // Currently not used

	int							stackPosition;
	
	// The below were pulled in from JumpcutController
	JumpcutStore				*clippingStore;
	

    // Status item -- the little icon in the menu bar
    NSStatusItem *statusItem;
    // The menu attatched to same
    IBOutlet NSMenu *jcMenu;
    // A timer which will let us check the pasteboard;
    // this should default to every .5 seconds but be user-configurable
    NSTimer *pollPBTimer;
    // We want an interface to the pasteboard
    NSPasteboard *jcPasteboard;
    // Track the clipboard count so we only act when its contents change
    NSNumber *pbCount;
    //stores PasteboardCount for internal Jumpcut pasteboard actions so they don't trigger any events
    NSNumber *pbBlockCount;
    //Preferences
    int jcDisplayNum;
    NSString *savePreference;
}

- (IBAction)toggleMainHotKey:(id)sender;
- (void)hitMainHotKey:(PTHotKey *)hotKey;

- (void)showBezel;
- (void)hideBezel;
- (void)processBezelKeyDown:(NSEvent *)theEvent;
- (void)metaKeysReleased;

-(IBAction) showPreferencePanel:(id)sender;

// Menu related
- (void)updateMenu;

//add a clipping to the pasteboard
-(NSString *) clippingStringWithCount:(int)count;
-(BOOL)addClipToPasteboardFromCount:(int)indexInt;
-(void)setPBBlockCount:(NSNumber *)newPBBlockCount;

-(IBAction)addClipToPasteboardFromMenu:(id)sender;

-(void)pollPB:(NSTimer *)timer;

-(BOOL) isValidClippingNumber:(NSNumber *)number;

// Save and load
-(void) saveEngine;
-(void) loadEngineFromPList;

- (IBAction)dummyShow:(id)sender;
- (IBAction)dummyHide:(id)sender;

@end
