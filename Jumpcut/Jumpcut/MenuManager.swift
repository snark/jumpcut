//
//  MenuManager.swift
//  Jumpcut
//
//  Created by Steve Cook on 2/5/22.
//

import Cocoa

public class MenuManager {
    @IBOutlet public var standard: NSMenu!
    @IBOutlet public var alt: NSMenu!
    weak private var delegate: AppDelegate?

    public var triggerEvent: NSEvent?

    init() {
        standard = NSMenu()
        alt = NSMenu()
        delegate = (NSApplication.shared.delegate as? AppDelegate)!
        standard.delegate = delegate
        alt.delegate = delegate
    }

    private func checkToggle() -> Bool {
        guard let event = self.triggerEvent else { return false }
        return delegate?.checkMenuBehavior(event) ?? false
    }

    public func shouldSelectionPaste() -> Bool {
        var paste =
 UserDefaults.standard.value(forKey: SettingsPath.menuSelectionPastes.rawValue) as? Bool ?? false
        if checkToggle() {
            paste = !paste
        }
        return paste
    }

    private func standardItem(forClipping clipping: Clipping) -> NSMenuItem {
        let standardItem = NSMenuItem(
            title: clipping.shortenedText,
            action: #selector(self.delegate!.interactions!.menuSelection(sender:)),
            keyEquivalent: ""
        )
        standardItem.target = delegate!.interactions!
        return standardItem
    }

    private func altItem(forClipping clipping: Clipping, pasteEnabled: Bool) -> NSMenuItem {
        let altItem = NSMenuItem(
            title: clipping.shortenedText,
            action: nil,
            keyEquivalent: ""
        )
        let submenu = NSMenu()
        altItem.submenu = submenu
        let placeItem = NSMenuItem(
            title: "Copy to pasteboard",
            action: #selector(self.delegate!.interactions!.menuPlace(sender:)),
            keyEquivalent: ""
        )
        let pasteItem = NSMenuItem(
            title: "Paste",
            action: #selector(self.delegate!.interactions!.menuPaste(sender:)),
            keyEquivalent: ""
        )
        pasteItem.isEnabled = pasteEnabled
        let deleteItem = NSMenuItem(
            title: "Delete item",
            action: #selector(self.delegate!.interactions!.menuDelete(sender:)),
            keyEquivalent: ""
        )
        for item in [placeItem, pasteItem, deleteItem] {
            item.target = delegate!.interactions!
            submenu.addItem(item)
        }
        return altItem
    }

    public func rebuild(stack: ClippingStack) {
        standard.removeAllItems()
        alt.removeAllItems()
        if stack.isEmpty() {
            for which in [alt!, standard!] {
                which.addItem(withTitle: "<None>", action: nil, keyEquivalent: "")
                which.item(at: 0)!.isEnabled = false
            }
        } else {
            let displaySize: Int
            if let displayNum = UserDefaults.standard.value(forKey: SettingsPath.displayNum.rawValue) as? Int {
                displaySize = displayNum
            } else {
                displaySize = 10
            }
            let clippings = stack.firstItems(n: displaySize)
            // No need to call this N times
            let pasteEnabled = AXIsProcessTrusted()
            for clipping in clippings {
                standard.addItem(standardItem(forClipping: clipping))
                alt.addItem(altItem(forClipping: clipping, pasteEnabled: pasteEnabled))
            }
        }
        for which in [alt!, standard!] {
            addFixedMenuItems(menu: which)
        }
    }

    func addFixedMenuItems(menu: NSMenu) {
        // Shared between alt and standard menus: Clear All, About,
        // Preferences, and Quit
        let appName = ProcessInfo.processInfo.processName
        menu.addItem(NSMenuItem.separator())
        let clear = NSMenuItem(
            title: "Clear All",
            action: #selector(self.delegate!.interactions!.clearAll(sender:)),
            keyEquivalent: ""
        )
        clear.target = delegate!.interactions!
        menu.addItem(clear)
        menu.addItem(
            NSMenuItem(
                title: "About \(appName)",
                action: #selector(delegate!.openAboutWindow(sender:)),
                keyEquivalent: ""
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "Preferences…",
                action: #selector(delegate!.openPreferencesWindow(sender:)),
                keyEquivalent: ""
            )
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit",
                action: #selector(delegate!.quit(sender:)),
                keyEquivalent: ""
            )
        )
    }

}
