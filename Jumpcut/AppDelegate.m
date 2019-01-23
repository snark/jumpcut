//
//  AppDelegate.m
//  Jumpcut
//
//  Created by Steve Cook on 9/11/18.
//  Copyright © 2018 Steve Cook. All rights reserved.
//

#import "AppDelegate.h"
#import <ShortcutRecorder/ShortcutRecorder.h>
#import <PTHotKey/PTHotKeyCenter.h>
#import <PTHotKey/PTHotKey+ShortcutRecorder.h>

#define _DISPLENGTH 40

@interface AppDelegate ()
@property BezelWindow *bezel;
@property JumpcutStore *clippingStore;
@property (assign) IBOutlet SRRecorderControl *hotkeyRecorder;
@property BOOL isBezelDisplayed;
@property BOOL isBezelPinned;
@property NSPasteboard *jcPasteboard;
@property unsigned int pbBlockCount;
@property unsigned int pbCount;
@property SRKeyCodeTransformer *shortcutTransformer;
@property signed int stackPosition;
@property NSStatusItem *statusItem;
@property CGKeyCode veeCode;

@end

@implementation AppDelegate

- (void)dealloc
{
    [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:@"values.mainHotkey"];
    [super dealloc];
}

- (id)init
{
    if ( ! [[NSUserDefaults standardUserDefaults] floatForKey:@"lastRun"] || [[NSUserDefaults standardUserDefaults] floatForKey:@"lastRun"] < 0.6  ) {
        // A decent starting value for the main hotkey is control-option-V
        NSDictionary *defaultHotkey = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:9],[NSNumber numberWithInt:786432],nil] forKeys:[NSArray arrayWithObjects:@"keyCode",@"modifierFlags",nil]];
        [[NSUserDefaults standardUserDefaults] setValue:defaultHotkey
                                                 forKey:@"mainHotkey"];

        // Something we'd really like is to transfer over info from 0.5x if we can get at it --
        if ( [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"Jumpcut"] ) {
            // We need to pull out the relevant objects and stuff them in as proper preferences for the net.sf.Jumpcut domain
            if ( [[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"Jumpcut"] objectForKey:@"displayNum"] != nil )
            {
                [[NSUserDefaults standardUserDefaults] setValue:[ [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"Jumpcut"] objectForKey:@"displayNum"]
                                                         forKey:@"displayNum"];
            }
            if ( [[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"Jumpcut"] objectForKey:@"savePreference"] != nil )
            {
                if ( [[[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"Jumpcut"] objectForKey:@"savePreference"] isEqual:@"onChange"] )
                {
                    [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:2]
                                                             forKey:@"savePreference"];
                }
                else if ( [[[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"Jumpcut"] objectForKey:@"savePreference"] isEqual:@"onExit"] )
                {
                    [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:1]
                                                             forKey:@"savePreference"];
                }
                else
                {
                    [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:0]
                                                             forKey:@"savePreference"];
                } // End save preference test
            } // End savePreference test
        } // End if/then that deals with 0.5x preferences
    } // End new-to-version check

    // If we don't have preferences defined, let's set some default values:
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                                             [NSNumber numberWithInt:20],
                                                             @"displayNum",
                                                             [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:9],[NSNumber numberWithInt:786432],nil] forKeys:[NSArray arrayWithObjects:@"keyCode",@"modifierFlags",nil]],
                                                             @"ShortcutRecorder mainHotkey",
                                                             [NSNumber numberWithInt:80],
                                                             @"rememberNum",
                                                             [NSNumber numberWithInt:1],
                                                             @"savePreference",
                                                             [NSNumber numberWithInt:0],
                                                             @"menuIcon",
                                                             [NSNumber numberWithFloat:.25],
                                                             @"bezelAlpha",
                                                             [NSNumber numberWithBool:NO],
                                                             @"stickyBezel",
                                                             [NSNumber numberWithBool:NO],
                                                             @"wraparoundBezel",
                                                             [NSNumber numberWithBool:NO],
                                                             @"launchOnStartup",
                                                             [NSNumber numberWithBool:YES],
                                                             @"menuSelectionPastes",
                                                             [NSNumber numberWithBool:YES],
                                                             @"bezelSelectionPastes",
                                                             [NSNumber numberWithBool:NO],
                                                             @"menuSelectionMovesToTop",
                                                             nil]
    ];
    // TODO: We should look for a change in the keyboard definition and re-run findVeeCode()
    self.veeCode = findVeeCode();
    return [super init];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.jcPasteboard = [NSPasteboard generalPasteboard];
    self.isBezelDisplayed = NO;
    self.isBezelPinned = NO;
    self.pbBlockCount = 0;
    self.pbCount = 0;
    self.shortcutTransformer = [[[SRKeyCodeTransformer alloc] init] retain];
    self.statusItem = [[NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength] retain];
    self.statusItem.title = @"✂";
    self.statusItem.menu = self.statusMenu;
    if ([self.bezel respondsToSelector:@selector(setCollectionBehavior:)]) {
        [self.bezel setCollectionBehavior:NSWindowCollectionBehaviorTransient | NSWindowCollectionBehaviorIgnoresCycle | NSWindowCollectionBehaviorFullScreenAuxiliary | NSWindowCollectionBehaviorMoveToActiveSpace];
    }
    [self.bezel setHidesOnDeactivate: YES];
}

