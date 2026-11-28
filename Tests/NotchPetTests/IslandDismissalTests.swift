import Testing
@testable import NotchPet

struct IslandDismissalTests {
    @Test func aPressOutsideClosesTheOpenIslandOnly() {
        #expect(IslandDismissal.closesOnPress(expanded: true, pressInsideIsland: false))
        #expect(!IslandDismissal.closesOnPress(expanded: true, pressInsideIsland: true))
        #expect(!IslandDismissal.closesOnPress(expanded: false, pressInsideIsland: false))
    }

    /// Keyboard focus without an edited text field, as after Open Sessions, no longer keeps the island open.
    @Test func leavingClosesUnlessATextFieldIsEditedOrTheSettingIsOff() {
        #expect(IslandDismissal.closesOnLeave(expanded: true, pointerInside: false, editingText: false,
                                              collapseOnLeave: true))
        #expect(!IslandDismissal.closesOnLeave(expanded: true, pointerInside: false, editingText: true,
                                               collapseOnLeave: true))
        #expect(!IslandDismissal.closesOnLeave(expanded: true, pointerInside: false, editingText: false,
                                               collapseOnLeave: false))
        #expect(!IslandDismissal.closesOnLeave(expanded: true, pointerInside: true, editingText: false,
                                               collapseOnLeave: true))
        #expect(!IslandDismissal.closesOnLeave(expanded: false, pointerInside: false, editingText: false,
                                               collapseOnLeave: true))
    }
}
