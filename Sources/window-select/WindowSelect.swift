import Quartz
import Cocoa
import Carbon.HIToolbox

let screenSize = CGDisplayBounds(CGMainDisplayID())
let screenWidth = screenSize.width
let screenHeight = screenSize.height

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {}
}

func cancel() {
  print("canceled")
  exit(1)
}

struct Window {
  var pid = 0
  var ownerName = ""
  var name = ""
  var x = 0
  var y = 0
  var width = 0
  var height = 0
  var number = 0
  var level = 0

  func convertToDictionary() -> [String : Any] {
    return [
      "pid": self.pid,
      "ownerName": self.ownerName,
      "name": self.name,
      "x": self.x,
      "y": self.y,
      "width": self.width,
      "height": self.height,
      "number": self.number
    ]
  }
}

class CoverWindowView: NSView {
  private var windowSelect: WindowSelect?

  convenience init(windowSelect: WindowSelect, frame: CGRect) {
    self.init(frame: frame)
    self.windowSelect = windowSelect
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    if (self.windowSelect != nil) {
      self.windowSelect!.selectWindow()
    }
    return true
  }

  override func mouseUp(with event: NSEvent) {
    if (self.windowSelect != nil) {
      self.windowSelect!.selectWindow()
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

class CoverWindow: NSWindow {
    convenience init(windowSelect: WindowSelect, frame: NSRect) {
        self.init(
            contentRect: frame,
            styleMask: .titled,
            backing: .buffered,
            defer: false
        )

        self.styleMask = .borderless
        self.collectionBehavior = [.stationary, .canJoinAllSpaces, .fullScreenAuxiliary]
        self.level = .screenSaver + 1
        self.orderFrontRegardless()
        self.setFrame(frame, display: true)
        self.backgroundColor = .clear

        let view = CoverWindowView(windowSelect: windowSelect, frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        view.layer = CALayer()
        view.layer?.contentsGravity = .resizeAspectFill;
        view.layer?.contents = NSImage(size: frame.size)
        view.wantsLayer = true
        view.alphaValue = CGFloat(1.0)

        // TODO: Figure out why this is not working
        view.addCursorRect(frame, cursor: NSCursor.pointingHand)
        NSCursor.pointingHand.set()

        self.contentView?.wantsLayer = true
        self.contentView!.addSubview(view)

        self.acceptsMouseMovedEvents = true
        self.ignoresMouseEvents = false

        self.makeFirstResponder(view)
        self.makeKey()
    }

  override var canBecomeKey: Bool {
      return true
  }

  override func keyDown(with event: NSEvent) {
      switch Int(event.keyCode) {
        case kVK_Escape, kVK_Space:
            cancel()
        default:
            break
      }
  }
}

class WindowSelect {
  var overlayWindow: NSWindow
  var windows: [Window] = []
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
      contentRect: NSMakeRect(0, 0, 0, 0),
      styleMask: .titled,
      backing: .buffered,
      defer: false
    )

    window.styleMask = .borderless
    window.collectionBehavior = [.stationary, .canJoinAllSpaces, .fullScreenAuxiliary]

    window.backgroundColor = NSColor(red: 0.647059, green: 0.478431, blue: 1, alpha: 0.2)
    if #available(macOS 10.14, *) {
			window.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2)
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
    NSScreen.screens.forEach { screen in
      CoverWindow(
        windowSelect: self,
        frame: screen.frame
      )
    }
  }

  @objc func computeWindowList() {
    // Alt + Tab event is called slightly before the window order changes
    sleep(for: 0.1)

    self.windows = []
    let options = CGWindowListOption(arrayLiteral: CGWindowListOption.optionOnScreenOnly)
    let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as! NSArray

    for win in windowList {
      let dict = win as! NSDictionary

      // Ignore windows that are not visible
      if ((dict.value(forKey: "kCGWindowAlpha") as! Double) == 0) {
        continue;
      }

      // Ignore windows that belong to this app
      let pid = dict.value(forKey: "kCGWindowOwnerPID") as! Int
      if (pid == NSRunningApplication.current.processIdentifier) {
        continue
      }

      // Ignore passed in apps
      var ownerName = ""
      if (dict.value(forKey: "kCGWindowOwnerName") != nil) {
        ownerName = dict.value(forKey: "kCGWindowOwnerName") as! String
      }


      if (self.appsToIgnore.contains(ownerName)) {
        continue
      }

      let bounds = dict.value(forKey: "kCGWindowBounds") as! NSDictionary

      let x = bounds.value(forKey: "X")! as! Int
      let y = bounds.value(forKey: "Y")! as! Int
      let width = bounds.value(forKey: "Width")! as! Int
      let height = bounds.value(forKey: "Height")! as! Int

      let number = dict.value(forKey: "kCGWindowNumber") as! Int
      let level = dict.value(forKey: "kCGWindowLayer") as! Int

      var name = ""
      if (dict.value(forKey: "kCGWindowName") != nil) {
        name = dict.value(forKey: "kCGWindowName") as! String
      }

      self.windows.append(Window(pid: pid, ownerName: ownerName, name: name, x: x, y: y, width: width, height: height, number: number, level: level))
    }

    drawRectangle()
  }

  func drawRectangle() {
    if let window = self.windows.first(where: { win in
        let y = Int(screenHeight) - win.height - win.y;
        return CGRect(x: win.x, y:y, width: win.width, height: win.height + 1).contains(CGPoint(x: Int(NSEvent.mouseLocation.x), y: Int(NSEvent.mouseLocation.y)))
    }) {
      self.overlayWindow.order(.above, relativeTo: window.number)
      let y = Int(screenHeight) - window.height - window.y;
      self.overlayWindow.setFrame(CGRect(x: window.x, y: y, width: window.width, height: window.height), display: true)
      self.overlayWindow.level = NSWindow.Level(rawValue: window.level)
      self.currentWindow = window
    }
  }

  func selectWindow() {
    if let window = currentWindow {
      do {
        if useJson {
          let jsonData = try JSONSerialization.data(withJSONObject: ["window":window.convertToDictionary()], options: .prettyPrinted)
          let json = String(data: jsonData, encoding: String.Encoding.utf8)
          print(json!)
        } else {
          print("\(window.ownerName) - \(window.name)");
        }
        exit(0)
      } catch {
        exit(1)
      }
    } else {
      exit(1)
    }
  }
}
