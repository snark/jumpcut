//
//  main.swift
//  JumpcutHelper
//
//  Created by Steve Cook on 4/16/22.
//

import Cocoa

let delegate = JumpcutHelperAppDelegate()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
