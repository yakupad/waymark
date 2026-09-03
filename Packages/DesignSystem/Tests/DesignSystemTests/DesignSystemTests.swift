import Testing
import SwiftUI
@testable import DesignSystem

struct DesignSystemTests {
    @Test func `Spacing scale is monotonic`() {
        #expect(Spacing.xs < Spacing.sm)
        #expect(Spacing.sm < Spacing.md)
        #expect(Spacing.md < Spacing.lg)
        #expect(Spacing.lg < Spacing.xl)
    }

    @Test func `Brand colour is defined`() {
        #expect(Color.brand != Color.clear)
    }
}
