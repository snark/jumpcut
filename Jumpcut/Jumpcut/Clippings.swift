//
//  Clippings.swift
//  Jumpcut
//
//  Created by Steve Cook on 7/24/21.
//

/*
 A clipping is a snippet of text with some simple operators
 to get it in a form that's useful for display.

 A clipping store is a list of clippings, with a persistance backing.

 A clipping stack is an overlay on such a list with a positional index
 which may be adjusted. (In practice, this is done via the keyboard-based
 interface in our bezel.
 */
import Cocoa

struct JCEngine: Codable {
    // displayLen is a duplicative property from older versions of
    // Jumpcut and may safely be ignored--even more so than the other
    // values beyond jcList, which aren't being used for anything.
    var displayLen: Int?
    var displayNum: Int
    var jcList: [JCListItem]
    var rememberNum: Int
    var version: String
}

// These names are from our original Objective-C implementation.
// swiftlint:disable identifier_name
struct JCListItem: Codable {
    let Contents: String
    let Position: Int
    let `Type`: String
}
// swiftlint:enable identifier_name

public class ClippingStack: NSObject {
    private var store: ClippingStore
    public var position: Int = 0
    public var count: Int {
        return store.count
    }
    public var skipSave: Bool {
        get { return store.skipSave }
        set { store.skipSave = newValue }
    }

    override init() {
        self.store = ClippingStore()
        super.init()
        self.store.maxLength = UserDefaults.standard.value(
            forKey: SettingsPath.rememberNum.rawValue
        ) as? Int ?? 99
    }

    func checkWriteAccess() -> Bool {
        return store.checkPlistWriteAccess()
    }

    func isEmpty() -> Bool {
        return store.count == 0
    }

    // swiftlint:disable:next identifier_name
    func firstItems(n: Int) -> ArraySlice<Clipping> {
        return store.firstItems(n: n)
    }

    func clear() {
        store.clear()
    }

    func delete() {
        deleteAt(position: self.position)
    }

    func add(item: String) {
        store.add(item: item)
    }

    func deleteAt(position: Int) {
        guard position < store.count else {
            return
        }
        store.removeItem(position: position)
        if store.count == 0 {
            self.position = 0
        } else if self.position > 0 && self.position >= position {
            // If we're deleting at or above the stack position,
            // move up.
            self.position -= 1
        }
    }

    func down() {
        let newPosition = position + 1
        if newPosition < store.count {
            position = newPosition
        } else {
            if let wraparound = UserDefaults.standard.value(forKey: SettingsPath.wraparoundBezel.rawValue) as? Bool {
                if wraparound {
                    position = 0
                }
            }
        }
    }

    func move(steps: Int) {
        // Differs from up() and down() methods, as we don't allow wrapping around.
        guard self.count > 0 else {
            return
        }
        if steps > 0 {
            let comparable: [Int] = [self.position + steps, self.count - 1]
            self.position = comparable.min()!
        } else {
            let comparable: [Int] = [0, self.position + steps]
            self.position = comparable.max()!
        }
    }

    func itemAt(position: Int) -> Clipping? {
        return store.itemAt(position: position)
    }

    func moveItemToTop(position: Int) {
        store.moveItemToTop(position: position)
    }

    func up() {
        let newPosition = position - 1
        if newPosition >= 0 {
            position = newPosition
        } else {
            if let wraparound = UserDefaults.standard.value(forKey: SettingsPath.wraparoundBezel.rawValue) as? Bool {
                if wraparound {
                    position = store.count - 1
                }
            }
        }
    }
}

public class Clipping: NSObject {
    public let fullText: String
    public var shortenedText: String
    public var length: Int
    private let defaultLength = 40

    init(string: String) {
        fullText = string
        length = defaultLength
        shortenedText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        shortenedText = shortenedText.components(separatedBy: .newlines)[0]
        if shortenedText.count > length {
            shortenedText = String(shortenedText.prefix(length)) + "…"
        }
    }
}

private class ClippingStore: NSObject {

    // TK: Back with sqlite3 for persistence
    private var clippings: [Clipping] = []
    private var _maxLength = 99
    private let plistUrl: URL?
    fileprivate var skipSave: Bool

    fileprivate var maxLength: Int {
        get { return _maxLength }
        set {
            let newValueWithMin = newValue < 10 ? 10 : newValue
            clippings = Array(self.firstItems(n: newValueWithMin))
            _maxLength = newValueWithMin
        }
    }