- (void)applicationWillResignActive:(NSNotification *)aNotification {
    // If, e.g., Expose has just fired and we've lost focus, make sure our bezel is aware of the fact.
    if (self.isBezelDisplayed) {
        [self hideBezel];
    }
}

-(IBAction) activateAndOrderFrontStandardAboutPanel:(id)sender
{
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[NSApplication sharedApplication] orderFrontStandardAboutPanel:sender];
}

CGKeyCode findVeeCode() {
    // Under ShortcutRecord 1, there was a programatic method to determine a keyCode for a given character.
    // This no longer exists in the 64-bit-compatible ShortcutRecorder 2, so we need to do a quick check to
    // determine what matches "v"; this is 9 in the default case of English, QWERTY keyboards, which we optimize
    // for.
    CGKeyCode testCode = (CGKeyCode)9;
    unsigned int i;
    NSString *testVee = keyCodeToString(testCode);
    if ([testVee isEqualTo:@"v"]) {
        return testCode;
    }
    // Having failed that, iterate through every available keycode, 0-127, until we find "v".
    for (i = 0; i < 128; ++i) {
        testCode = (CGKeyCode)i;
        testVee = keyCodeToString(testCode);
        if ([testVee isEqualTo:@"v"]) {
            return testCode;
        }
    }
    // Something has gone tragically wrong. Do our best.
    return (CGKeyCode)9;
}

NSString* keyCodeToString(CGKeyCode keyCode) {
    // Code taken from https://stackoverflow.com/questions/1918841/how-to-convert-ascii-character-to-cgkeycode
    TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
    CFDataRef uchr =
    (CFDataRef)TISGetInputSourceProperty(currentKeyboard,
                                         kTISPropertyUnicodeKeyLayoutData);
    const UCKeyboardLayout *keyboardLayout =
    (const UCKeyboardLayout*)CFDataGetBytePtr(uchr);

    if(keyboardLayout)
    {
        UInt32 deadKeyState = 0;
        UniCharCount maxStringLength = 255;
        UniCharCount actualStringLength = 0;
        UniChar unicodeString[maxStringLength];

        OSStatus status = UCKeyTranslate(keyboardLayout,
                                         keyCode, kUCKeyActionDown, 0,
                                         LMGetKbdType(), 0,
                                         &deadKeyState,
                                         maxStringLength,
                                         &actualStringLength, unicodeString);

        if (actualStringLength == 0 && deadKeyState)
        {
            status = UCKeyTranslate(keyboardLayout,
                                    kVK_Space, kUCKeyActionDown, 0,
                                    LMGetKbdType(), 0,
                                    &deadKeyState,
                                    maxStringLength,
                                    &actualStringLength, unicodeString);
        }
        if(actualStringLength > 0 && status == noErr)
            return [[NSString stringWithCharacters:unicodeString
                                            length:(NSUInteger)actualStringLength] lowercaseString];
    }

    return nil;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    if ( [[NSUserDefaults standardUserDefaults] integerForKey:@"savePreference"] >= 1 ) {
        [self saveEngine] ;
    }
}

