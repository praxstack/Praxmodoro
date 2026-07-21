import Testing

@testable import PraxodoroCore

@Test
func exposesStableProductIdentity() {
  #expect(PraxodoroCore.productName == "Praxodoro")
}
