//
//  AppDelegate.h
//  Jumpcut
//
//  Created by Steve Cook on 9/11/18.
//  Copyright © 2018 Steve Cook. All rights reserved.
//

#import "BezelWindow.h"
#import "JumpcutClipping.h"
#import "JumpcutStore.h"
#import <ShortcutRecorder/SRCommon.h>
#import <ShortcutRecorder/SRRecorderControl.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong, nonatomic) IBOutlet NSMenu *statusMenu;
@property (assign) IBOutlet NSWindow *prefsPanel;
@property (assign) IBOutlet NSSegmentedControl *launchAtLoginButton;

// Preference related
-(IBAction) showPreferencePanel:(id)sender;

// Pasteboard and stack
-(void) pollPasteboard:(NSTimer *)timer;
-(void) saveEngine;

// Bezel related
-(void) showBezel;
-(void) hideBezel;
-(void) processBezelKeyDown:(NSEvent *)theEvent;
-(void) metaKeysReleased;

// Other actions
-(IBAction) clearClippingList:(id)sender;
-(IBAction) toggleLaunchAtLogin:(id)sender;
-(IBAction) switchMenuIcon:(id)sender;
-(void) keyboardInputSourceChanged:(NSNotification *)notification;

@end

