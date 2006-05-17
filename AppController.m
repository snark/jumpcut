//
//  AppController.m
//  Jumpcut
//
//  Created by Steve Cook on 4/3/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//
//  This code is open-source software subject to the MIT License; see the homepage
//  at <http://jumpcut.sourceforge.net/> for details.

#import "AppController.h"
#import "PTHotKey.h"
#import "PTHotKeyCenter.h"

#define _DISPLAY 15
#define _DISPLENGTH 40

@implementation AppController

- (void)awakeFromNib
{
	// Set up the bezel window
    NSSize windowSize = NSMakeSize(325.0, 325.0);
    NSSize screenSize = [[NSScreen mainScreen] frame].size;
	NSRect windowFrame = NSMakeRect( (screenSize.width - windowSize.width) / 2,
                                     (screenSize.height - windowSize.height) / 3,
									 windowSize.width, windowSize.height );
	bezel = [[BezelWindow alloc] initWithContentRect:windowFrame
										   styleMask:NSBorderlessWindowMask
											 backing:NSBackingStoreBuffered
											   defer:NO];
	[bezel setDelegate:self];
	// Initialize the JumpcutStore
    clippingStore = [[JumpcutStore alloc] initRemembering:[[NSUserDefaults standardUserDefaults] integerForKey:@"rememberNum"]
											   displaying:[[NSUserDefaults standardUserDefaults] integerForKey:@"displayNum"]
										withDisplayLength:_DISPLENGTH];
	// Create our pasteboard interface
    jcPasteboard = [NSPasteboard generalPasteboard];
    [jcPasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    pbCount = [[NSNumber numberWithInt:[jcPasteboard changeCount]] retain];

	// Build the statusbar menu
    statusItem = [[[NSStatusBar systemStatusBar]
            statusItemWithLength:NSSquareStatusItemLength] retain];
    [statusItem setHighlightMode:YES];
    [statusItem setTitle:[NSString stringWithFormat:@"%C",0x2702]]; 
    [statusItem setMenu:jcMenu];
    [statusItem setEnabled:YES];
	
    // If our preferences indicate that we are saving, load the dictionary from the saved plist
    // and use it to get everything set up.
	if ( [[NSUserDefaults standardUserDefaults] integerForKey:@"savePreference"] >= 1 ) {
		[self loadEngineFromPList];
	}
	
	// Build our listener timer
    pollPBTimer = [[NSTimer scheduledTimerWithTimeInterval:(1.0)
													target:self
												  selector:@selector(pollPB:)
												  userInfo:nil
												   repeats:YES] retain];
	
    // Finish up
    pbBlockCount = [[NSNumber numberWithInt:0] retain];
    [pollPBTimer fire];

	// Stack position starts @ 0 by default
	stackPosition = 0;
	
	NSLog(@"Jumpcut running: init complete.");
		
    [super init];
}

-(IBAction) setRememberNumPref:(id)sender
{
	int choice;
	int newRemember = [sender intValue];
	if ( newRemember < [clippingStore jcListCount] &&
		 ! issuedRememberResizeWarning &&
		 ! [[NSUserDefaults standardUserDefaults] boolForKey:@"stifleRememberResizeWarning"]
		 ) {
		choice = NSRunAlertPanel(@"Resize Stack", 
								 @"Resizing the stack to a value below its present size will cause clippings to be lost.",
								 @"Resize", @"Cancel", @"Don't Warn Me Again");
		if ( choice == NSAlertAlternateReturn ) {
			[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:[clippingStore jcListCount]]
													 forKey:@"rememberNum"];
			[self updateMenu];
			NSLog(@"Alternate - %d", [clippingStore jcListCount]);
			return;
		} else if ( choice == NSAlertOtherReturn ) {
			NSLog(@"Other");
			[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES]
													 forKey:@"stifleRememberResizeWarning"];
		} else {
			issuedRememberResizeWarning = YES;
		}
	}
	if ( newRemember < [[NSUserDefaults standardUserDefaults] integerForKey:@"displayNum"] ) {
		[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:newRemember]
												 forKey:@"displayNum"];
	}
	[clippingStore setRememberNum:newRemember];
	[self updateMenu];
}

-(IBAction) setDisplayNumPref:(id)sender
{
	[self updateMenu];
}

