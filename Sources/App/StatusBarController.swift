import AppKit
import SwiftUI

/// Owns the menu bar status item and a native `NSPopover` (the pattern used by
/// polished menu bar apps): smooth open/close animation, a real arrow pointing
/// at the icon, and transient auto-dismiss on outside clicks.
@MainActor
final class StatusBarController: NSObject, ObservableObject {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    /// Whether to show the pet's quote line next to the menu bar icon (default off).
    @Published var showQuoteOnMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showQuoteOnMenuBar, forKey: "agentpet.showQuoteMenuBar")
            updateStatus()
        }
    }

    override init() {
        showQuoteOnMenuBar = (UserDefaults.standard.object(forKey: "agentpet.showQuoteMenuBar") as? Bool) ?? false
        super.init()
    }

    /// Recomputes the menu bar title (called when the quote line changes).
    func refreshTitle() { updateStatus() }

    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = Self.menuBarImage(count: nil, waiting: false)
        item.button?.imagePosition = .imageLeading
        item.button?.target = self
        item.button?.action = #selector(toggle)
        statusItem = item

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.appearance = NSAppearance(named: .darkAqua)
        let host = NSHostingController(rootView: MenuContentView(dismiss: { [weak self] in
            self?.popover.performClose(nil)
        }))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
    }

    /// Closes the popover when the user clicks anywhere outside it (including
    /// other apps / the desktop), which a transient popover can miss for a
    /// non-activating menu bar app.
    private var outsideClickMonitor: Any?

    @objc private func toggle() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    /// Refreshes the menu bar icon and, when enabled, the optional menu-bar quote
    /// bubble. In minimal mode, the icon stays as a fixed paw symbol.
    func updateStatus() {
        guard let button = statusItem?.button else { return }
        button.title = ""
        button.image = Self.menuBarImage(count: nil, waiting: false)

        refreshQuoteBubble()
    }

    /// Builds the menu bar image: paw-only in minimal mode.
    private static func menuBarImage(count: Int?, waiting: Bool) -> NSImage? {
        guard let paw = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "AgentPet") else { return nil }

        guard let count else {
            paw.isTemplate = true
            return paw
        }

        let font = NSFont.systemFont(ofSize: 13, weight: .bold)
        let text = "\(count)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let textSize = text.size(withAttributes: attrs)
        let pawSize = paw.size
        let gap: CGFloat = 3
        let w = ceil(pawSize.width + gap + textSize.width)
        let h = ceil(max(pawSize.height, textSize.height))

        let img = NSImage(size: NSSize(width: w, height: h))
        img.lockFocus()
        paw.draw(in: NSRect(x: 0, y: (h - pawSize.height) / 2, width: pawSize.width, height: pawSize.height))
        text.draw(at: NSPoint(x: pawSize.width + gap, y: (h - textSize.height) / 2), withAttributes: attrs)
        if waiting {
            NSColor.systemOrange.set()
            NSRect(x: 0, y: 0, width: w, height: h).fill(using: .sourceAtop)
        }
        img.unlockFocus()
        img.isTemplate = !waiting
        return img
    }

    // MARK: - Quote bubble dropping from the menu bar

    private var quotePanel: NSPanel?
    private var quoteHideTimer: Timer?
    private var lastShownQuote = ""

    private func refreshQuoteBubble() {
        let quote = PetController.shared.quoteLine
        guard showQuoteOnMenuBar, !quote.isEmpty else {
            hideQuoteBubble()
            return
        }
        guard quote != lastShownQuote else { return }
        lastShownQuote = quote
        showQuoteBubble(quote)
    }

    private func showQuoteBubble(_ text: String) {
        guard let button = statusItem?.button, let buttonWindow = button.window else { return }

        let host = NSHostingView(rootView: MenuBarQuoteBubble(text: text))
        host.setFrameSize(host.fittingSize)
        let size = host.fittingSize

        let panel = quotePanel ?? {
            let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
            p.level = .popUpMenu
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.ignoresMouseEvents = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            quotePanel = p
            return p
        }()
        panel.contentView = host
        panel.setContentSize(size)

        let frame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let originX = frame.midX - size.width / 2
        panel.setFrameOrigin(NSPoint(x: originX, y: frame.minY - size.height + 2))
        panel.orderFrontRegardless()

        quoteHideTimer?.invalidate()
        quoteHideTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in
            Task { @MainActor [weak self] in self?.hideQuoteBubble() }
        }
    }

    private func hideQuoteBubble() {
        quoteHideTimer?.invalidate()
        quotePanel?.orderOut(nil)
        lastShownQuote = ""
    }

    /// Shows the same popover anchored to an arbitrary view (e.g. the floating
    /// pet on right-click).
    func showPopover(relativeTo rect: NSRect, of view: NSView, edge: NSRectEdge) {
        if popover.isShown { popover.performClose(nil) }
        popover.show(relativeTo: rect, of: view, preferredEdge: edge)
    }

    // MARK: - Deferred close actions

    /// Action to run once the popover finishes its close animation.
    /// Use this instead of `DispatchQueue.main.asyncAfter` so the action fires
    /// at the exact moment the popover delegate confirms it is closed.
    private var pendingCloseAction: (() -> Void)?

    /// Closes the popover and invokes `action` only after the close animation
    /// has fully completed (via `NSPopoverDelegate.popoverDidClose`).
    func closeAndThen(_ action: @escaping () -> Void) {
        pendingCloseAction = action
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Already closed — fire immediately.
            let pending = pendingCloseAction
            pendingCloseAction = nil
            pending?()
        }
    }
}

extension StatusBarController: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover.performClose(nil)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        // Fire any deferred action now that the close animation has finished.
        let pending = pendingCloseAction
        pendingCloseAction = nil
        pending?()
    }
}
