import Foundation
import Testing

@testable import MonkeyCore

@Suite struct StorageLocationPreferenceTests {
  private func makeSuite() -> UserDefaults {
    let suiteName = "StorageLocationPreferenceTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }

  @Test func defaultsToOnDeviceWhenNothingIsSaved() {
    let defaults = makeSuite()

    #expect(StorageLocationPreference.load(defaults: defaults) == .onDevice)
  }

  @Test func roundTripsASavedValue() {
    let defaults = makeSuite()

    StorageLocationPreference.save(.iCloud, defaults: defaults)

    #expect(StorageLocationPreference.load(defaults: defaults) == .iCloud)
  }

  @Test func defaultsToOnDeviceWhenDefaultsIsNil() {
    #expect(StorageLocationPreference.load(defaults: nil) == .onDevice)
  }
}
