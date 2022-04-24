//
//  Bezel.swift
//  Jumpcut
//
//  Created by Steve Cook on 9/13/20.
//

import Cocoa

public struct BezelAppearance {
    let bezelSize: CGSize
    let outletSize: CGSize
    let secondaryOutletSize: CGSize?
    let windowAlpha: Double
    let windowAttributes: AppearanceAttributes
    let mainOutletAttributes: AppearanceAttributes
    let secondaryOutletAttributes: AppearanceAttributes?
    let outletFontColor: NSColor
}

public struct AppearanceAttributes {
    let backgroundColor: NSColor
    let borderWidth: Double
    let borderColor: NSColor
    let cornerRadius: Double
}

public class Bezel {

    let window: KeyCaptureWindow
    var shown: Bool = false

    fileprivate var mainOutlet: Outlet
    fileprivate var secondaryOutlet: Outlet? // Used for display of stack number

    // TODO: Add controls for positioning on window -- NB, not part of BezelAppearance
    //      -- Center, Top Left, Top Right, Top Center, Bottom Center
    // TODO: Add controls for positioning main outlet, secondary outlet
    // TODO: Add controls for changing the appearance

    static let defaultAppearance = BezelAppearance(
        bezelSize: CGSize(width: 325, height: 325),
        outletSize: CGSize(width: 300, height: 200),
        secondaryOutletSize: CGSize(width: 36, height: 30),
        windowAlpha: 0.8,
        windowAttributes: AppearanceAttributes(
            backgroundColor: NSColor.init(calibratedWhite: 0.1, alpha: 0.6),
            borderWidth: 0.0,
            borderColor: .clear,
            cornerRadius: 25.0
        ),
        mainOutletAttributes: AppearanceAttributes(
            backgroundColor: NSColor.init(calibratedWhite: 0.1, alpha: 0.9),
            borderWidth: 1.0,
            borderColor: .black,
            cornerRadius: 12.0
        ),
        secondaryOutletAttributes: AppearanceAttributes(
            backgroundColor: NSColor.init(calibratedWhite: 0.1, alpha: 0.9),
            borderWidth: 1.0,
            borderColor: .black,
            cornerRadius: 12.0
        ),
        outletFontColor: .white
    )

    fileprivate static func makeOutlet(size: CGSize, attributes: AppearanceAttributes) -> Outlet {
        return Outlet(
            width: size.width,
            height: size.height,
            backgroundColor: attributes.backgroundColor,
            cornerRadius: attributes.cornerRadius,
            borderWidth: attributes.borderWidth,
            borderColor: attributes.borderColor
        )
    }

