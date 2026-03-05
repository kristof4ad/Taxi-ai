import Testing

@testable import Taxi_ai

@MainActor
struct RidePhaseTests {
    // MARK: - Cancel Label

    @Test func cancelLabelIsEmptyForNone() {
        #expect(RidePhase.none.cancelLabel == "")
    }

    @Test func cancelLabelForOrdering() {
        #expect(RidePhase.ordering.cancelLabel == "Cancel this ride")
    }

    @Test func cancelLabelForRiding() {
        #expect(RidePhase.riding.cancelLabel == "Cancel this ride")
    }

    // MARK: - Cancel Message

    @Test func cancelMessageIsEmptyForNone() {
        #expect(RidePhase.none.cancelMessage == "")
    }

    @Test func cancelMessageForOrdering() {
        #expect(RidePhase.ordering.cancelMessage == "You won't be charged if you cancel now.")
    }

    @Test func cancelMessageForRiding() {
        #expect(RidePhase.riding.cancelMessage == "You will be charged for this ride.")
    }

    // MARK: - Distinct Messages

    @Test func orderingAndRidingHaveDifferentMessages() {
        #expect(RidePhase.ordering.cancelMessage != RidePhase.riding.cancelMessage)
    }

    @Test func orderingAndRidingHaveSameCancelLabel() {
        #expect(RidePhase.ordering.cancelLabel == RidePhase.riding.cancelLabel)
    }
}
