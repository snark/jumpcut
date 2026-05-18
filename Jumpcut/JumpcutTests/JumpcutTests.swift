//
//  JumpcutTests.swift
//  JumpcutTests
//
//  Created by Steve Cook on 4/15/22.
//

import XCTest
@testable import Jumpcut

class JumpcutTests: XCTestCase {
    private var previousRememberNum: Any?
    private var previousSkipSave: Any?
    private var previousExtendedFeaturesEnabled: Any?
    private var previousMenuSelectionPastes: Any?

    override func setUpWithError() throws {
        previousRememberNum = UserDefaults.standard.object(forKey: SettingsPath.rememberNum.rawValue)
        previousSkipSave = UserDefaults.standard.object(forKey: SettingsPath.skipSave.rawValue)
        previousExtendedFeaturesEnabled = UserDefaults.standard.object(
            forKey: SettingsPath.extendedFeaturesEnabled.rawValue
        )
        previousMenuSelectionPastes = UserDefaults.standard.object(
            forKey: SettingsPath.menuSelectionPastes.rawValue
        )
        UserDefaults.standard.set(500, forKey: SettingsPath.rememberNum.rawValue)
        UserDefaults.standard.set(true, forKey: SettingsPath.skipSave.rawValue)
        UserDefaults.standard.set(true, forKey: SettingsPath.extendedFeaturesEnabled.rawValue)
    }

    override func tearDownWithError() throws {
        restore(previousRememberNum, forKey: SettingsPath.rememberNum)
        restore(previousSkipSave, forKey: SettingsPath.skipSave)
        restore(previousExtendedFeaturesEnabled, forKey: SettingsPath.extendedFeaturesEnabled)
        restore(previousMenuSelectionPastes, forKey: SettingsPath.menuSelectionPastes)
    }

    private func restore(_ value: Any?, forKey key: SettingsPath) {
        if let value = value {
            UserDefaults.standard.set(value, forKey: key.rawValue)
        } else {
            UserDefaults.standard.removeObject(forKey: key.rawValue)
        }
    }

    func testStackCanRememberFiveHundredClippings() throws {
        let stack = ClippingStack()

        for index in 0 ..< 550 {
            stack.add(item: "clip \(index)")
        }

        XCTAssertEqual(stack.count, 500)
        XCTAssertEqual(stack.itemAt(position: 0)?.fullText, "clip 549")
        XCTAssertEqual(stack.itemAt(position: 499)?.fullText, "clip 50")
        XCTAssertNil(stack.itemAt(position: 500))
    }

    func testMenuSelectionDefaultsToPasteWhenPreferenceIsMissing() throws {
        UserDefaults.standard.removeObject(forKey: SettingsPath.menuSelectionPastes.rawValue)

        XCTAssertTrue(Settings.menuSelectionPastes())
    }

    func testExtendedHistoryRequiresOptIn() throws {
        UserDefaults.standard.set(false, forKey: SettingsPath.extendedFeaturesEnabled.rawValue)
        let stack = ClippingStack()

        for index in 0 ..< 120 {
            stack.add(item: "clip \(index)")
        }

        XCTAssertEqual(stack.count, 99)
        XCTAssertEqual(stack.itemAt(position: 0)?.fullText, "clip 119")
        XCTAssertEqual(stack.itemAt(position: 98)?.fullText, "clip 21")
        XCTAssertNil(stack.itemAt(position: 99))
    }

    func testSyncSettingsTrimsToRememberLimit() throws {
        let stack = ClippingStack()
        for index in 0 ..< 25 {
            stack.add(item: "clip \(index)")
        }

        UserDefaults.standard.set(10, forKey: SettingsPath.rememberNum.rawValue)
        stack.syncSettings()

        XCTAssertEqual(stack.count, 10)
        XCTAssertEqual(stack.itemAt(position: 0)?.fullText, "clip 24")
        XCTAssertEqual(stack.itemAt(position: 9)?.fullText, "clip 15")
    }

    func testFavoritesCanBeToggledAndMoveWithClipping() throws {
        let stack = ClippingStack()
        stack.add(item: "first")
        stack.add(item: "second")

        stack.toggleFavorite(position: 1)

        XCTAssertFalse(stack.itemAt(position: 0)?.isFavorite ?? true)
        XCTAssertTrue(stack.itemAt(position: 1)?.isFavorite ?? false)
        XCTAssertEqual(stack.favoriteItems().first?.position, 1)
        XCTAssertEqual(stack.favoriteItems().first?.clipping.fullText, "first")

        stack.moveItemToTop(position: 1)

        XCTAssertEqual(stack.itemAt(position: 0)?.fullText, "first")
        XCTAssertTrue(stack.itemAt(position: 0)?.isFavorite ?? false)
    }

    func testClippingStylesCanBeToggledAndMoveWithClipping() throws {
        let stack = ClippingStack()
        stack.add(item: "plain")
        stack.add(item: "styled")

        stack.toggleBold(position: 1)
        stack.toggleItalic(position: 1)
        stack.setLabelColor(position: 1, color: .green)

        XCTAssertFalse(stack.itemAt(position: 0)?.isBold ?? true)
        XCTAssertTrue(stack.itemAt(position: 1)?.isBold ?? false)
        XCTAssertTrue(stack.itemAt(position: 1)?.isItalic ?? false)
        XCTAssertEqual(stack.itemAt(position: 1)?.labelColor, .green)

        stack.moveItemToTop(position: 1)

        XCTAssertEqual(stack.itemAt(position: 0)?.fullText, "plain")
        XCTAssertTrue(stack.itemAt(position: 0)?.isBold ?? false)
        XCTAssertTrue(stack.itemAt(position: 0)?.isItalic ?? false)
        XCTAssertEqual(stack.itemAt(position: 0)?.labelColor, .green)

        stack.setLabelColor(position: 0, color: nil)

        XCTAssertNil(stack.itemAt(position: 0)?.labelColor)
    }

}
