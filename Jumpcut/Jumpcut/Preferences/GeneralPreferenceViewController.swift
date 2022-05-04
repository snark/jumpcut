//
//  GeneralPreferenceViewController.swift
//  Jumpcut
//
//  Created by Steve Cook on 4/16/22.
//

import Cocoa
import Preferences
import ServiceManagement

final class GeneralPreferenceViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = Preferences.PaneIdentifier.general
    let preferencePaneTitle = "General"
    let toolbarItemIcon = NSImage(named: "gearshape")!

    // Dummy nib; we'll build the UI programatically
    override func loadView() {
        self.view = NSView()
    }
    override var nibName: NSNib.Name? { nil }

    @objc func dispatchResetPreferences() {
        let alert = NSAlert()
        alert.messageText = "Do you want to reset preferences?"
        alert.informativeText = "This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Settings.reset()
        }
    }

    @objc func toggleLaunchOnLogin(sender: NSButton) {
        let helper = "net.sf.Jumpcut.JumpcutHelper"
        if sender.state == .on {
            if !SMLoginItemSetEnabled(helper as CFString, true) {
                #if DEBUG
                    print("SMLoginItemSetEnabled for \(helper) (true) failed")
                #endif
            }
        } else {
            if !SMLoginItemSetEnabled(helper as CFString, false) {
                #if DEBUG
                    print("SMLoginItemSetEnabled for \(helper) (false) failed")
                #endif
            }
        }
    }

    private func makeSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }

    private func makeBezelToTopRow(settings: Settings) -> NSStackView {
        let options = [
            (title: "Bezel position is unchanged", value: 0),
            (title: "Bezel position returns to top", value: 1)
        ]
        let popup = settings.popup(title: "After recording a new clipping…",
                                   key: SettingsPath.bezelToTop, options: options)
        let popupStack = NSStackView(views: [popup])
        return popupStack
    }

    private func makeAdvancedMenuRow(settings: Settings) -> NSStackView {
        let options = [
            (title: "None", value: MenuBehaviorFlags.none.rawValue),
            (title: "Right click for additional options", value: MenuBehaviorFlags.rightAlt.rawValue),
            (title: "…and shift click to switch paste behavior",
             value: MenuBehaviorFlags.rightAltShiftToggle.rawValue),
            (title: "Shift click for additional options", value: MenuBehaviorFlags.shiftAlt.rawValue),
            (title: "…and right click to switch paste behavior",
             value: MenuBehaviorFlags.shiftAltRightToggle.rawValue)
        ]
        let popup = settings.popup(title: "Alternate menu behavior",
                                   key: SettingsPath.menuBehaviorFlags, options: options)
        let popupStack = NSStackView(views: [popup])
        return popupStack
    }

    private func makeResetRow() -> NSStackView {
        let resetButton = NSButton()
        resetButton.title = "Reset Preferences"
        resetButton.target = self
        resetButton.action = #selector(self.dispatchResetPreferences)
        resetButton.controlSize = .small
        resetButton.bezelStyle = .rounded
        let resetRow = NSStackView(views: [resetButton])
        resetRow.alignment = .right
        return resetRow
    }

    private func makeLaunchOnLogin(settings: Settings) -> NSButton {
        return settings.checkbox(
            title: "Launch on login",
            key: SettingsPath.launchOnStartup,
            target: self,
            action: #selector(self.toggleLaunchOnLogin)
        )
    }

    private func makePasteOptions(settings: Settings) -> (NSButton, NSButton) {
        let accessibilityActive = AXIsProcessTrusted()
        let pasteMenu = settings.checkbox(
            title: "Menu selection pastes",
            key: SettingsPath.menuSelectionPastes
        )
        let pasteBezel = settings.checkbox(
            title: "Bezel selection pastes",
            key: SettingsPath.bezelSelectionPastes
        )
        if !accessibilityActive {
            pasteMenu.isEnabled = false
            pasteBezel.isEnabled = false
        }
        return (pasteMenu, pasteBezel)
    }

    private func makeSparkleRow(settings: Settings) -> NSStackView {
        let autoCheck = settings.checkbox(title: "Automatically check for updates", key: SettingsPath.checkForUpdates)
        let checkNowButton = NSButton()
        let delegate = (NSApplication.shared.delegate as? AppDelegate)!
        checkNowButton.title = "Check Now"
        checkNowButton.target = delegate
        checkNowButton.action = #selector(delegate.checkSparkle(sender:))
        checkNowButton.controlSize = .small
        checkNowButton.bezelStyle = .rounded
        let checkRow = NSStackView(views: [autoCheck, checkNowButton])
        NSLayoutConstraint.activate([
            autoCheck.leadingAnchor.constraint(greaterThanOrEqualTo: checkRow.leadingAnchor, constant: 0),
            checkNowButton.trailingAnchor.constraint(greaterThanOrEqualTo: checkRow.trailingAnchor, constant: 0)
        ])
        return checkRow
    }

    override func viewDidLoad() {
        let settings = Settings()
        toolbarItemIcon.isTemplate = true
        self.preferredContentSize = CGSize(width: 480, height: 320)
        super.viewDidLoad()

        let (pasteMenu, pasteBezel) = makePasteOptions(settings: settings)
        let wrapBezel = settings.checkbox(title: "Wraparound bezel", key: SettingsPath.wraparoundBezel)
        let stickyBezel = settings.checkbox(title: "Sticky bezel", key: SettingsPath.stickyBezel)
        let rememberNumView = settings.rangeStepper(title: "Remembering", minValue: 10, maxValue: 99, key: .rememberNum)
        let displayNumView = settings.rangeStepper(title: "Displaying", minValue: 10, maxValue: 99, key: .displayNum)
        let stepperViews = NSStackView(views: [rememberNumView, displayNumView])
        NSLayoutConstraint.activate([
            displayNumView.leadingAnchor.constraint(equalTo: rememberNumView.leadingAnchor, constant: 160)
        ])
        let advancedMenuRow = makeAdvancedMenuRow(settings: settings)
        let launchOnLogin = makeLaunchOnLogin(settings: settings)
        let sparkleRow = makeSparkleRow(settings: settings)
        let bezelToTopRow = makeBezelToTopRow(settings: settings)

        let resetRow = makeResetRow()

        let grid = NSStackView(views: [
            pasteMenu, pasteBezel, bezelToTopRow, wrapBezel, stickyBezel,
            advancedMenuRow, makeSeparator(), stepperViews, makeSeparator(),
            launchOnLogin, sparkleRow, makeSeparator(), resetRow
        ])
        grid.orientation = .vertical
        grid.alignment = .leading
        self.view.addSubview(grid)
        self.view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: 24),
            grid.topAnchor.constraint(greaterThanOrEqualTo: self.view.topAnchor, constant: 24),
            grid.widthAnchor.constraint(equalTo: self.view.widthAnchor, constant: -48),
            stepperViews.leadingAnchor.constraint(equalTo: grid.leadingAnchor, constant: 10),
            sparkleRow.widthAnchor.constraint(equalTo: grid.widthAnchor),
            resetRow.widthAnchor.constraint(equalTo: grid.widthAnchor)
        ])
    }
}
