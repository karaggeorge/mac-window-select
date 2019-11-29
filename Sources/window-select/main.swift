import Cocoa
import SwiftCLI

final class SelectCommand: Command {
    let name = "select"

    let appsToIgnore = VariadicKey<String>("-i", "--ignore", description: "List of app names to ignore")
    let useJson = Flag("-j", "--json", description: "Use JSON for the output")

    func execute() throws {
      _ = WindowSelect(
        appsToIgnore: appsToIgnore.value,
        useJson: useJson.value
      )

      let delegate = AppDelegate()
      NSApp.delegate = delegate
      NSApp.run()
    }
}

let selectWindow = CLI(name: "select-window")
selectWindow.commands = [SelectCommand()]
_ = selectWindow.go()