- (void)awakeFromNib
{
    NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
    
    // Set up the bezel window
    NSSize windowSize = NSMakeSize(325.0, 325.0);
    NSSize screenSize = [[NSScreen mainScreen] frame].size;
    NSRect windowFrame = NSMakeRect( (screenSize.width - windowSize.width) / 2,
                                    (screenSize.height - windowSize.height) / 3,
                                    windowSize.width, windowSize.height );
    self.bezel = [[BezelWindow alloc] initWithContentRect:windowFrame
                                                styleMask:NSWindowStyleMaskBorderless
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    [self.bezel setDelegate:self];
    // Initiate our store
    self.clippingStore = [[JumpcutStore alloc] initRemembering:(int)[[NSUserDefaults standardUserDefaults] integerForKey:@"rememberNum"]
                                                    displaying:(int)[[NSUserDefaults standardUserDefaults] integerForKey:@"displayNum"]
                                             withDisplayLength:_DISPLENGTH];
    // If our preferences indicate that we are saving, load the dictionary from the saved plist
    // and use it to get everything set up.
    if ([[NSUserDefaults standardUserDefaults] integerForKey:@"savePreference"] >= 1) {
        [self loadEngineFromPList];
    }
    

    // Set up the hotkey and hotkey observer
    [self.hotkeyRecorder bind:NSValueBinding
                     toObject:defaults
                  withKeyPath:@"values.mainHotkey"
                      options:nil];
    [defaults addObserver:self forKeyPath:@"values.mainHotkey" options:NSKeyValueObservingOptionInitial context:NULL];
    // Build our listener
    [self.jcPasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [[[NSTimer scheduledTimerWithTimeInterval:(1.0)
                                       target:self
                                     selector:@selector(pollPasteboard:)
                                     userInfo:nil
                                      repeats:YES] retain] fire];
}

/* Hotkey handler */
- (void)observeValueForKeyPath:(NSString *)aKeyPath ofObject:(id)anObject change:(NSDictionary *)aChange context:(void *)aContext
{
    if ([aKeyPath isEqualToString:@"values.mainHotkey"])
    {
        PTHotKeyCenter *hotKeyCenter = [PTHotKeyCenter sharedCenter];
        PTHotKey *oldHotKey = [hotKeyCenter hotKeyWithIdentifier:aKeyPath];
        [hotKeyCenter unregisterHotKey:oldHotKey];
        
        NSDictionary *newShortcut = [anObject valueForKeyPath:aKeyPath];
        
        if (newShortcut && (NSNull *)newShortcut != [NSNull null])
        {
            PTHotKey *newHotKey = [PTHotKey hotKeyWithIdentifier:aKeyPath
                                                        keyCombo:newShortcut
                                                          target:self
                                                          action:@selector(hitMainHotkey:)];
            [hotKeyCenter registerHotKey:newHotKey];
        }
    }
    else
        [super observeValueForKeyPath:aKeyPath ofObject:anObject change:aChange context:aContext];
}

- (IBAction)hitMainHotkey:(id)aSender
{
    if ( ! self.isBezelDisplayed ) {
        [NSApp activateIgnoringOtherApps:YES];
        // SBC do we care about this?
        /*
         if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"stickyBezel"] ) {
         isBezelPinned = YES;
         }
         */
        [self showBezel];
    } else {
        [self stackDown];
    }
}

- (void)updateMenu {
    int passedSeparator = 0;
    NSMenuItem *oldItem;
    NSMenuItem *item;
    NSString *pbMenuTitle;
    NSArray *returnedDisplayStrings = [self.clippingStore previousDisplayStrings:(int)[[NSUserDefaults standardUserDefaults] integerForKey:@"displayNum"]];
    NSEnumerator *menuEnumerator = [[self.statusMenu itemArray] reverseObjectEnumerator];
    NSEnumerator *clipEnumerator = [returnedDisplayStrings reverseObjectEnumerator];

    //remove clippings from menu
    while( oldItem = [menuEnumerator nextObject] ) {
        if( [oldItem isSeparatorItem]) {
            passedSeparator++;
        } else if ( passedSeparator == 2 ) {
            [self.statusMenu removeItem:oldItem];
        }
    }

    while( pbMenuTitle = [clipEnumerator nextObject] ) {
        item = [[NSMenuItem alloc] initWithTitle:pbMenuTitle
                                          action:@selector(processMenuClippingSelection:)
                                   keyEquivalent:@""];
        [item setTarget:self];
        [item setEnabled:YES];
        [self.statusMenu insertItem:item atIndex:0];
        // Way back in 0.2, failure to release the new item here was causing a quite atrocious memory leak.
        [item release];
    }
}

/* Bezel handler */
- (void) showBezel
{
    if ( [self.clippingStore jcListCount] > 0 && [self.clippingStore jcListCount] > self.stackPosition ) {
        [self.bezel setCharString:[NSString stringWithFormat:@"%d", self.stackPosition + 1]];
        [self.bezel setText:[self.clippingStore clippingContentsAtPosition:self.stackPosition]];
    }
    [self.bezel makeKeyAndOrderFront:nil];
    self.isBezelDisplayed = YES;
}

-(void)hideApp
{
    [self hideBezel];
    self.isBezelPinned = NO;
    [NSApp hide:self];
}

- (void) hideBezel
{
    [self.bezel orderOut:nil];
    [self.bezel setCharString:@""];
    self.isBezelDisplayed = NO;
}

-(void) stackUp
{
    self.stackPosition--;
    if ( self.stackPosition < 0 ) {
        self.stackPosition = 0;
        if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"wraparoundBezel"] ) {
            self.stackPosition = [self.clippingStore jcListCount] - 1;
            [self.bezel setCharString:[NSString stringWithFormat:@"%d", self.stackPosition + 1]];
            [self.bezel setText:[self.clippingStore clippingContentsAtPosition:self.stackPosition]];
        } else {
            self.stackPosition = 0;
        }
    }
    if ( [self.clippingStore jcListCount] > self.stackPosition ) {
        [self.bezel setCharString:[NSString stringWithFormat:@"%d", self.stackPosition + 1]];
        [self.bezel setText:[self.clippingStore clippingContentsAtPosition:self.stackPosition]];
    }
}

