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
        self.preferredContentSize = CGSize(width: 480, height: 260)
        super.viewDidLoad()
        let recorder = settings.shortcutRecorder(title: "Main hotkey", key: .mainHotkey)
        let multiRecorder = settings.shortcutRecorder(title: "Paste several clippings", key: .multiPasteHotkey)
        let orderPopup = settings.popup(
            title: "Several clippings are pasted",
            key: .multiPasteOrder,
            options: [
                (title: "Oldest first", value: MultiPasteOrder.oldestFirst.rawValue),
                (title: "Newest first", value: MultiPasteOrder.newestFirst.rawValue)
            ]
        )
        let separatorPopup = settings.popup(
            title: "Separated by",
            key: .multiPasteSeparator,
            options: [
                (title: "New line", value: MultiPasteSeparator.newline.rawValue),
                (title: "Blank line", value: MultiPasteSeparator.blankLine.rawValue),
                (title: "Space", value: MultiPasteSeparator.space.rawValue),
                (title: "Comma", value: MultiPasteSeparator.comma.rawValue)
            ]
        )
        let help = settings.smallText(
            "In the multi-paste bezel, press the hotkey again, or use the arrow or number keys, to choose how many."
        )
        let grid = NSStackView(views: [ recorder, multiRecorder, orderPopup, separatorPopup, help ])
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