-(IBAction) showPreferencePanel:(id)sender
{
//    if ( ![prefsPanel isVisible] ) {
	[NSApp activateIgnoringOtherApps: YES];
	[prefsPanel makeKeyAndOrderFront:self];
	issuedRememberResizeWarning = NO;
}

- (void)pasteFromStack
{
	if ( [clippingStore jcListCount] > stackPosition ) {
		[self addClipToPasteboardFromCount:stackPosition];
		[self performSelector:@selector(hideApp) withObject:nil afterDelay:0.2];
		[self performSelector:@selector(fakeCommandV) withObject:nil afterDelay:0.2];
	} else {
		[self performSelector:@selector(hideApp) withObject:nil afterDelay:0.2];
	}
}

- (void)metaKeysReleased
{
	if ( ! isBezelPinned ) {
		[self pasteFromStack];
	}
}

-(void)fakeCommandV
	/*" +fakeCommandV synthesizes keyboard events for Cmd-v Paste 
	shortcut. "*/ 
	// Code from a Mark Mason post to Cocoadev-l
	// What are the flaws in this approach?
	//  We don't know whether we can really accept the paste
	//  We have no way of judging whether it's gone through
	//  Simulating keypresses could have oddball consequences (for instance, if something else was trapping control v)
	//  Not all apps may take Command-V as a paste command (xemacs, for instance?)
	// Some sort of AE-based (or System Events-based, or service-based) paste would be preferable in many circumstances.
	// On the other hand, this doesn't require scripting support, should work for Carbon, etc.
	// Ideally, in the future, we will be able to tell from what environment JC was passed the trigger
	// and have different behavior from each.
{ 
	CGPostKeyboardEvent( (CGCharCode)0, (CGKeyCode)55, true ); // Command down
	CGPostKeyboardEvent( (CGCharCode)'v', (CGKeyCode)9, true ); // V down 
	CGPostKeyboardEvent( (CGCharCode)'v', (CGKeyCode)9, false ); //  V up 
	CGPostKeyboardEvent( (CGCharCode)0, (CGKeyCode)55, false ); // Command up
} 

-(void)pollPB:(NSTimer *)timer
{
    NSString *type = [jcPasteboard availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]];
    if ( [pbCount intValue] != [jcPasteboard changeCount] ) {
        // Reload pbCount with the current changeCount
        // Probably poor coding technique, but pollPB should be the only thing messing with pbCount, so it should be okay
        [pbCount release];
        pbCount = [[NSNumber numberWithInt:[jcPasteboard changeCount]] retain];
        if ( type != nil ) {
			NSString *contents = [jcPasteboard stringForType:type];
			if ( contents == nil ) {
                NSLog(@"Contents: Empty");
            } else {
				if (( [clippingStore jcListCount] == 0 || ! [contents isEqualToString:[clippingStore clippingContentsAtPosition:0]])
					&&  ! [pbCount isEqualTo:pbBlockCount] ) {
//					NSLog(@"New pbCount: %@, pbBlockCount: %@", pbCount, pbBlockCount);
                    [clippingStore addClipping:contents
										ofType:type	];
//					The below tracks our position down down down... Maybe as an option?
//					if ( [clippingStore jcListCount] > 1 ) stackPosition++;
					stackPosition = 0;
                    [self updateMenu];
					if ( [[NSUserDefaults standardUserDefaults] integerForKey:@"savePreference"] >= 2 ) {
                        [self saveEngine];
                    }
                }
            }
        } else {
            // NSLog(@"Contents: Non-string");
        }
    }
	
}

