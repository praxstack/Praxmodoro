import Testing

@Suite struct AppSmokeTests {
    @Test func testBundleBuilds() {
        #expect(Bool(true))
    }
}
