import AppKit
import SwiftUI

@main
enum OP1FunApplication {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
        _ = delegate
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var statusController: StatusController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        OP1Assets.registerFonts()

        let controller = StatusController(model: model)
        statusController = controller
        model.showPopover = { [weak controller] in
            controller?.showPopover(nil)
        }

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(event:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        model.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak controller] in
            controller?.showPopover(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURLEvent(event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        guard
            let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: urlString)
        else {
            return
        }

        statusController?.showPopover(nil)
        model.handleCompanionURL(url)
    }
}

@MainActor
final class StatusController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    init(model: AppModel) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()

        if let button = statusItem.button {
            button.image = Self.makeStatusIcon()
            button.image?.isTemplate = true
            button.toolTip = "op1.fun"
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 600, height: 420)
        popover.contentViewController = NSHostingController(rootView: ContentView(model: model))
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover(sender)
        }
    }

    func showPopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else {
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func makeStatusIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        NSColor.black.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.8
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        path.move(to: NSPoint(x: 2.5, y: 9))
        path.line(to: NSPoint(x: 4.5, y: 9))
        path.curve(
            to: NSPoint(x: 7.5, y: 9),
            controlPoint1: NSPoint(x: 5, y: 14),
            controlPoint2: NSPoint(x: 7, y: 14)
        )
        path.curve(
            to: NSPoint(x: 10.5, y: 9),
            controlPoint1: NSPoint(x: 8, y: 4),
            controlPoint2: NSPoint(x: 10, y: 4)
        )
        path.curve(
            to: NSPoint(x: 13.5, y: 9),
            controlPoint1: NSPoint(x: 11, y: 14),
            controlPoint2: NSPoint(x: 13, y: 14)
        )
        path.line(to: NSPoint(x: 15.5, y: 9))
        path.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