-(void) stackDown
{
    self.stackPosition++;
    if ( [self.clippingStore jcListCount] > self.stackPosition ) {
        [self.bezel setCharString:[NSString stringWithFormat:@"%d", self.stackPosition + 1]];
        [self.bezel setText:[self.clippingStore clippingContentsAtPosition:self.stackPosition]];
    } else {
        if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"wraparoundBezel"] ) {
            self.stackPosition = 0;
            [self.bezel setCharString:[NSString stringWithFormat:@"%d", 1]];
            [self.bezel setText:[self.clippingStore clippingContentsAtPosition:self.stackPosition]];
        } else {
            self.stackPosition--;
        }
    }
}

- (void)loadEngineFromPList {
    NSString *path = [@"~/Library/Application Support/Jumpcut/JCEngine.save" stringByExpandingTildeInPath];
    NSDictionary *loadDict = [[NSDictionary alloc] initWithContentsOfFile:path];
    NSEnumerator *enumerator;
    NSDictionary *aSavedClipping;
    NSArray *savedJCList;
    NSRange loadRange;
    int rangeCap;
    
    if (loadDict != nil) {
        savedJCList = [loadDict objectForKey:@"jcList"];
        
        if ([savedJCList isKindOfClass:[NSArray class]]) {
            // There's probably a nicer way to prevent the range from going out of bounds, but this works.
            rangeCap = [savedJCList count] < [[NSUserDefaults standardUserDefaults] integerForKey:@"rememberNum"]
                ? (int)[savedJCList count]
                : (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"rememberNum"];
            loadRange = NSMakeRange(0, rangeCap);
            enumerator = [[savedJCList subarrayWithRange:loadRange] reverseObjectEnumerator];
            
            while (aSavedClipping = [enumerator nextObject])
                [self.clippingStore addClipping:[aSavedClipping objectForKey:@"Contents"]
                                    ofType:[aSavedClipping objectForKey:@"Type"]];
        } else {
            NSLog(@"Not array");
        }
        
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
    path = [@"~/Library/Application Support/Jumpcut" stringByExpandingTildeInPath];
    if ( ![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] || ! isDir ) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil
         ];
    }

    saveDict = [NSMutableDictionary dictionaryWithCapacity:3];

    [saveDict setObject:@"0.7" forKey:@"version"];
    [saveDict setObject:[NSNumber numberWithInt:(int)[[NSUserDefaults standardUserDefaults] integerForKey:@"rememberNum"]]
                 forKey:@"rememberNum"];
    [saveDict setObject:[NSNumber numberWithInt:_DISPLENGTH]
                 forKey:@"displayLen"];
    [saveDict setObject:[NSNumber numberWithInt:(int)[[NSUserDefaults standardUserDefaults] integerForKey:@"displayNum"]]
                 forKey:@"displayNum"];
    for ( i = 0 ; i < [self.clippingStore jcListCount]; i++) {
        [jcListArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                [self.clippingStore clippingContentsAtPosition:i], @"Contents",
                                [self.clippingStore clippingTypeAtPosition:i], @"Type",
                                [NSNumber numberWithInt:i], @"Position",
                                nil
                                ]
         ];
    }
    [saveDict setObject:jcListArray forKey:@"jcList"];
    [saveDict writeToFile:[path stringByAppendingString:@"/JCEngine.save"] atomically:true];
}

