import Cocoa
import SwiftCLI

class SelectCommand: Command {
    let name = "select"

    let appsToIgnore = VariadicKey<String>("-i", "--ignore", description: "List of app names to ignore")
    let useJson = Flag("-j", "--json", description: "Use json for the output")

    func execute() throws {
      WindowSelect(
        appsToIgnore: appsToIgnore.value,
        useJson: useJson.value
      )

      NSApp.delegate = AppDelegate()
      NSApp.run()
    }
}

let selectWindow = CLI(name: "select-window")
selectWindow.commands = [SelectCommand()]
selectWindow.go()