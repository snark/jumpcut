//
//  JumpcutHelperAppDelegate.swift
//  JumpcutHelper
//
//  Created by Steve Cook on 4/16/22.
//

import Cocoa

class JumpcutHelperAppDelegate: NSObject, NSApplicationDelegate {

    let mainAppIdentifier = "net.sf.Jumpcut"

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains {
            $0.bundleIdentifier == mainAppIdentifier
        }

        /*
         * We should be able to use
         guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: mainAppIdentifier) else { return }
         in a post-10.15 setup, but it seems to be getting confused by the debug
         build on a developer machine. It's a cleaner solution, so if we can figure
         out why it doesn't correctly identify the /Application item as taking precedence,
         we should switch to that.
        */
        let pathComponents = (Bundle.main.bundlePath as NSString).pathComponents
        let mainPath = NSString.path(withComponents: Array(pathComponents[0...(pathComponents.count - 5)]))
        if !isRunning {
            if #available(macOS 10.15, *) {
                print("Post 15")
                let fileUrl = URL(fileURLWithPath: mainPath)
                print(fileUrl)
                NSWorkspace.shared.openApplication(at: fileUrl,
                                                   configuration: NSWorkspace.OpenConfiguration(),
                                                   completionHandler: nil)
            } else {
                print("Pre 15")
                NSWorkspace.shared.launchApplication(mainPath)
            }
            print("Open attempted!")
        } else {
            print("Already running")
        }
        print("About to terminate")
        NSApplication.shared.terminate(self)
    }
}
