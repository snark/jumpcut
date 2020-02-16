//
//  JCRecorderControl.m
//  Jumpcut
//
//  Created by Steve Cook on 9/4/19.
//  Copyright © 2019 Steve Cook. All rights reserved.
//
//  Taken directly from:
//     https://github.com/Kentzo/ShortcutRecorder/wiki/Usage-of-pause-and-resume-methods-of-PTHotKeyCenter

#import "JCRecorderControl.h"

@implementation JCRecorderControl

- (BOOL)becomeFirstResponder
{
    BOOL isBecome = [super becomeFirstResponder];
    if (isBecome)
        [[PTHotKeyCenter sharedCenter] pause];
    return isBecome;
}

- (BOOL)resignFirstResponder
{
    BOOL isResigned = [super resignFirstResponder];
    if (isResigned)
        [[PTHotKeyCenter sharedCenter] resume];
    return isResigned;
}

- (BOOL)performKeyEquivalent:(NSEvent *)anEvent
{
    BOOL result = [super performKeyEquivalent:anEvent];
    if (result)
        [[self window] makeFirstResponder:nil];
    return result;
}

@end
