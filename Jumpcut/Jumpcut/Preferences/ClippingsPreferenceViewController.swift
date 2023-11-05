//
//  ClippingsPreferenceViewController.swift
//  Jumpcut
//
//  Created by Steve Cook on 4/16/22.
//

import Cocoa
import Preferences

final class ClippingsPreferenceViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = Preferences.PaneIdentifier.clippings
    let preferencePaneTitle = "Clippings"
    let toolbarItemIcon = NSImage(named: "paperclip")!
    var skipSaveButton: NSButton?

    // Dummy nib; we'll build the UI programatically
    override func loadView() {
        self.view = NSView()
    }
    override var nibName: NSNib.Name? { nil }

    override func viewDidLoad() {
        let settings = Settings()
        toolbarItemIcon.isTemplate = true
        self.preferredContentSize = CGSize(width: 480, height: 180)
        super.viewDidLoad()
        let btn1 = settings.checkbox(
            title: "Ignore large clippings",
            key: SettingsPath.ignoreLargeClippings
        )
        let btn2 = settings.checkbox(
            title: "Ignore confidential clipping types",
            key: SettingsPath.ignoreSensitiveClippingTypes
        )
        skipSaveButton = settings.fixedCheckbox(
            title: "Never save clippings to disk",
            target: self,
            action: #selector(toggleSkipSave)
        )
        let btn4 = settings.checkbox(
            title: "Allow whitespace clippings",
            key: SettingsPath.allowWhitespaceClippings
        )
        let btn5 = settings.checkbox(
            title: "Move clippings to top after use",
            key: SettingsPath.moveClippingsAfterUse
        )
        skipSaveButton!.state = UserDefaults.standard.value(
            forKey: SettingsPath.skipSave.rawValue
        ) as? Bool ?? false ? .on : .off
        let grid = NSStackView(views: [ btn1, btn2, skipSaveButton!, btn4, btn5 ])
        grid.orientation = .vertical
        grid.alignment = .leading
        self.view.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: 24),
            grid.topAnchor.constraint(greaterThanOrEqualTo: self.view.topAnchor, constant: 24)
        ])
    }

    @objc func toggleSkipSave(sender: Any?) {
        let delegate = (NSApplication.shared.delegate as? AppDelegate)!
        let skipOn = UserDefaults.standard.value(forKey: SettingsPath.skipSave.rawValue) as? Bool ?? false
        guard delegate.stackEmpty() else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            if skipOn {
                alert.messageText = Constants.Alerts.skipClearBeforeOff
            } else {
                alert.messageText = Constants.Alerts.skipClearBeforeOn
            }
            alert.addButton(withTitle: "OK")
            _ = alert.runModal()
            return
        }
        let alert = NSAlert()
        if skipOn {
            UserDefaults.standard.set(false, forKey: SettingsPath.skipSave.rawValue)
            skipSaveButton!.state = .off
            delegate.setSkipSave(value: false)
        } else {
            alert.messageText = "Do you want to stop saving clippings to disk?"
            alert.informativeText = Constants.Alerts.skipSave
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                UserDefaults.standard.set(true, forKey: SettingsPath.skipSave.rawValue)
                skipSaveButton!.state = .on
                delegate.setSkipSave(value: true)
            }
        }
    }
}