    public init() {
        let appearance = Bezel.defaultAppearance
        window = KeyCaptureWindow(contentRect: NSRect(origin: .zero, size: appearance.bezelSize),
                                  styleMask: .borderless, backing: .buffered, defer: true)
        mainOutlet = Bezel.makeOutlet(size: appearance.outletSize, attributes: appearance.mainOutletAttributes)
        if let secondarySize = appearance.secondaryOutletSize {
            var outletAttributes: AppearanceAttributes
            if appearance.secondaryOutletAttributes != nil {
                outletAttributes = appearance.secondaryOutletAttributes!
            } else {
                outletAttributes = appearance.mainOutletAttributes
            }
            secondaryOutlet = Bezel.makeOutlet(size: secondarySize, attributes: outletAttributes)
        } else {
            secondaryOutlet = nil
        }
        buildWindow(
            windowAlpha: appearance.windowAlpha,
            windowBackgroundColor: appearance.windowAttributes.backgroundColor,
            windowCornerRadius: appearance.windowAttributes.cornerRadius
        )
        window.contentView!.addSubview(mainOutlet.embedderView)
        if secondaryOutlet != nil {
            window.contentView!.addSubview(secondaryOutlet!.embedderView)
        }
        var constraints = [
            mainOutlet.embedderView.widthAnchor.constraint(equalToConstant: appearance.outletSize.width),
            mainOutlet.embedderView.heightAnchor.constraint(equalToConstant: appearance.outletSize.height),
            mainOutlet.embedderView.centerXAnchor.constraint(equalTo: window.contentView!.centerXAnchor),
            mainOutlet.embedderView.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -10)
        ]
        if secondaryOutlet != nil {
            constraints.append(
                secondaryOutlet!.embedderView.widthAnchor.constraint(
                    equalToConstant: appearance.secondaryOutletSize!.width
                )
            )
            constraints.append(
                secondaryOutlet!.embedderView.heightAnchor.constraint(
                    equalToConstant: appearance.secondaryOutletSize!.height
                )
            )
            constraints.append(
                secondaryOutlet!.embedderView.centerXAnchor.constraint(
                    equalTo: window.contentView!.centerXAnchor
                )
            )
            constraints.append(
                secondaryOutlet!.embedderView.bottomAnchor.constraint(
                    equalTo: mainOutlet.embedderView.topAnchor, constant: -10
                )
            )
        }
        NSLayoutConstraint.activate(constraints)
    }

    public func shouldSelectionPaste() -> Bool {
        // Unlike the menu manager version, there's no toggling.
        let paste =
 UserDefaults.standard.value(forKey: SettingsPath.bezelSelectionPastes.rawValue) as? Bool ?? false
        return paste
    }

    public func setKeyDownHandler(handler: @escaping (NSEvent) -> Void) {
        window.keyDownHandler = handler
    }

    public func setMetaKeyReleaseHandler(handler: @escaping () -> Void) {
        window.metaKeyReleaseHandler = handler
    }

    public func setText(text: String) {
        mainOutlet.setText(text: text)
    }

    public func setSecondaryText(text: String) {
        secondaryOutlet?.setText(text: text, align: .center)
    }

    public func setWindowSize(size: CGSize) {
        var newFrame = window.frame
        newFrame.size.height = size.height
        newFrame.size.width = size.width
        window.setFrame(newFrame, display: true)
    }

    func buildWindow(
        windowAlpha: Double,
        windowBackgroundColor: NSColor,
        windowCornerRadius: Double
    ) {
        // Not under caller's control
        window.backgroundColor = .clear
        window.hasShadow = false
        window.hidesOnDeactivate = true
        window.isOpaque = false
        window.level = .modalPanel
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        window.alphaValue = CGFloat(windowAlpha)

        let contentView = NSView(frame: self.window.frame)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.wantsLayer = true
        contentView.layer!.cornerRadius = CGFloat(windowCornerRadius)
        contentView.layer!.masksToBounds = true
        contentView.layer!.backgroundColor = windowBackgroundColor.cgColor

        //        let effectView = NSVisualEffectView(frame: self.window.frame)
        //        effectView.translatesAutoresizingMaskIntoConstraints = false
        //        // Could also be ".popover" for a lighter appearance
        //        effectView.material = .dark
        //        effectView.state = .active
        //        effectView.translatesAutoresizingMaskIntoConstraints = false
        //
        //        contentView.addSubview(effectView)

        self.window.contentView = contentView
    }

    public func hide() {
        window.orderOut(nil)
        shown = false
    }

    public func show() {
        window.center()
        window.makeKeyAndOrderFront(self)
        shown = true
    }

}

private struct OutletFontConfig {
    let color: NSColor
    let size: Int
    let monospaced: Bool
}

private class Outlet {

    let embedderView: NSView
    let textView: NSTextView
    var fontConfig: OutletFontConfig

