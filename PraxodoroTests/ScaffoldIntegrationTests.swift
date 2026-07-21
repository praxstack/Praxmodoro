import Foundation
import Testing

@testable import Praxodoro

@Test @MainActor
func applicationUsesCoreProductIdentity() {
  #expect(PraxodoroApplication.productName == "Praxodoro")
}

@Test
func testStateRootOverrideIsConsumed() {
  let root = AppPaths.stateRoot(environment: ["PRAXODORO_STATE_ROOT": "/tmp/praxodoro-test"])
  #expect(root.path == "/tmp/praxodoro-test")
}
