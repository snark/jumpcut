//
//  HotkeyListeners.swift
//  Jumpcut
//
//  Created by Steve Cook on 4/16/22.
//

import Cocoa

public class HotkeyListeners {
    weak private var delegate: AppDelegate!

    init() {
        self.delegate = (NSApplication.shared.delegate as? AppDelegate)!
    }

    func startRecorderListeners() {
        // Prevent triggering our bezel while we record a new hotkey
        // by observing when we start and end our recordings.
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(mainHotkeyBeganRecording),
                                               name: NSNotification.Name("recorderBeganRecording.mainHotkey"),
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(mainHotkeyEndedRecording),
                                               name: NSNotification.Name("recorderEndedRecording.mainHotkey"),
                                               object: nil)
    }

    @objc func mainHotkeyBeganRecording() {
        delegate.mainHotkeyIsRecording = true
    }

    @objc func mainHotkeyEndedRecording() {
        delegate.mainHotkeyIsRecording = false
        delegate.setHotkey()
    }
}
