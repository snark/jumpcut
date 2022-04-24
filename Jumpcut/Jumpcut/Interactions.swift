//
//  Interactions.swift
//  Jumpcut
//
//  Created by Steve Cook on 2/5/22.
//

import Cocoa
import Sauce

public class Interactions: NSObject {
    /*
     * Responses to user actions, such as selecting a clipping via the
     * bezel or clicking "Clear All".
     */

    weak private var pasteboard: Pasteboard!
    weak private var stack: ClippingStack!
    weak private var menu: MenuManager!
    weak private var bezel: Bezel!
    weak private var delegate: AppDelegate!

    init(bezel: Bezel, menu: MenuManager, pasteboard: Pasteboard, stack: ClippingStack) {
        self.pasteboard = pasteboard
        self.stack = stack
        self.menu = menu
        self.bezel = bezel
        self.delegate = (NSApplication.shared.delegate as? AppDelegate)!
    }

    // HOTKEY
    func setHotkeyHandlers() {
        bezel.setMetaKeyReleaseHandler(handler: {
            if let sticky = UserDefaults.standard.value(forKey: SettingsPath.stickyBezel.rawValue) as? Bool {
                if !sticky {
                    self.bezelSelection()
                }
            }
        })
        bezel.setKeyDownHandler(handler: {(event: NSEvent) -> Void in
            // Note that the event.keyCode is locale-independent; it gives us
            // the ANSI-standard keycode, representing the QWERTY layout. To
            // handle things otherwise, we'll do a lookup in Sauce.
            if let key = Sauce.shared.key(for: Int(event.keyCode)) {
                if key == self.delegate.hotKeyBase {
                    if event.modifierFlags.contains(.shift) {
                        self.stack.up()
                        self.delegate.displayBezelAtPosition(position: self.stack.position)
                    } else {
                        self.stack.down()
                        self.delegate.displayBezelAtPosition(position: self.stack.position)
                    }
                } else {
                    self.delegate.bezelKeyDownBehavior(key: key)
                }
            }
        })
    }

    // PASTEBOARD
    func place(_ clipping: Clipping) {
        // Place the clipping on the top of the pasteboard, then resign from
        // front.
        pasteboard.set(clipping.fullText)
        delegate.hide()
    }

    func paste(_ clipping: Clipping) {
        // Place the clipping on the top of the pasteboard, and 0.2 seconds
        // later, emit a Command-V event to paste.
        place(clipping)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.fakeCommandV()
        }
    }

    private func fakeCommandV() {
        let sourceRef = CGEventSource(stateID: .combinedSessionState)
        guard sourceRef != nil else {
            return
        }
        let veeCode = Sauce.shared.keyCode(for: .v)
        sourceRef!.setLocalEventsFilterDuringSuppressionState([.permitLocalMouseEvents, .permitSystemDefinedEvents],
                                                           state: .eventSuppressionStateSuppressionInterval)
        let eventDown = CGEvent(keyboardEventSource: sourceRef, virtualKey: veeCode, keyDown: true)
        eventDown?.flags = .maskCommand
        let eventUp = CGEvent(keyboardEventSource: sourceRef, virtualKey: veeCode, keyDown: false)
        eventUp?.flags = .maskCommand
        eventDown?.post(tap: .cgAnnotatedSessionEventTap)
        eventUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    // BEZEL
    public func bezelSelection() {
        let clipping = stack.itemAt(position: stack.position)
        guard clipping != nil else {
            return
        }
        if bezel.shouldSelectionPaste() {
            paste(clipping!)
        } else {
            place(clipping!)
        }
    }

    // MENU
    private func menuHandler(item: NSMenuItem!, wantsPaste: Bool) {
        let idx = extractIndex(menuItem: item)
        let clipping = stack.itemAt(position: idx)
        guard clipping != nil else {
            delegate.hide()
            return
        }
        if wantsPaste {
            paste(clipping!)
        } else {
            place(clipping!)
        }
    }

    @objc public func menuSelection(sender: NSMenuItem!) {
        menuHandler(item: sender, wantsPaste: menu.shouldSelectionPaste())
    }

    @objc public func menuPlace(sender: NSMenuItem!) {
        menuHandler(item: sender, wantsPaste: false)
    }

    @objc public func menuPaste(sender: NSMenuItem!) {
        menuHandler(item: sender, wantsPaste: true)
    }

    @objc public func menuDelete(sender: NSMenuItem!) {
        let idx = extractIndex(menuItem: sender)
        // stack.deleteAt() takes care of resetting the stack position.
        stack.deleteAt(position: idx)
        menu.rebuild(stack: stack)
    }

    private func extractIndex(menuItem: NSMenuItem!) -> Int {
        // Utility function to abstract over calling our menu-driven behaviors
        // for individual clippings from either the standard or the alternative
        // menu.
        var topLevel: NSMenu
        var item: NSMenuItem
        if menuItem.parent != nil {
            topLevel = menuItem.parent!.menu!
            item = menuItem.parent!
        } else {
            topLevel = menuItem.menu!
            item = menuItem
        }
        return topLevel.index(of: item)
    }

    private func _clearAll() {
        /*
         * If the top item in our stack is on the pasteboard, we also want
         * to clear the pasteboard itself. We don't care about the expense
         * of this, because clear all is an uncommon behavior, not in a
         * hot loop.
         */
        if let topOfPasteboard = pasteboard.topItem() {
            let topOfStack = stack.itemAt(position: 0)
            if topOfPasteboard == topOfStack!.fullText {
                pasteboard.set("", autogenerated: true)
            }
        }
        stack.clear()
        menu.rebuild(stack: stack)
    }

    @objc public func clearAll(sender: AnyObject?) {
        let ask = UserDefaults.standard.value(forKey: SettingsPath.askBeforeClearingClippings.rawValue) as? Bool ?? true
        if ask {
            let alert = NSAlert()
            alert.messageText = "Do you want to clear all clippings?"
            alert.informativeText = "This action cannot be undone."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            alert.showsSuppressionButton = true
            alert.suppressionButton!.title = "Do not remind me again"
            let response = alert.runModal()
            if response == .alertFirstButtonReturn && !stack.isEmpty() {
                _clearAll()
            }
            if let supress = alert.suppressionButton {
                if supress.state == NSControl.StateValue.on {
                    UserDefaults.standard.set(false, forKey: SettingsPath.askBeforeClearingClippings.rawValue)
                }
            }
        } else {
            _clearAll()
        }
    }
}