/* Pasteboard and clipping behavior */

-(BOOL)addClipToPasteboardFromCount:(int)indexInt movingToTop:(bool)moveBool
{
    NSString *pbFullText;
    NSArray *pbTypes;
    if ( (indexInt + 1) > [self.clippingStore jcListCount] ) {
        // We're asking for a clipping that isn't there yet
        // This only tends to happen immediately on startup when not saving, as the entire list is empty.
        NSLog(@"Out of bounds request to jcList ignored.");
        return false;
    }
    pbFullText = [self clippingStringWithCount:indexInt];
    pbTypes = [NSArray arrayWithObjects:@"NSStringPboardType",NULL];
    
    [self.jcPasteboard declareTypes:pbTypes owner:NULL];
    
    [self.jcPasteboard setString:pbFullText forType:@"NSStringPboardType"];
    if (! moveBool) {
        self.pbBlockCount = (int)[self.jcPasteboard changeCount];
    }
    return true;
}

-(BOOL) isValidClippingNumber:(NSNumber *)number {
    return ( ([number intValue] + 1) <= [self.clippingStore jcListCount] );
}

-(NSString *) clippingStringWithCount:(int)count {
    if ( [self isValidClippingNumber:[NSNumber numberWithInt:count]] ) {
        return [self.clippingStore clippingContentsAtPosition:count];
    } else { // It fails -- we shouldn't be passed this, but...
        NSLog(@"Asked for non-existant clipping count: %d", count);
        return @"";
    }
}

-(IBAction)processMenuClippingSelection:(id)sender
{
    int index=(int)[[sender menu] indexOfItem:sender];
    if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"menuSelectionMovesToTop"] ) {
        [self addClipToPasteboardFromCount:index movingToTop:YES];
    } else {
        [self addClipToPasteboardFromCount:index movingToTop:NO];
    }
    //    if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"menuSelectionPastes"] ) {
    if (1) {
        [self performSelector:@selector(hideApp) withObject:nil];
        [self performSelector:@selector(fakeCommandV) withObject:nil afterDelay:0.2];
    }
}

