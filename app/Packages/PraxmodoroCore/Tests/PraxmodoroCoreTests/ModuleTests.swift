import Testing
@testable import PraxmodoroCore

@Suite struct ModuleTests {
    @Test func moduleIsPresent() {
        #expect(PraxmodoroCore.moduleName == "PraxmodoroCore")
    }
}