    public init(
        width: CGFloat,
        height: CGFloat,
        backgroundColor: NSColor,
        cornerRadius: Double,
        borderWidth: Double,
        borderColor: NSColor,
        fontSize: Int = 14,
        fontColor: NSColor = .white
    ) {
        let embedderRect = NSRect(x: 0, y: 0, width: width, height: height)
        embedderView = NSView(frame: embedderRect)
        textView = NSTextView(
            frame: NSRect(
                x: 2, y: 1, width: embedderRect.size.width - 4, height: embedderRect.size.height - 2
            )
        )
        textView.isEditable = false
        textView.isSelectable = false
        // This is critical to preventing partial lines from displaying
        textView.textContainer!.lineBreakMode = .byClipping
        textView.backgroundColor = backgroundColor
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.textContainerInset = NSSize(width: 1, height: 1)

        embedderView.translatesAutoresizingMaskIntoConstraints = false
        embedderView.wantsLayer = true

        embedderView.layer?.borderColor = borderColor.cgColor
        embedderView.layer?.borderWidth = CGFloat(borderWidth)
        embedderView.layer?.cornerRadius = CGFloat(cornerRadius)
        embedderView.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.widthAnchor.constraint(equalTo: embedderView.widthAnchor, constant: -2),
            textView.heightAnchor.constraint(equalTo: embedderView.heightAnchor, constant: -2),
            textView.centerXAnchor.constraint(equalTo: embedderView.centerXAnchor),
            textView.centerYAnchor.constraint(equalTo: embedderView.centerYAnchor)
        ])

        fontConfig = OutletFontConfig(
            color: fontColor,
            size: fontSize,
            monospaced: false
        )
    }

    public func setText(text: String) {
        self.setText(text: text, align: nil)
    }

    public func setText(text: String, align: BezelAlignment?) {
        // swiftlint:disable:next line_length
        // Monospacing: https://stackoverflow.com/questions/46642335/how-do-i-get-a-monospace-font-that-respects-acessibility-settings
        let paragraph = NSMutableParagraphStyle()
        var useAlign = align
        paragraph.lineSpacing = 1.2
        if useAlign == nil {
            let pref = UserDefaults.standard.object(forKey: SettingsPath.bezelAlignment.rawValue) as? String
            useAlign = BezelAlignment(rawValue: pref ?? BezelAlignment.center.rawValue) ?? BezelAlignment.center
        }
        switch useAlign {
        case .smartAlign:
            if text.count > 100 || text.contains(where: { $0.isNewline }) {
                paragraph.alignment = .left
            } else {
                paragraph.alignment = .center
            }
        case .left:
            paragraph.alignment = .left
        case .right:
            paragraph.alignment = .right
        default:
            paragraph.alignment = .center
        }
        // We could set it to center here.
        let font: NSFont
        if fontConfig.monospaced {
            // NB: We only have access to SF Mono/monospacedSystemFont in 10.15 or later.
            if #available(OSX 10.15, *) {
                // SF Mono looks significantly better than Courier New.
                font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontConfig.size), weight: NSFont.Weight.medium)
            } else {
                font = NSFont(name: "Courier New", size: CGFloat(fontConfig.size))!
            }
        } else {
            font = NSFont.systemFont(ofSize: CGFloat(fontConfig.size))
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: fontConfig.color,
            .paragraphStyle: paragraph
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        textView.textStorage?.setAttributedString(attrString)
    }
}

class KeyCaptureWindow: NSWindow {

    override var acceptsFirstResponder: Bool { return true }
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }

    fileprivate var metaKeyReleaseHandler: (() -> Void)?
    fileprivate var keyDownHandler: ((NSEvent) -> Void)?

    override func keyDown(with event: NSEvent) {
        // We will not pass through keyDown events while the bezel is active.
        // super.keyDown(with: event)
        if let keyDown = keyDownHandler {
            keyDown(event)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        if !event.modifierFlags.contains(.option) &&
                !event.modifierFlags.contains(.command) &&
                !event.modifierFlags.contains(.control) &&
                !event.modifierFlags.contains(.shift) {
            if let keyRelease = metaKeyReleaseHandler {
                keyRelease()
            }
        }
        super.flagsChanged(with: event)
    }
}