- (void)processBezelKeyDown:(NSEvent *)theEvent
{
    int newStackPosition;
    // AppControl should only be getting these directly from bezel via delegation
    if ( [theEvent type] == NSEventTypeKeyDown )
    {
        // Note that we want to accept as a "stack down" or "stack up"
        // move the underlying key and shift-key, even if not all the flags
        // are correct.
        if ( theEvent.keyCode == [self.hotkeyRecorder.objectValue[@"keyCode"] integerValue])
        {
            if ( [theEvent modifierFlags] & NSEventModifierFlagShift )
            {
                [self stackUp];
            } else {
                [self stackDown];
            }
            return;
        }
        unichar pressed = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];
        switch ( pressed ) {
            case 0x1B:
                [self hideApp];
                break;
            case 0x3: case 0xD: // Enter or Return
                [self pasteFromStack];
                break;
            case NSUpArrowFunctionKey:
            case NSLeftArrowFunctionKey:
                [self stackUp];
                break;
            case NSDownArrowFunctionKey:
            case NSRightArrowFunctionKey:
                [self stackDown];
                break;
            case NSHomeFunctionKey:
                if ( [self.clippingStore jcListCount] > 0 ) {
                    self.stackPosition = 0;
                    [self.bezel setCharString:[NSString stringWithFormat:@"%d", self.stackPosition + 1]];
                    [self.bezel setText:[self.clippingStore clippingContentsAtPosition:self.stackPosition]];
                }
                break;
            case NSEndFunctionKey:
                if ( [self.clippingStore jcListCount] > 0 ) {
                    self.stackPosition = [self.clippingStore jcListCount] - 1;
                    [self.bezel setCharString:[NSString stringWithFormat:@"%d", self.stackPosition + 1]];
                    [self.bezel setText:[self.clippingStore clippingContentsAtPosition:self.stackPosition]];
                }
                break;
            case NSPageUpFunctionKey:
                if ( [self.clippingStore jcListCount] > 0 ) {
                    self.stackPosition = self.stackPosition - 10; if ( self.stackPosition < 0 ) self.stackPosition = 0;
                    [self.bezel setCharString:[NSString stringWithFormat:@"%d", self.stackPosition + 1]];
                    [self.bezel setText:[self.clippingStore clippingContentsAtPosition:self.stackPosition]];
                }
                break;
            case NSPageDownFunctionKey:
                if ( [self.clippingStore jcListCount] > 0 ) {
                    self.stackPosition = self.stackPosition + 10; if ( self.stackPosition >= [self.clippingStore jcListCount] ) self.stackPosition = [self.clippingStore jcListCount] - 1;
                    [self.bezel setCharString:[NSString stringWithFormat:@"%d", self.stackPosition + 1]];
                    [self.bezel setText:[self.clippingStore clippingContentsAtPosition:self.stackPosition]];
                }
                break;
            case NSBackspaceCharacter: break;
            case NSDeleteCharacter: break;
            case NSDeleteFunctionKey: break;
            case 0x30: case 0x31: case 0x32: case 0x33: case 0x34:                 // Numeral
            case 0x35: case 0x36: case 0x37: case 0x38: case 0x39:
                // We'll currently ignore the possibility that the user wants to do something with shift.
                // First, let's set the new stack count to "10" if the user pressed "0"
                newStackPosition = pressed == 0x30 ? 9 : [[NSString stringWithCharacters:&pressed length:1] intValue] - 1;
                if ( [self.clippingStore jcListCount] >= newStackPosition ) {
                    self.stackPosition = newStackPosition;
                    [self.bezel setCharString:[NSString stringWithFormat:@"%d", self.stackPosition + 1]];
                    [self.bezel setText:[self.clippingStore clippingContentsAtPosition:self.stackPosition]];
                }
                break;
            default: // It's not a navigation/application-defined thing, so let's figure out what to do with it.
                //                NSLog(@"PRESSED %d", pressed);
                //                NSLog(@"CODE %d", [self.hotkeyRecorder keyCombo].code);
                break;
        }
    }
}

