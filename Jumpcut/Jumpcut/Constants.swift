//
//  Constants.swift
//  Jumpcut
//
//  Created by Steve Cook on 5/21/22.
//

struct Constants {
    // Some longer chunks of text used in alert modals
    struct Alerts {
        static let accessibilityWarning = """
        Jumpcut needs your permission to paste clippings to other applications. \
        Without this permission Jumpcut can place items on the pasteboard but \
        cannot paste.

        To give permission, go to System Preferences → Security & Privacy → Privacy \
        → Accessibility, add Jumpcut, make sure the checkbox is checked, and \
        restart Jumpcut.
        """

        static let cannotSaveWarning = """
        In order to save clippings, Jumpcut must have write access to the "Jumpcut" \
        directory in your Application Support directory (found in your User directory's \
        Library directory). Without this access Jumpcut cannot save your historys.
        """

        static let skipSave = """
        This means clippings will not be preserved when Jumpcut or your computer \
        is restarted.
        """

        static let skipClearBeforeOn = """
        Please clear all clippings before you stop saving clippings to disk.
        """

        static let skipClearBeforeOff = """
        Please clear all clippings before you start saving clippings to disk.
        """

    }
}