    private static func getSupportDir() -> URL? {
        // Adapted from Rectangle's preferences loader
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let supportDir = paths.isEmpty ? nil : paths[0].appendingPathComponent("Jumpcut", isDirectory: true)
        guard supportDir != nil else {
            return nil
        }
        if !FileManager.default.fileExists(atPath: supportDir!.path) {
            do {
                try FileManager.default.createDirectory(
                    at: supportDir!,
                    withIntermediateDirectories: false,
                    attributes: nil
                )
            } catch {
                print("Unable to create support directory", error)
            }
        }
        return supportDir
    }

    override init() {
        // TK: We will eventually be switching this out to use SQLite3, but for
        // now we'll use a hardcoded path to a property list.
        skipSave = UserDefaults.standard.value(forKey: SettingsPath.skipSave.rawValue) as? Bool ?? false
        if let jumpcutSupportDir = ClippingStore.getSupportDir() {
            plistUrl = jumpcutSupportDir.appendingPathComponent("JCEngine.save")
        } else {
            plistUrl = nil
        }
        super.init()
        if !skipSave {
            loadFromPlist(path: plistUrl)
        }
    }

    func checkPlistWriteAccess() -> Bool {
        guard plistUrl != nil else {
            return false
        }
        var resourceValues = URLResourceValues()
        resourceValues.contentModificationDate = Date()
        let manager = FileManager()
        let plistPath = plistUrl!.path
        let result: Bool
        if !manager.fileExists(atPath: plistPath) {
            result = manager.createFile(atPath: plistPath, contents: nil, attributes: nil)
        } else {
            result = manager.isWritableFile(atPath: plistPath)
        }
        return result
    }

    func loadFromPlist(path: URL?) {
        guard path != nil else {
            return
        }
        var savedValues: JCEngine
        let allowWhitespace = UserDefaults.standard.value(
            forKey: SettingsPath.allowWhitespaceClippings.rawValue
        ) as? Bool ?? false
        if let data = try? Data(contentsOf: path!) {
            do {
                savedValues = try PropertyListDecoder().decode(JCEngine.self, from: data)
                for clipDict in savedValues.jcList.reversed() {
                    let clipIsEmpty = clipDict.Contents.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                    if !clipIsEmpty || allowWhitespace {
                        self.add(item: clipDict.Contents)
                    }
                }
            } catch {
                print("Unable to load clippings store plist")
            }
        }
    }

    var count: Int {
        return clippings.count
    }

    private func writeClippings() {
        guard !skipSave, plistUrl != nil else {
            return
        }
        var items: [JCListItem] = []
        var counter = 0
        for clip in clippings {
            items.append(JCListItem(Contents: clip.fullText, Position: counter, Type: "NSStringPboardType"))
            counter += 1
        }
        let data = JCEngine(
            displayNum: UserDefaults.standard.value(forKey: SettingsPath.displayNum.rawValue) as? Int ?? 10,
            jcList: items,
            rememberNum: UserDefaults.standard.value(forKey: SettingsPath.displayNum.rawValue) as? Int ?? 99,
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        )
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        do {
            let newData = try encoder.encode(data)
            try newData.write(to: plistUrl!)
        } catch {
            print("Unable to write clippings store plist file")
        }
    }

    func add(item: String) {
        clippings.insert(Clipping(string: item), at: 0)
        if clippings.count > maxLength {
            clippings.removeLast()
        }
        // TK: When we have SQLite backing, we'll want to change this.
        writeClippings()
    }

    func clear() {
        clippings = []
        // TK: When we have SQLite backing, we'll want to change this.
        writeClippings()
    }

    func moveItemToTop(position: Int) {
        // Don't move from an invalid position; also, position 0
        // is a null operation, because it's already at the top.
        guard !clippings.isEmpty,
            position <= clippings.count,
            position > 0
        else {
            return
        }
        let element = clippings.remove(at: position)
        clippings.insert(element, at: 0)
        writeClippings()
    }

    func itemAt(position: Int) -> Clipping? {
        if clippings.isEmpty || position > clippings.count {
            return nil
        }
        return clippings[position]
    }

    func removeItem(position: Int) {
        if clippings.isEmpty || position > clippings.count {
            return
        }
        clippings.remove(at: position)
        // TK: When we have SQLite backing, we'll want to change this.
        writeClippings()
    }

    // swiftlint:disable:next identifier_name
    func firstItems(n: Int) -> ArraySlice<Clipping> {
        var slice: ArraySlice<Clipping>
        if n > clippings.count {
            slice = clippings[...]
        } else {
            slice = clippings[0 ..< n]
        }
        return slice
    }
}
