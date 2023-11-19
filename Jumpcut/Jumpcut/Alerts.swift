//
//  Alerts.swift
//  Jumpcut
//
//  Created by Steve Cook on 11/19/23.
//

import Cocoa

public class Alerts {

    static func authorizePaste() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Authorize Jumpcut to Paste"
        alert.informativeText = Constants.Alerts.accessibilityWarning
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Accessibility")
        alert.addButton(withTitle: "Continue")
        alert.showsSuppressionButton = true
        alert.suppressionButton!.title = "Do not remind me again"
        return alert
    }

    static func clearAllWarning() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Do you want to clear all clippings?"
        alert.informativeText = "This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.showsSuppressionButton = true
        alert.suppressionButton!.title = "Do not remind me again"
        return alert
    }

    static func resetPreferences() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Do you want to reset preferences?"
        alert.informativeText = "This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return alert
    }

    static func saveFileWarning() -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "No save access"
        alert.informativeText = Constants.Alerts.cannotSaveWarning
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continue")
        return alert
    }

}