- (void)processBezelKeyDown:(NSEvent *)theEvent
{
	// AppControl should only be getting these directly from bezel via delegation
	if ( [theEvent type] == NSKeyDown )
	{
		unichar pressed = [[theEvent characters] characterAtIndex:0];
		switch ( pressed ) {
			case NSUpArrowFunctionKey: 
			case NSLeftArrowFunctionKey: 
				// We don't need to check to see if the positions above still exist
				// since we're coming from a valid stackPosition -- 
				// however, we'll need to make sure that we check the stackPosition's
				// validity whenever we delete a clipping (or multiple clippings).
				stackPosition--; if ( stackPosition < 0 ) stackPosition = 0;
				[bezel setCharString:[NSString stringWithFormat:@"%d", stackPosition + 1]];
				[bezel setText:[clippingStore clippingContentsAtPosition:stackPosition]];
				break;
			case NSDownArrowFunctionKey: 
			case NSRightArrowFunctionKey:
				stackPosition++;
				if ( [clippingStore jcListCount] > stackPosition ) {
					[bezel setCharString:[NSString stringWithFormat:@"%d", stackPosition + 1]];
					[bezel setText:[clippingStore clippingContentsAtPosition:stackPosition]];
				} else {
					stackPosition--;
				}
				break;
			case 0x3: case 0xD:
				[self pasteFromStack];
				break;
			case NSBackspaceCharacter: NSLog(@"Backspace pressed"); break;
            case NSDeleteCharacter: NSLog(@"Delete pressed"); break;
            case NSDeleteFunctionKey: NSLog(@"Delete pressed"); break;
			case 0x1B:
				[self hideApp];
				break;
            default: // It's not a navigation/application-defined thing, so let's figure out what it is.
				NSLog(@"%d", pressed);
				break;
		}		
	}
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	//Create our hot key
	mainHotKey = [[PTHotKey alloc] initWithIdentifier:@"mainHotKey"
											   keyCombo:[PTKeyCombo keyComboWithKeyCode:[mainRecorder keyCombo].code
																			  modifiers:[mainRecorder cocoaToCarbonFlags: [mainRecorder keyCombo].flags]]];
	mainHotkeyModifiers = [mainRecorder cocoaToCarbonFlags:[mainRecorder keyCombo].flags];
	NSLog(@"Hotkey modifiers: %d", mainHotkeyModifiers);
	[mainHotKey setName: @"Activate Bezel HotKey"]; //This is typically used by PTKeyComboPanel
	[mainHotKey setTarget: self];
	[mainHotKey setAction: @selector( hitMainHotKey: ) ];
	
	//Register it
	[[PTHotKeyCenter sharedCenter] registerHotKey: mainHotKey];
}

- (void) showBezel
{
	if ( [clippingStore jcListCount] > 0 && [clippingStore jcListCount] > stackPosition ) {
		[bezel setCharString:[NSString stringWithFormat:@"%d", stackPosition + 1]];
		[bezel setText:[clippingStore clippingContentsAtPosition:stackPosition]];
	} 
	[bezel makeKeyAndOrderFront:nil];
	isBezelDisplayed = YES;
}

- (void) hideBezel
{
	[bezel orderOut:nil];
	[bezel setCharString:@""];
	isBezelDisplayed = NO;
}

-(void)hideApp
{
    [self hideBezel];
	isBezelPinned = NO;
	[NSApp hide:self];
}

- (void) applicationWillResignActive:(NSApplication *)app; {
	// This should be hidden anyway, but just in case it's not.
    [self hideBezel];
}


- (void)hitMainHotKey:(PTHotKey *)hotKey
{
	if ( ! isBezelDisplayed ) {
		[NSApp activateIgnoringOtherApps:YES];
		if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"stickyBezel"] ) {
			isBezelPinned = YES;
		}
		[self showBezel];
	} else {
		stackPosition++;
		if ( [clippingStore jcListCount] > stackPosition ) {
			[bezel setCharString:[NSString stringWithFormat:@"%d", stackPosition + 1]];
			[bezel setText:[clippingStore clippingContentsAtPosition:stackPosition]];
		} else {
			stackPosition--;
		}
	}
}

- (IBAction)toggleMainHotKey:(id)sender
{
	if (mainHotKey != nil)
	{
		[[PTHotKeyCenter sharedCenter] unregisterHotKey:mainHotKey];
		[mainHotKey release];
		mainHotKey = nil;
	}
	
	mainHotKey = [[PTHotKey alloc] initWithIdentifier:@"mainHotKey"
											   keyCombo:[PTKeyCombo keyComboWithKeyCode:[mainRecorder keyCombo].code
																			  modifiers:[mainRecorder cocoaToCarbonFlags: [mainRecorder keyCombo].flags]]];
	
	[mainHotKey setTarget: self];
	[mainHotKey setAction: @selector(hitMainHotKey:)];
	
	[[PTHotKeyCenter sharedCenter] registerHotKey:mainHotKey];
}

