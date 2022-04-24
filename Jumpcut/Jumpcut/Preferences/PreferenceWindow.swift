//
//  PreferenceWindow.swift
//  Jumpcut
//
//  Created by Steve Cook on 7/21/22.
//

import Cocoa
import Preferences

extension Preferences.PaneIdentifier {
    static let appearance = Self("appearance")
    static let clippings = Self("clippings")
    static let general = Self("general")
    static let hotkey = Self("hotkey")
}

// Preferences pane
var preferences: [PreferencePane] = [
    GeneralPreferenceViewController(),
    HotkeyPreferenceViewController(),
    ClippingsPreferenceViewController(),
    AppearancePreferenceViewController()
]

var preferencesWindowController = PreferencesWindowController(
    preferencePanes: preferences,
    style: .toolbarItems,
    animated: true,
    hidesToolbarForSingleItem: true
)
