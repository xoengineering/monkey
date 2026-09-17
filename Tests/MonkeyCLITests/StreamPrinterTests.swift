import Foundation
import Testing

@testable import monkey

@Suite struct StreamPrinterTests {
  @Test func printsOnlyTheAppendedSuffixOnEachCall() {
    let written = LockedArray<String>()
    let printer = StreamPrinter { written.append($0) }

    printer.printDelta(of: "Hello")
    printer.printDelta(of: "Hello, world")
    printer.printDelta(of: "Hello, world!")

    #expect(written.values == ["Hello", ", world", "!"])
  }

  @Test func ignoresUpdatesThatDoNotGrowTheBody() {
    let written = LockedArray<String>()
    let printer = StreamPrinter { written.append($0) }

    printer.printDelta(of: "Hello")
    printer.printDelta(of: "Hello")
    printer.printDelta(of: "Hi")

    #expect(written.values == ["Hello"])
  }
}