-(IBAction)clearClippingList:(id)sender {
    int choice;
	
	[NSApp activateIgnoringOtherApps:YES];
    choice = NSRunAlertPanel(@"Clear Clipping List", 
							 @"Do you want to clear all recent clippings?",
							 @"Clear", @"Cancel", nil);
	
    // on clear, zap the list and redraw the menu
    if ( choice == NSAlertDefaultReturn ) {
        [clippingStore clearList];
        [self updateMenu];
		if ( [[NSUserDefaults standardUserDefaults] integerForKey:@"savePreference"] >= 1 ) {
			[self saveEngine];
		}
    }
}

- (void)updateMenu {
    int passedSeparator = 0;
    NSMenuItem *oldItem;
    NSMenuItem *item;
    NSString *pbMenuTitle;
    NSArray *returnedDisplayStrings = [clippingStore previousDisplayStrings:[[NSUserDefaults standardUserDefaults] integerForKey:@"displayNum"]];
    NSEnumerator *menuEnumerator = [[jcMenu itemArray] reverseObjectEnumerator];
    NSEnumerator *clipEnumerator = [returnedDisplayStrings reverseObjectEnumerator];
	
    //remove clippings from menu
    while( oldItem = [menuEnumerator nextObject] ) {
		if( [oldItem isSeparatorItem]) {
            passedSeparator++;
        } else if ( passedSeparator == 2 ) {
            [jcMenu removeItem:oldItem];
        }
    }
	
	
    while( pbMenuTitle = [clipEnumerator nextObject] ) {
        item = [[NSMenuItem alloc] initWithTitle:pbMenuTitle
										  action:@selector(processMenuClippingSelection:)
								   keyEquivalent:@""];
        [item setTarget:self];
        [item setEnabled:YES];
        [jcMenu insertItem:item atIndex:0];
        // Way back in 0.2, failure to release the new item here was causing a quite atrocious memory leak.
        [item release];
	} 
}

-(IBAction)processMenuClippingSelection:(id)sender
{
    int index=[[sender menu] indexOfItem:sender];
    [self addClipToPasteboardFromCount:index];
	if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"menuSelectionPastes"] ) {
		[self performSelector:@selector(hideApp) withObject:nil];
		[self performSelector:@selector(fakeCommandV) withObject:nil afterDelay:0.2];
	}
}

-(BOOL) isValidClippingNumber:(NSNumber *)number {
    return ( ([number intValue] + 1) <= [clippingStore jcListCount] );
}

-(NSString *) clippingStringWithCount:(int)count {
    if ( [self isValidClippingNumber:[NSNumber numberWithInt:count]] ) {
        return [clippingStore clippingContentsAtPosition:count];
    } else { // It fails -- we shouldn't be passed this, but...
        NSLog(@"Asked for non-existant clipping count: %d");
        return @"";
    }
}

-(void) setPBBlockCount:(NSNumber *)newPBBlockCount
{
    [newPBBlockCount retain];
    [pbBlockCount release];
    pbBlockCount = newPBBlockCount;
}

-(BOOL)addClipToPasteboardFromCount:(int)indexInt
{
    NSString *pbFullText;
    NSArray *pbTypes;
    if ( (indexInt + 1) > [clippingStore jcListCount] ) {
        // We're asking for a clipping that isn't there yet
		// This only tends to happen immediately on startup when not saving, as the entire list is empty.
        NSLog(@"Out of bounds request to jcList ignored.");
        return false;
    }
    pbFullText = [self clippingStringWithCount:indexInt];
    pbTypes = [NSArray arrayWithObjects:@"NSStringPboardType",NULL];
    
    [jcPasteboard declareTypes:pbTypes owner:NULL];
	
    [jcPasteboard setString:pbFullText forType:@"NSStringPboardType"];
    [self setPBBlockCount:[NSNumber numberWithInt:[jcPasteboard changeCount]]];
    return true;
}

-(void) loadEngineFromPList
{
    NSString *path = [[NSString stringWithString:@"~/Library/Application Support/Jumpcut/JCEngine.save"] 					stringByExpandingTildeInPath];
    NSDictionary *loadDict = [[NSDictionary alloc] initWithContentsOfFile:path];
    NSEnumerator *enumerator;
    NSDictionary *aSavedClipping;
    NSArray *savedJCList;
	NSRange loadRange;
	int rangeCap;
	if ( loadDict != nil ) {
        savedJCList = [loadDict objectForKey:@"jcList"];
        if ( [savedJCList isKindOfClass:[NSArray class]] ) {
			// There's probably a nicer way to prevent the range from going out of bounds, but this works.
			rangeCap = [savedJCList count] < [[NSUserDefaults standardUserDefaults] integerForKey:@"rememberNum"] ? [savedJCList count] : [[NSUserDefaults standardUserDefaults] integerForKey:@"rememberNum"];
			loadRange = NSMakeRange(0, rangeCap);
			enumerator = [[savedJCList subarrayWithRange:loadRange] reverseObjectEnumerator];
			while ( aSavedClipping = [enumerator nextObject] ) {
				[clippingStore addClipping:[aSavedClipping objectForKey:@"Contents"]
									ofType:[aSavedClipping objectForKey:@"Type"]];
            }
        } else {
			NSLog(@"Not array");
		}
        NSLog(@"Contents loaded from file.");
        [self updateMenu];
        [loadDict release];
    }
}

