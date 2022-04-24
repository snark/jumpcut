//
//  AppearancePreferenceViewController.swift
//  Jumpcut
//
//  Created by Steve Cook on 4/16/22.
//

import Cocoa
import Preferences

final class AppearancePreferenceViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = Preferences.PaneIdentifier.appearance
    let preferencePaneTitle = "Appearance"
    let toolbarItemIcon = NSImage(named: "paintpalette")!

    // Dummy nib; we'll build the UI programatically
    override func loadView() {
        self.view = NSView()
    }
    override var nibName: NSNib.Name? { nil }

    @IBAction func handlePopupChange(_ sender: Any?) {

    }

/*
    init() {
        if #available(macOS 11.0, *) {
            toolbarItemIcon = NSImage(
                systemSymbolName: "paintpalette",
                accessibilityDescription: "Appearance preferences"
            )!
        } else {

        }
        super.init(nibName: "AppearancePreferenceViewController", bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
*/

    override func viewDidLoad() {
        let settings = Settings()
        toolbarItemIcon.isTemplate = true
        self.preferredContentSize = CGSize(width: 480, height: 180)
        super.viewDidLoad()
        let hideStatusCheckbox = settings.checkbox(
            title: "Hide menu icon",
            key: SettingsPath.hideStatusItem
        )
        let hideStatusLabel = settings.smallText(
            "When the menu icon is hidden, relaunch Jumpcut from Finder to open"
        )
        let hideStatusStack = NSStackView(views: [hideStatusCheckbox, hideStatusLabel ])
        hideStatusStack.orientation = .vertical
        hideStatusStack.alignment = .leading
        let options = [
            (title: "Center", value: BezelAlignment.center.rawValue),
            (title: "Left", value: BezelAlignment.left.rawValue),
            (title: "Right", value: BezelAlignment.right.rawValue),
            (title: "Single lines center; others left", value: BezelAlignment.smartAlign.rawValue)
        ]
        let popup = settings.popup(title: "Bezel text alignment", key: SettingsPath.bezelAlignment, options: options)
        let popupStack = NSStackView(views: [popup])
        let grid = NSStackView(views: [ hideStatusStack, popupStack ])
        grid.orientation = .vertical
        grid.alignment = .leading
        self.view.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: 24),
            grid.topAnchor.constraint(greaterThanOrEqualTo: self.view.topAnchor, constant: 24)
        ])
    }
}