- (void)pasteFromStack
{
    [self performSelector:@selector(hideApp) withObject:nil afterDelay:0.2];
    if ( [self.clippingStore jcListCount] > self.stackPosition ) {
        [self addClipToPasteboardFromCount:self.stackPosition movingToTop:NO];
        //        if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"bezelSelectionPastes"] ) {
        if (1) {
            // Set this back to 0.2 when it's working.
            [self performSelector:@selector(fakeCommandV) withObject:nil afterDelay:0.2];
        }
    }
}

-(void)fakeCommandV
{
    // We can no longer use a reverse transformer to get this value
    // programatically, under the 64-bit friendly ShortcutRecorder2,
    // so we need to hardcode it for now, but this is valid for US
    // ASCII only and is not a permanent solution.
    CGEventSourceRef sourceRef = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    if (!sourceRef) {
        return;
    }
    CGEventRef eventDown = CGEventCreateKeyboardEvent(sourceRef, self.veeCode, true);
    CGEventSetFlags(eventDown, kCGEventFlagMaskCommand|0x000008);
    CGEventRef eventUp = CGEventCreateKeyboardEvent(sourceRef, self.veeCode, false);
    CGEventPost(kCGHIDEventTap, eventDown);
    CGEventPost(kCGHIDEventTap, eventUp);
    CFRelease(eventDown);
    CFRelease(eventUp);
    CFRelease(sourceRef);
}

- (void)metaKeysReleased
{
    if ( !self.isBezelPinned ) {
        [self pasteFromStack];
    }
}

-(void)pollPasteboard:(NSTimer *)timer
{
    NSString *type = [self.jcPasteboard availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]];
    if ( self.pbCount != [self.jcPasteboard changeCount] ) {
        // Reload pbCount with the current changeCount
        // Probably poor coding technique, but pollPB should be the only thing messing with pbCount, so it should be okay
        self.pbCount = (int)[self.jcPasteboard changeCount];
        if ( type != nil ) {
            NSString *contents = [self.jcPasteboard stringForType:type];
            if ( contents == nil || [self.jcPasteboard stringForType:@"PasswordPboardType"] ) {
                //                NSLog(@"Contents: Empty");
            } else {
                if (( [self.clippingStore jcListCount] == 0 || ! [contents isEqualToString:[self.clippingStore clippingContentsAtPosition:0]])
                    && self.pbCount != self.pbBlockCount ) {
                    [self.clippingStore addClipping:contents
                                             ofType:type    ];
                    //                    The below tracks our position down down down... Maybe as an option?
                    //                    if ( [clippingStore jcListCount] > 1 ) stackPosition++;
                    self.stackPosition = 0;
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

/* Misc. UX */
-(IBAction)clearClippingList:(id)sender {
    NSUInteger choice;
    [NSApp activateIgnoringOtherApps:YES];
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NSLocalizedString(@"Clear", @"Alert panel - clear clippings list - clear")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Alert panel - cancel")];
    [alert setMessageText:NSLocalizedString(@"Clear Clipping List", @"Alert panel - clear clippings list - title")];
    [alert setInformativeText:NSLocalizedString(@"Do you want to clear all recent clippings?", @"Alert panel - clear clippings list - message")];
    choice = [alert runModal];
    // on clear, zap the list and redraw the menu
    if (choice == NSAlertFirstButtonReturn) {
        [self.clippingStore clearList];
        [self updateMenu];
        if ( [[NSUserDefaults standardUserDefaults] integerForKey:@"savePreference"] >= 1 ) {
            [self saveEngine];
        }
        [self.bezel setText:@""];
    }
    [alert release];
}

-(IBAction) showPreferencePanel:(id)sender
{
    if ([self.prefsPanel respondsToSelector:@selector(setCollectionBehavior:)])
        [self.prefsPanel setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
    [NSApp activateIgnoringOtherApps: YES];
    [self.prefsPanel makeKeyAndOrderFront:self];
}

@end
