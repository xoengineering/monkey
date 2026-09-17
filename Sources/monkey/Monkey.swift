import ArgumentParser

@main
struct Monkey: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "monkey",
    abstract: "A local, on-device chat client for Apple's Foundation Models.",
    subcommands: [
      ListCommand.self,
      DoCommand.self,
      ChatCommand.self,
      CatCommand.self,
      OpenCommand.self,
      SearchCommand.self,
    ]
  )
}
