//
//  StatusItem.swift
//  Jumpcut
//
//  Created by Steve Cook on 4/16/22.
//

import Cocoa

class StatusItem {
    // Annoyingly, our shotgun approach to monitoring preference state change
    // means that we have to track what the state is supposed to be, because
    // we'll call it repeatedly on change, causing a crash in the naïve case.
    private var shown = false
    private var statusItem: NSStatusItem?
    private var visibilityObserver: NSKeyValueObservation?

    func setVisibility() {
        let headless = UserDefaults.standard.value(forKey: SettingsPath.hideStatusItem.rawValue) as? Bool ?? false
        if headless && shown {
            hide()
        } else if !headless && !shown {
            show()
        }
    }

    init() {
        makeItem()
    }

    public func displayMenu(_ activeMenu: NSMenu) {
        guard statusItem != nil else {
            return
        }
        statusItem!.highlightMode = true // Highlight bodge: Stop the highlight flicker (see async call below).
        statusItem!.button?.isHighlighted = true
        statusItem!.menu = activeMenu
        statusItem!.popUpMenu(activeMenu)
        statusItem!.menu = nil // Otherwise clicks won't be processed again
    }

    private func makeItem() {
        let delegate = (NSApplication.shared.delegate as? AppDelegate)!
        let menuIconPref = UserDefaults.standard.value(forKey: SettingsPath.menuIcon.rawValue) as? Int ?? 0
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if menuIconPref == 1 {
            statusItem!.button?.title = "✄"
        } else {
            statusItem!.button?.image = NSImage(named: NSImage.Name("scissors_bw"))
            statusItem!.button?.image!.isTemplate = true
        }
        statusItem!.button?.action = #selector(delegate.statusItemClicked(sender:))
        // See https://stackoverflow.com/questions/40062510/swift-nsstatusitem-remains-highlighted-after-right-click
        // for details on why we're using mouseup instead of mousedown.
        statusItem!.button?.sendAction(on: [
            NSEvent.EventTypeMask.leftMouseUp,
            NSEvent.EventTypeMask.rightMouseUp,
            NSEvent.EventTypeMask.otherMouseUp
        ])
        if #available(OSX 10.12, *) {
            statusItem!.behavior = .removalAllowed
            statusItem!.autosaveName = "JumpcutStatusItem"
            visibilityObserver = statusItem!.observe(\.isVisible, options: [.old, .new]) { _, change in
                if !change.newValue! {
                    UserDefaults.standard.set(true, forKey: SettingsPath.hideStatusItem.rawValue)
                    self.hide()
                }
            }
        }
    }

    public func hide() {
        shown = false
        guard statusItem != nil else {
            return
        }
        if #available(OSX 10.12, *) {
            if !statusItem!.isVisible {
                return
            }
            statusItem!.isVisible = false
        } else {
            NSStatusBar.system.removeStatusItem(statusItem!)
            visibilityObserver = nil
            statusItem = nil
        }
    }

    func show() {
        /*
         * Trickier logic; if we're pre-10.12 we *should* have a nil
         * statusItem.
         */
        shown = true
        if #available(OSX 10.12, *) {
            guard statusItem != nil else {
                return
            }
            if statusItem!.isVisible {
                return
            }
            statusItem!.isVisible = true
        } else {
            guard statusItem == nil else {
                return
            }
            makeItem()
        }
    }
}
