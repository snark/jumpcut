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
        let grid = NSStackView(views: [ btn1, btn2 ])
        grid.orientation = .vertical
        grid.alignment = .leading
        self.view.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: 24),
            grid.topAnchor.constraint(greaterThanOrEqualTo: self.view.topAnchor, constant: 24)
        ])
    }
}
