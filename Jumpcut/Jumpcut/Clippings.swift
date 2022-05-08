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

    override init() {
        self.store = ClippingStore()
        super.init()
        self.store.maxLength = UserDefaults.standard.value(
            forKey: SettingsPath.rememberNum.rawValue
        ) as? Int ?? 99
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

    func itemAt(position: Int) -> Clipping? {
        return store.itemAt(position: position)
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
    private let plistPath: String
    private let skipSave: Bool

    fileprivate var maxLength: Int {
        get { return _maxLength }
        set {
            let newValueWithMin = newValue < 10 ? 10 : newValue
            clippings = Array(self.firstItems(n: newValueWithMin))
            _maxLength = newValueWithMin
        }
    }

    override init() {
        // TK: We will eventually be switching this out to use SQLite3, but for
        // now we'll use a hardcoded path to a property list.
        skipSave = UserDefaults.standard.value(forKey: SettingsPath.skipSave.rawValue) as? Bool ?? false
        plistPath = NSString(string: "~/Library/Application Support/Jumpcut/JCEngine.save").expandingTildeInPath
        super.init()
        if !skipSave {
            loadFromPlist(path: plistPath)
        }
    }

    func loadFromPlist(path: String) {
        let fullPath = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: fullPath)
        var savedValues: JCEngine
        if let data = try? Data(contentsOf: url) {
            do {
                savedValues = try PropertyListDecoder().decode(JCEngine.self, from: data)
                for clipDict in savedValues.jcList.reversed() {
                    if !clipDict.Contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
        guard !skipSave else {
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
            let url = URL(fileURLWithPath: plistPath)
            try newData.write(to: url)
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
