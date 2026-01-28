//
//  HotkeyPreferenceViewController.swift
//  Jumpcut
//
//  Created by Steve Cook on 4/16/22.
//

import Cocoa
import Preferences

final class HotkeyPreferenceViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = Preferences.PaneIdentifier.hotkey
    let preferencePaneTitle = "Hotkey"
    let toolbarItemIcon = NSImage(named: "command.square")!

    // Dummy nib; we'll build the UI programatically
    override func loadView() {
        self.view = NSView()
    }
    override var nibName: NSNib.Name? { nil }

    override func viewDidLoad() {
        let settings = Settings()
        toolbarItemIcon.isTemplate = true
        self.preferredContentSize = CGSize(width: 480, height: 240)
        super.viewDidLoad()
        
        let recorder = settings.shortcutRecorder(title: "Main hotkey", key: .mainHotkey)
        
        // Quick paste feature
        let quickPasteCheckbox = settings.checkbox(
            title: "Enable quick paste shortcuts",
            key: SettingsPath.quickPasteEnabled
        )
        
        // Get the main hotkey modifiers to show in the description
        var modifierDescription = "⌃⌥" // Default to Control-Option
        if let dictionary = UserDefaults.standard.value(forKey: SettingsPath.mainHotkey.rawValue) as? [AnyHashable: Any],
           let modifierFlags = dictionary["modifierFlags"] as? Int {
            var parts: [String] = []
            if modifierFlags & 1048576 != 0 { parts.append("⌘") }  // Command (1 << 20)
            if modifierFlags & 524288 != 0 { parts.append("⌥") }   // Option (1 << 19)
            if modifierFlags & 262144 != 0 { parts.append("⌃") }   // Control (1 << 18)
            if modifierFlags & 131072 != 0 { parts.append("⇧") }   // Shift (1 << 17)
            if !parts.isEmpty {
                modifierDescription = parts.joined()
            }
        }
        
        let quickPasteDescription = settings.smallText(
            "Pastes clipping 1-5 using \(modifierDescription)1, \(modifierDescription)2, \(modifierDescription)3, \(modifierDescription)4, \(modifierDescription)5"
        )
        
        let quickPasteStack = NSStackView(views: [quickPasteCheckbox, quickPasteDescription])
        quickPasteStack.orientation = .vertical
        quickPasteStack.alignment = .leading
        quickPasteStack.spacing = 4
        
        let grid = NSStackView(views: [ recorder, quickPasteStack ])
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = 16
        self.view.addSubview(grid)
        self.view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: 24),
            grid.topAnchor.constraint(greaterThanOrEqualTo: self.view.topAnchor, constant: 24)
       ])
    }
}