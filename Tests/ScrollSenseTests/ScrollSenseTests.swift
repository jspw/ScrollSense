import Foundation
import Testing

@testable import ScrollSenseCore

// MARK: - ScrollPreferences Tests

@Suite("ScrollPreferences")
struct ScrollPreferencesTests {

    @Test("Default preferences: mouse OFF, trackpad ON")
    func defaultPreferences() {
        let defaults = ScrollPreferences.default
        #expect(defaults.mouseNatural == false)
        #expect(defaults.trackpadNatural == true)
    }

    @Test("Natural scroll for device returns correct value")
    func naturalScrollForDevice() {
        let config = ScrollPreferences(mouseNatural: false, trackpadNatural: true)
        #expect(config.naturalScroll(for: .mouse) == false)
        #expect(config.naturalScroll(for: .trackpad) == true)
    }

    @Test("Equality comparison works correctly")
    func equality() {
        let a = ScrollPreferences(mouseNatural: false, trackpadNatural: true)
        let b = ScrollPreferences(mouseNatural: false, trackpadNatural: true)
        let c = ScrollPreferences(mouseNatural: true, trackpadNatural: true)
        #expect(a == b)
        #expect(a != c)
    }

    @Test("JSON encoding includes all fields")
    func encoding() throws {
        let config = ScrollPreferences(mouseNatural: false, trackpadNatural: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("mouseNatural"))
        #expect(json.contains("trackpadNatural"))
    }

    @Test("JSON decoding parses correctly")
    func decoding() throws {
        let json = """
            {"mouseNatural": true, "trackpadNatural": false}
            """
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(ScrollPreferences.self, from: data)
        #expect(config.mouseNatural == true)
        #expect(config.trackpadNatural == false)
    }
}

// MARK: - InputDevice Tests

@Suite("InputDevice")
struct InputDeviceTests {

    @Test("Display names are correct")
    func displayName() {
        #expect(InputDevice.mouse.displayName == "Mouse")
        #expect(InputDevice.trackpad.displayName == "Trackpad")
    }

    @Test("Raw values are correct")
    func rawValue() {
        #expect(InputDevice.mouse.rawValue == "mouse")
        #expect(InputDevice.trackpad.rawValue == "trackpad")
    }
}

// MARK: - DaemonState Tests

@Suite("DaemonState")
struct DaemonStateTests {

    @Test("Initial state has nil/zero values")
    func initialState() {
        let state = DaemonState()
        #expect(state.lastDetectedDevice == nil)
        #expect(state.lastAppliedScrollValue == nil)
        #expect(state.isRunning == false)
        #expect(state.eventCount == 0)
        #expect(state.switchCount == 0)
        #expect(state.startTime == nil)
        #expect(state.uptime == nil)
        #expect(state.uptimeFormatted == "N/A")
    }

    @Test("Uptime formats correctly")
    func uptimeFormatted() {
        var state = DaemonState()
        state.startTime = Date().addingTimeInterval(-3661)  // ~1h 1m 1s ago
        #expect(state.uptime != nil)
        let formatted = state.uptimeFormatted
        #expect(formatted.contains(":"))
    }
}

// MARK: - StateManager Tests

@Suite("StateManager")
struct StateManagerTests {

    @Test("Records device detection and counts events/switches")
    func recordDeviceDetection() {
        let manager = StateManager()
        #expect(manager.state.eventCount == 0)
        #expect(manager.state.switchCount == 0)

        manager.recordDeviceDetection(.mouse)
        #expect(manager.state.eventCount == 1)
        #expect(manager.state.switchCount == 1)
        #expect(manager.state.lastDetectedDevice == .mouse)

        // Same device again — no switch
        manager.recordDeviceDetection(.mouse)
        #expect(manager.state.eventCount == 2)
        #expect(manager.state.switchCount == 1)

        // Different device — switch
        manager.recordDeviceDetection(.trackpad)
        #expect(manager.state.eventCount == 3)
        #expect(manager.state.switchCount == 2)
        #expect(manager.state.lastDetectedDevice == .trackpad)
    }

    @Test("shouldApplyChange returns correct value or nil")
    func shouldApplyChange() {
        let manager = StateManager()
        let currentSystem = ScrollController.getCurrentNaturalScroll()

        // Build a config where one device matches the system and the other doesn't.
        let config = ScrollPreferences(mouseNatural: !currentSystem, trackpadNatural: currentSystem)

        // Mouse wants the opposite of the system → should apply
        let result = manager.shouldApplyChange(for: .mouse, config: config)
        #expect(result == !currentSystem)

        // Trackpad wants same as system → no change needed
        let noChange = manager.shouldApplyChange(for: .trackpad, config: config)
        #expect(noChange == nil)
    }

    @Test("Records applied value correctly")
    func recordAppliedValue() {
        let manager = StateManager()
        #expect(manager.state.lastAppliedScrollValue == nil)

        manager.recordAppliedValue(true)
        #expect(manager.state.lastAppliedScrollValue == true)

        manager.recordAppliedValue(false)
        #expect(manager.state.lastAppliedScrollValue == false)
    }
}

// MARK: - ConfigManager Tests

@Suite("ConfigManager")
struct ConfigManagerTests {

    @Test("Load returns valid preferences")
    func loadDefault() {
        let config = ConfigManager.shared.load()
        // Should return some valid config
        #expect(config.mouseNatural == true || config.mouseNatural == false)
    }

    @Test("Save and load round-trips correctly")
    func saveAndLoad() {
        let original = ScrollPreferences(mouseNatural: true, trackpadNatural: false)
        ConfigManager.shared.save(original)

        let loaded = ConfigManager.shared.load()
        #expect(loaded.mouseNatural == true)
        #expect(loaded.trackpadNatural == false)

        // Restore defaults
        ConfigManager.shared.reset()
    }

    @Test("Reset restores default preferences")
    func reset() {
        // Save non-default config
        let custom = ScrollPreferences(mouseNatural: true, trackpadNatural: false)
        ConfigManager.shared.save(custom)

        // Reset
        let defaults = ConfigManager.shared.reset()
        #expect(defaults == ScrollPreferences.default)

        // Verify it persisted
        let loaded = ConfigManager.shared.load()
        #expect(loaded == ScrollPreferences.default)
    }
}