-(void) saveEngine
{
    NSMutableDictionary *saveDict;
    NSMutableArray *jcListArray = [NSMutableArray array];
    int i;
    BOOL isDir;
    NSString *path;
    path = [[NSString stringWithString:@"~/Library/Application Support/Jumpcut"] stringByExpandingTildeInPath];
    if ( ![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] || ! isDir ) {
        NSLog(@"Creating Application Support directory");
        [[NSFileManager defaultManager] createDirectoryAtPath:path
												   attributes:[NSDictionary dictionaryWithObjectsAndKeys:
													   @"NSFileModificationDate", [NSNull null],
													   @"NSFileOwnerAccountName", [NSNull null],
													   @"NSFileGroupOwnerAccountName", [NSNull null],
													   @"NSFilePosixPermissions", [NSNull null],
													   @"NSFileExtensionsHidden", [NSNull null],
													   nil]
			];
    }
	
    saveDict = [NSMutableDictionary dictionaryWithCapacity:3];
    [saveDict setObject:@"0.60a" forKey:@"version"];
    [saveDict setObject:[NSNumber numberWithInt:[[NSUserDefaults standardUserDefaults] integerForKey:@"rememberNum"]]
                 forKey:@"rememberNum"];
    [saveDict setObject:[NSNumber numberWithInt:_DISPLENGTH]
                 forKey:@"displayLen"];
    [saveDict setObject:[NSNumber numberWithInt:[[NSUserDefaults standardUserDefaults] integerForKey:@"displayNum"]]
                 forKey:@"displayNum"];
    for ( i = 0 ; i < [clippingStore jcListCount]; i++) {
		[jcListArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[clippingStore clippingContentsAtPosition:i], @"Contents",
			[clippingStore clippingTypeAtPosition:i], @"Type",
			[NSNumber numberWithInt:i], @"Position",
			nil
			]
			];
    }
    [saveDict setObject:jcListArray forKey:@"jcList"];
	
    if ( [saveDict writeToFile:[path stringByAppendingString:@"/JCEngine.save"] atomically:true] ) {
		NSLog(@"Engine contents saved.");
    } else {
		NSLog(@"Engine contents NOT saved.");
    }
}


- (BOOL)shortcutRecorder:(ShortcutRecorder *)aRecorder isKeyCode:(signed short)keyCode andFlagsTaken:(unsigned int)flags reason:(NSString **)aReason
{
	if (aRecorder == mainRecorder)
	{
		BOOL isTaken = NO;
/*		
		KeyCombo kc = [delegateDisallowRecorder keyCombo];
		
		if (kc.code == keyCode && kc.flags == flags) isTaken = YES;
		
		*aReason = [delegateDisallowReasonField stringValue];
*/		
		return isTaken;
	}
	
	return NO;
}

- (void)shortcutRecorder:(ShortcutRecorder *)aRecorder keyComboDidChange:(KeyCombo)newKeyCombo
{
	if (aRecorder == mainRecorder)
	{
		[self toggleMainHotKey: aRecorder];
	}
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app {
    // if we wanted to cancel, we would:
    //   return NSTerminateLater;
    // That might be useful for us at some point.
	if ( [[NSUserDefaults standardUserDefaults] integerForKey:@"savePreference"] >= 1 ) {
        [self saveEngine];
    }
    return NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	//Unregister our hot key (not required)
	[[PTHotKeyCenter sharedCenter] unregisterHotKey: mainHotKey];
	
	//Memory cleanup
	[mainHotKey release];
	mainHotKey = nil;
	[nc removeObserver:self];
	
	[self hideBezel];
	[bezel release];
}

@end
