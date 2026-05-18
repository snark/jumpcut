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
        var paste = Settings.menuSelectionPastes()
        if checkToggle() {
            paste = !paste
        }
        return paste
    }

    private func menuTitle(for clipping: Clipping, extendedFeaturesEnabled: Bool) -> String {
        if extendedFeaturesEnabled && clipping.isFavorite {
            return "[F] \(clipping.shortenedText)"
        }
        return clipping.shortenedText
    }

    private func menuFont(for clipping: Clipping) -> NSFont {
        var font = NSFont.menuFont(ofSize: NSFont.systemFontSize)
        let manager = NSFontManager.shared
        if clipping.isBold {
            font = manager.convert(font, toHaveTrait: .boldFontMask)
        }
        if clipping.isItalic {
            font = manager.convert(font, toHaveTrait: .italicFontMask)
        }
        return font
    }

    private func applyMenuStyle(
        to item: NSMenuItem,
        for clipping: Clipping,
        extendedFeaturesEnabled: Bool
    ) {
        let title = menuTitle(for: clipping, extendedFeaturesEnabled: extendedFeaturesEnabled)
        item.title = title
        guard extendedFeaturesEnabled,
              (clipping.isBold || clipping.isItalic || clipping.labelColor != nil) else {
            return
        }
        var attributes: [NSAttributedString.Key: Any] = [
            .font: menuFont(for: clipping)
        ]
        if let color = clipping.labelColor {
            attributes[.foregroundColor] = color.menuColor
        }
        item.attributedTitle = NSAttributedString(string: title, attributes: attributes)
    }

    private func styleMenuItem(
        title: String,
        action: Selector?,
        position: Int
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = delegate!.interactions!
        item.representedObject = position
        return item
    }

    private func standardItem(
        forClipping clipping: Clipping,
        position: Int,
        extendedFeaturesEnabled: Bool
    ) -> NSMenuItem {
        let standardItem = NSMenuItem(
            title: menuTitle(for: clipping, extendedFeaturesEnabled: extendedFeaturesEnabled),
            action: #selector(self.delegate!.interactions!.menuSelection(sender:)),
            keyEquivalent: ""
        )
        standardItem.representedObject = position
        standardItem.target = delegate!.interactions!
        applyMenuStyle(to: standardItem, for: clipping, extendedFeaturesEnabled: extendedFeaturesEnabled)
        return standardItem
    }

    private func altItem(
        forClipping clipping: Clipping,
        position: Int,
        pasteEnabled: Bool,
        extendedFeaturesEnabled: Bool
    ) -> NSMenuItem {
        let altItem = NSMenuItem(
            title: menuTitle(for: clipping, extendedFeaturesEnabled: extendedFeaturesEnabled),
            action: nil,
            keyEquivalent: ""
        )
        altItem.representedObject = position
        applyMenuStyle(to: altItem, for: clipping, extendedFeaturesEnabled: extendedFeaturesEnabled)
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
        var items = [placeItem, pasteItem]
        if extendedFeaturesEnabled {
            let saveItem = styleMenuItem(
                title: "Save item to file...",
                action: #selector(self.delegate!.interactions!.menuSaveItemToFile(sender:)),
                position: position
            )
            let favoriteItem = styleMenuItem(
                title: clipping.isFavorite ? "Remove from Favourites" : "Add to Favourites",
                action: #selector(self.delegate!.interactions!.menuToggleFavorite(sender:)),
                position: position
            )
            let boldItem = styleMenuItem(
                title: clipping.isBold ? "Remove Bold" : "Make Bold",
                action: #selector(self.delegate!.interactions!.menuToggleBold(sender:)),
                position: position
            )
            boldItem.state = clipping.isBold ? .on : .off
            let italicItem = styleMenuItem(
                title: clipping.isItalic ? "Remove Italic" : "Make Italic",
                action: #selector(self.delegate!.interactions!.menuToggleItalic(sender:)),
                position: position
            )
            italicItem.state = clipping.isItalic ? .on : .off
            items.append(saveItem)
            items.append(favoriteItem)
            items.append(boldItem)
            items.append(italicItem)
            items.append(colorMenuItem(for: clipping, position: position))
        }
        items.append(deleteItem)
        for item in items {
            item.target = delegate!.interactions!
            item.representedObject = position
            submenu.addItem(item)
        }
        return altItem
    }

    private func colorMenuItem(for clipping: Clipping, position: Int) -> NSMenuItem {
        let colorItem = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")
        colorItem.representedObject = position
        let colorMenu = NSMenu()
        colorItem.submenu = colorMenu
        let noneItem = NSMenuItem(
            title: "None",
            action: #selector(self.delegate!.interactions!.menuSetLabelColor(sender:)),
            keyEquivalent: ""
        )
        noneItem.target = delegate!.interactions!
        noneItem.representedObject = "none"
        noneItem.state = clipping.labelColor == nil ? .on : .off
        colorMenu.addItem(noneItem)
        colorMenu.addItem(NSMenuItem.separator())
        for color in ClippingLabelColor.allCases {
            let item = NSMenuItem(
                title: color.title,
                action: #selector(self.delegate!.interactions!.menuSetLabelColor(sender:)),
                keyEquivalent: ""
            )
            item.target = delegate!.interactions!
            item.representedObject = color.rawValue
            item.state = clipping.labelColor == color ? .on : .off
            item.attributedTitle = NSAttributedString(
                string: color.title,
                attributes: [.foregroundColor: color.menuColor]
            )
            colorMenu.addItem(item)
        }
        return colorItem
    }

    private func addFavoritesMenu(menu: NSMenu, stack: ClippingStack) {
        let favoritesMenu = NSMenu()
        let favoritesItem = NSMenuItem(title: "Favourites", action: nil, keyEquivalent: "")
        favoritesItem.submenu = favoritesMenu
        let favorites = stack.favoriteItems()
        if favorites.isEmpty {
            let empty = NSMenuItem(title: "<None>", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            favoritesMenu.addItem(empty)
        } else {
            for favorite in favorites {
                let item = NSMenuItem(
                    title: favorite.clipping.shortenedText,
                    action: #selector(self.delegate!.interactions!.menuSelection(sender:)),
                    keyEquivalent: ""
                )
                item.target = delegate!.interactions!
                item.representedObject = favorite.position
                applyMenuStyle(to: item, for: favorite.clipping, extendedFeaturesEnabled: true)
                favoritesMenu.addItem(item)
            }
        }
        menu.addItem(favoritesItem)
    }

    public func rebuild(stack: ClippingStack) {
        standard.removeAllItems()
        alt.removeAllItems()
        let extendedFeaturesEnabled = Settings.extendedFeaturesEnabled()
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
            for (position, clipping) in clippings.enumerated() {
                standard.addItem(
                    standardItem(
                        forClipping: clipping,
                        position: position,
                        extendedFeaturesEnabled: extendedFeaturesEnabled
                    )
                )
                alt.addItem(
                    altItem(
                        forClipping: clipping,
                        position: position,
                        pasteEnabled: true,
                        extendedFeaturesEnabled: extendedFeaturesEnabled
                    )
                )
            }
        }
        for which in [alt!, standard!] {
            addFixedMenuItems(menu: which, stack: stack, extendedFeaturesEnabled: extendedFeaturesEnabled)
        }
    }

    func addFixedMenuItems(menu: NSMenu, stack: ClippingStack, extendedFeaturesEnabled: Bool) {
        // Shared between alt and standard menus: Clear All, About,
        // Preferences, and Quit
        let appName = ProcessInfo.processInfo.processName
        menu.addItem(NSMenuItem.separator())
        if extendedFeaturesEnabled {
            addFavoritesMenu(menu: menu, stack: stack)
            let saveAllToFile = NSMenuItem(
                title: "Save All to File...",
                action: #selector(self.delegate!.interactions!.saveAllToFile(sender:)),
                keyEquivalent: ""
            )
            saveAllToFile.target = delegate!.interactions!
            saveAllToFile.isEnabled = !stack.isEmpty()
            menu.addItem(saveAllToFile)
            let saveAllAsFiles = NSMenuItem(
                title: "Save All as Files...",
                action: #selector(self.delegate!.interactions!.saveAllAsFiles(sender:)),
                keyEquivalent: ""
            )
            saveAllAsFiles.target = delegate!.interactions!
            saveAllAsFiles.isEnabled = !stack.isEmpty()
            menu.addItem(saveAllAsFiles)
        }
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
