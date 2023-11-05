//
//  AppDelegate.swift
//  Jumpcut
//
//  Created by Steve Cook on 4/16/22.
//

import Cocoa
import HotKey
import LaunchAtLogin
import Preferences
import Sauce
import ShortcutRecorder
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate, SPUStandardUserDriverDelegate, SPUUpdaterDelegate {

    private var pasteboard: Pasteboard!
    private var stack: ClippingStack!
    private var menu: MenuManager!
    private var statusItem: StatusItem!
    private let bezel = Bezel()
    private var hkListeners: HotkeyListeners!
    // Hotkey
    private var hotKey: HotKey?
    public var hotKeyBase: SauceKey?
    public var mainHotkeyIsRecording = false
    // Sparkle
    public var sparkleUpdater: SPUUpdater!

    // Logic for all our UX behaviors
    public var interactions: Interactions!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Settings.registerDefaults()
        // Initialize Sparkle
        let bundle = Bundle.main
        let sparkleDriver = SPUStandardUserDriver(hostBundle: bundle, delegate: self)
        sparkleUpdater = SPUUpdater(
            hostBundle: bundle, applicationBundle: bundle, userDriver: sparkleDriver, delegate: self
        )
        statusItem = StatusItem()
        stack = ClippingStack()
        pasteboard = Pasteboard(changeCallback: pasteboardChangeClosure)
        // And our menus, now that we have the stack
        menu = MenuManager()
        // And now we have what we need to deal with user interactions
        interactions = Interactions(bezel: bezel, menu: menu, pasteboard: pasteboard, stack: stack)
        // Which means we can build the menu
        menu.rebuild(stack: stack)
        hkListeners = HotkeyListeners()
        let checkForUpdates = UserDefaults.standard.value(
            forKey: SettingsPath.checkForUpdates.rawValue
        ) as? Bool ?? false
        if checkForUpdates {
            checkSparkle(background: true)
        }
        // NB:
        // hkListeners' methods; interactions.setHotkeyHandlers; and setHotkey
        // should eventually be unified into a single class, but at the moment,
        // setHotkey is tightly coupled to a number of AppDelegate-specific items
        // (primarily the bezel); more refactoring to turn the AppDelegate into
        // simply a message-passer is required.

        // Observe some UI-type events
        hkListeners.startRecorderListeners()

        // Set up hotkey and bezel handlers
        setHotkey()
        interactions.setHotkeyHandlers()

        // If we are coming from an earlier version, let's set the new launch-on-login
        // preference. (This is safe to do under any circumstance.)
        LaunchAtLogin.isEnabled = UserDefaults.standard.value(
            forKey: SettingsPath.launchOnStartup.rawValue) as? Bool ?? false

        // Should we show an alert here if we are headless?
        statusItem.setVisibility()

        // Hard to double-click an icon in debug mode!
        #if DEBUG
        let headless = UserDefaults.standard.value(forKey: SettingsPath.hideStatusItem.rawValue) as? Bool ?? false
        if headless {
            openPreferencesWindow(sender: self)
        }
        #endif

        setObservers()

        if !AXIsProcessTrusted() &&
            UserDefaults.standard.value(forKey: SettingsPath.askForAccessibility.rawValue) as? Bool ?? true {
                #if DEBUG
                // Running in debug mode in Xcode doesn't seem to
                // pick up our accessibility settings. Why?
                #else
                showAccessibilityWarning()
                #endif
        }
    }

    private func setObservers() {
        // We can't use KV observers until we are only targeting 10.15
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStateFromSettings),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateKeyboardCodes),
            name: NSNotification.Name.SauceSelectedKeyboardKeyCodesChanged,
            object: nil
        )
    }

    func showAccessibilityWarning() {
        let alert = NSAlert()
        alert.messageText = "Authorize Jumpcut to Paste"
        alert.informativeText = Constants.Alerts.accessibilityWarning
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Accessibility")
        alert.addButton(withTitle: "Continue")
        alert.showsSuppressionButton = true
        alert.suppressionButton!.title = "Do not remind me again"

        let response = alert.runModal()
        if response == NSApplication.ModalResponse.alertFirstButtonReturn {
            let axPanel = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            NSWorkspace.shared.open(NSURL.init(string: axPanel)! as URL)
        }
        if let supress = alert.suppressionButton {
            if supress.state == NSControl.StateValue.on {
                UserDefaults.standard.set(false, forKey: SettingsPath.askForAccessibility.rawValue)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // For now we're always going to reopen, regardless of headless status,
        // to allow people to deal with notch situations.
        self.openPreferencesWindow(sender: self)
        return true
    }

    @objc func updateKeyboardCodes(_ notification: Notification) {
        setHotkey()
    }

    @objc func updateStateFromSettings(_ notification: Notification) {
        // At the moment all we need to do is redraw the menu and update,
        // the menu bar's visibility, rather than a more detailed examination
        // of what has changed.
        statusItem.setVisibility()
        menu.rebuild(stack: stack)
    }

    func checkMenuBehavior(_ event: NSEvent) -> Bool {
        let wanted: MenuBehaviorFlags
        if let trigger = (
            UserDefaults.standard.value(forKey: SettingsPath.menuBehaviorFlags.rawValue) as? String
        ) {
            wanted = MenuBehaviorFlags(rawValue: trigger) ?? MenuBehaviorFlags.none
        } else {
            wanted = MenuBehaviorFlags.none
        }
        if wanted == MenuBehaviorFlags.rightAlt || wanted == MenuBehaviorFlags.rightAltShiftToggle {
            return event.type == NSEvent.EventType.rightMouseUp
        } else if wanted == MenuBehaviorFlags.shiftAlt || wanted == MenuBehaviorFlags.shiftAltRightToggle {
            return event.modifierFlags.contains(.shift)
        } else {
            return false
        }
    }

    @objc func statusItemClicked(sender: NSStatusBarButton!) {
        let event = NSApp.currentEvent!
        let useAlt = checkMenuBehavior(event)
        if useAlt {
            statusItem.displayMenu(menu.alt)
        } else {
            menu.triggerEvent = event
            statusItem.displayMenu(menu.standard)
        }
    }

    func hide() {
        self.bezel.hide()
        NSApp.hide(nil)
    }

    func clearHotkey() {
        hotKey = nil
        hotKeyBase = nil
    }

    func stackEmpty() -> Bool {
        return stack.isEmpty()
    }

    func setSkipSave(value: Bool) {
        stack.setSkipSave(value: value)
    }

    func setHotkey() {
        if var dictionary = UserDefaults.standard.value(forKey: SettingsPath.mainHotkey.rawValue)
            as? [AnyHashable: Any] {
            // A null keyCode means we're not using the hotkey. Return!
            guard var keyCode = dictionary["keyCode"] as? Int else {
                clearHotkey()
                return
            }
            // Our on-disk representation of the hotkey uses QWERTY. Imagine that
            // we have saved a hotkey as "Command-Option-Control-V". We now
            // have a keyCode of "9". We want to set the shortcut to be V, regardless
            // of our current keyboard—for instance, if the user has switched between Dvorak
            // and QWERTY. Both ShortcutRecorder and HotKey are tracking the physical
            // keys, so let's duplicate the dictionary and set the right key
            // code. If it's not in our current keyboard representation, we will
            // *not* clear the hotkey—maybe the user will switch soon!—but *will*
            // return. No hotkey if we can't figure out how to map it!
            if let ignoringModifier = dictionary["charactersIgnoringModifiers"] as? String {
                if let character = SauceKey.init(character: ignoringModifier, virtualKeyCode: nil) {
                    let currentKeyCode = Sauce.shared.currentKeyCode(for: character)
                    if currentKeyCode != nil {
                        #if DEBUG
                        print("Updating key code to \(currentKeyCode!)")
                        #endif
                        dictionary["keyCode"] = currentKeyCode!
                        // Replace the keyCode variable so that we set the
                        // hotkey base correctly below.
                        keyCode = Int(currentKeyCode!)
                    }
                }
            }
            let shortcut = Shortcut.init(dictionary: dictionary)
            if shortcut == nil {
                return
            }
            clearHotkey()
            hotKey = HotKey.init(
                carbonKeyCode: shortcut!.carbonKeyCode,
                carbonModifiers: shortcut!.carbonModifierFlags
            )
            hotKey!.keyDownHandler = {
                guard !self.mainHotkeyIsRecording else {
                    // We're recording, so don't activate the bezel.
                    return
                }
                if !self.bezel.shown {
                    self.interactions.displayBezelAtPosition(position: self.stack.position)
                } else {
                    self.stack.down()
                    self.interactions.displayBezelAtPosition(position: self.stack.position)
                }
            }
            // Again, this uses the physical keyboard representation, rather than
            // the actual character. For instance, using Dvorak, "V" is actually
            // .period.
            hotKeyBase = SauceKey.init(QWERTYKeyCode: keyCode)
        } else {
            clearHotkey()
        }
    }

    func pasteboardChangeClosure() {
        guard pasteboard.lastFound != nil else {
            return
        }
        if stack.itemAt(position: 0) == nil
            || stack.itemAt(position: 0)!.fullText != pasteboard.lastFound! {
            stack.add(item: pasteboard.lastFound!)
            if UserDefaults.standard.value(
                forKey: SettingsPath.bezelToTop.rawValue
            ) as? Int ?? 1 == 1 {
                stack.position = 0
            } else {
                stack.position += 1
                // If we've reached the end, we'll bump along at the bottom
                // for now.
                if stack.position >= stack.count {
                    stack.position -= 1
                }
            }
            menu.rebuild(stack: stack)
        }
    }

    @objc func openAboutWindow(sender: AnyObject?) {
        bezel.hide()
        NSApplication.shared.orderFrontStandardAboutPanel()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openPreferencesWindow(sender: AnyObject?) {
        bezel.hide()
        preferencesWindowController.show()
        preferencesWindowController.window?.makeKeyAndOrderFront(sender)
    }

    // Called from a button, should be visible
    @objc func checkSparkle(sender: Any?) {
        checkSparkle(background: false)
    }

    private func checkSparkle(background: Bool) {
        do {
            try sparkleUpdater.start()
            if background {
                sparkleUpdater.checkForUpdatesInBackground()
            } else {
                sparkleUpdater.checkForUpdates()
            }
        } catch {
            #if DEBUG
            print("Unable to check Sparkle")
            #endif
        }
    }

    @objc func quit(sender: AnyObject?) {
        NSApplication.shared.terminate(nil)
    }

    func applicationWillResignActive(_ aNotification: Notification) {
        if bezel.shown {
            bezel.hide()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}
