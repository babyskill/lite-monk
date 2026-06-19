import XCTest
@testable import agentpet

@MainActor
final class PetControllerTests: XCTestCase {
    func testPetTapShowsReactionAndPulse() {
        let pet = PetController.shared
        let tapCount = pet.petTapCount

        pet.petTap()

        XCTAssertEqual(pet.petTapCount, tapCount + 1)
        XCTAssertTrue(pet.isPetted)
        XCTAssertFalse(pet.petReactionLine.isEmpty)

        let bounceReset = expectation(description: "pet pulse resets after tap")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertFalse(pet.isPetted)
            bounceReset.fulfill()
        }

        let bubbleReset = expectation(description: "pet reaction bubble hides soon after tap")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            XCTAssertTrue(pet.petReactionLine.isEmpty)
            bubbleReset.fulfill()
        }

        wait(for: [bounceReset, bubbleReset], timeout: 3.0)
    }

    func testPetTapSupportsRapidTaps() {
        let pet = PetController.shared
        let first = pet.petTapCount

        pet.petTap()
        pet.petTap()

        XCTAssertEqual(pet.petTapCount, first + 2)
    }
}
