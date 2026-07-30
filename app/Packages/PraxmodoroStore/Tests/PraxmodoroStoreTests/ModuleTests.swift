import Testing
@testable import PraxmodoroStore

@Suite struct ModuleTests {
    @Test func moduleIsPresent() {
        #expect(PraxmodoroStore.moduleName == "PraxmodoroStore")
    }
}
