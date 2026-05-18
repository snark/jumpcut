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

    @objc func toggleExtendedFeatures(sender: NSButton) {
        guard sender.state == .off else {
            return
        }
        let rememberNum = UserDefaults.standard.value(
            forKey: SettingsPath.rememberNum.rawValue
        ) as? Int ?? Settings.defaultRememberNum()
        if rememberNum > Settings.defaultRememberNum() {
            UserDefaults.standard.set(
                Settings.defaultRememberNum(),
                forKey: SettingsPath.rememberNum.rawValue
            )
        }
    }

    override func viewDidLoad() {
        let settings = Settings()
        toolbarItemIcon.isTemplate = true
        self.preferredContentSize = CGSize(width: 480, height: 220)
        super.viewDidLoad()
        let recorder = settings.shortcutRecorder(title: "Main hotkey", key: .mainHotkey)
        let extendedFeatures = settings.checkbox(
            title: "Enable extended clipping actions and 500-item history",
            key: .extendedFeaturesEnabled,
            target: self,
            action: #selector(self.toggleExtendedFeatures)
        )
        let grid = NSStackView(views: [ recorder, extendedFeatures ])
        grid.orientation = .vertical
        grid.alignment = .leading
        self.view.addSubview(grid)
        self.view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: 24),
            grid.topAnchor.constraint(greaterThanOrEqualTo: self.view.topAnchor, constant: 24)
       ])
    }
}
