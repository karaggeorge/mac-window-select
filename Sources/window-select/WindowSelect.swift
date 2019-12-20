import Quartz
import Cocoa
import Carbon.HIToolbox

let screenSize = CGDisplayBounds(CGMainDisplayID())
let screenWidth = screenSize.width
let screenHeight = screenSize.height

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {}
}

func cancel() {
  print("canceled")
  exit(1)
}

struct Window {
  let pid: Int
  let ownerName: String
  let name: String
  let bounds: CGRect
  let number: Int
  let level: Int

  var dictionary: [String: Any] {
    [
      "pid": pid,
      "ownerName": ownerName,
      "name": name,
      "x": bounds.origin.x,
      "y": bounds.origin.y,
      "width": bounds.size.width,
      "height": bounds.size.height,
      "number": number
    ]
  }
}

final class CoverWindowView: NSView {
  private var windowSelect: WindowSelect?

  convenience init(windowSelect: WindowSelect, frame: CGRect) {
    self.init(frame: frame)
    self.windowSelect = windowSelect
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    if windowSelect != nil {
      windowSelect!.selectWindow()
    }

    return true
  }

  override func mouseUp(with event: NSEvent) {
    if windowSelect != nil {
      windowSelect!.selectWindow()
    }
  }

  override func keyUp(with event: NSEvent) {
    switch Int(event.keyCode) {
      case kVK_Escape, kVK_Space:
          cancel()
      default:
          break
    }
  }
}

final class CoverWindow: NSWindow {
  convenience init(windowSelect: WindowSelect, frame: CGRect) {
    self.init(
        contentRect: frame,
        styleMask: .borderless,
        backing: .buffered,
        defer: false
    )

    self.collectionBehavior = [
      .stationary,
      .canJoinAllSpaces,
      .fullScreenAuxiliary
    ]
    self.level = .screenSaver + 1
    self.orderFrontRegardless()
    self.setFrame(frame, display: true)
    self.backgroundColor = .clear

    let view = CoverWindowView(
      windowSelect: windowSelect,
      frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
    )
    view.layer = CALayer()
    view.layer?.contentsGravity = .resizeAspectFill
    view.layer?.contents = NSImage(size: frame.size)
    view.wantsLayer = true
    view.alphaValue = 1

    // TODO: Figure out why this is not working
    view.addCursorRect(frame, cursor: .pointingHand)
    NSCursor.pointingHand.set()

    self.contentView?.wantsLayer = true
    self.contentView!.addSubview(view)

    self.acceptsMouseMovedEvents = true
    self.ignoresMouseEvents = false

    self.makeFirstResponder(view)
    self.makeKey()
  }

  override var canBecomeKey: Bool { true }

  override func keyDown(with event: NSEvent) {
      switch Int(event.keyCode) {
        case kVK_Escape, kVK_Space:
            cancel()
        default:
            break
      }
  }
}

final class WindowSelect {
  var overlayWindow: NSWindow
  var windows = [Window]()
  var currentWindow: Window?
  var appsToIgnore: [String]
  var useJson: Bool

  init(
    appsToIgnore: [String],
    useJson: Bool
  ) {
    self.appsToIgnore = appsToIgnore
    self.useJson = useJson

    let window = NSWindow(
      contentRect: .zero,
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )

    window.collectionBehavior = [
      .stationary,
      .canJoinAllSpaces,
      .fullScreenAuxiliary
    ]

    if #available(macOS 10.14, *) {
      window.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2)
    } else {
      window.backgroundColor = NSColor(red: 0.647059, green: 0.478431, blue: 1, alpha: 0.2)
    }

    self.overlayWindow = window

    createCoverWindows()
    computeWindowList()

    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(computeWindowList), name: NSWorkspace.didActivateApplicationNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(computeWindowList), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)

    NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { _ in
      self.drawRectangle()
    }
  }

  func createCoverWindows() {
    for screen in NSScreen.screens {
      _ = CoverWindow(
        windowSelect: self,
        frame: screen.frame
      )
    }
  }

  @objc func computeWindowList() {
    // Alt + Tab event is called slightly before the window order changes
    sleep(for: 0.1)

    windows = []

    let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[String: Any]]

    for window in windowList {
      // Ignore windows that are not visible
      if window[kCGWindowAlpha as String] as! Double == 0 {
        continue
      }

      // Ignore windows that belong to this app
      let pid = window[kCGWindowOwnerPID as String] as! Int
      if pid == NSRunningApplication.current.processIdentifier {
        continue
      }

      // Ignore passed in apps
      let ownerName = window[kCGWindowOwnerName as String] as? String ?? ""
      if appsToIgnore.contains(ownerName) {
        continue
      }

      let bounds = CGRect(dictionaryRepresentation: window[kCGWindowBounds as String] as! CFDictionary)!

      let number = window[kCGWindowNumber as String] as! Int
      let level = window[kCGWindowLayer as String] as! Int
      let name = window[kCGWindowName as String] as? String ?? ""

      windows.append(Window(
        pid: pid,
        ownerName: ownerName,
        name: name,
        bounds: bounds,
        number: number,
        level: level
      ))
    }

    drawRectangle()
  }

  func drawRectangle() {
    guard let window = (windows.first {
        CGRect(
          x: $0.bounds.origin.x,
          y: screenHeight - $0.bounds.size.height - $0.bounds.origin.y,
          width: $0.bounds.size.width,
          height: $0.bounds.size.height + 1
        )
          .contains(NSEvent.mouseLocation)
    }) else {
      return
    }

    overlayWindow.order(.above, relativeTo: window.number)

    var windowBounds = window.bounds
    windowBounds.origin.y = screenHeight - windowBounds.size.height - windowBounds.origin.y
    overlayWindow.setFrame(windowBounds, display: true)

    overlayWindow.level = NSWindow.Level(window.level)
    currentWindow = window
  }

  func selectWindow() {
    guard let window = currentWindow else {
      exit(1)
    }

    do {
      if useJson {
        let jsonData = try JSONSerialization.data(
          withJSONObject: ["window": window.dictionary],
          options: .prettyPrinted
        )
        let json = String(data: jsonData, encoding: .utf8)!
        print(json)
      } else {
        print("\(window.ownerName) - \(window.name)")
      }
    } catch {
      exit(1)
    }

    exit(0)
  }
}
