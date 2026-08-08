import XCTest

final class VectorIndexTests: XCTestCase {
    private let tolerance: Float = 1e-5

    func testIdenticalVectorsHaveSimilarityOne() {
        let v: [Float] = [1, 2, 3]
        XCTAssertEqual(cosineSimilarity(v, v), 1, accuracy: tolerance)
    }

    func testOppositeVectorsHaveSimilarityNegativeOne() {
        let a: [Float] = [1, 0, 0]
        let b: [Float] = [-1, 0, 0]
        XCTAssertEqual(cosineSimilarity(a, b), -1, accuracy: tolerance)
    }

    func testOrthogonalVectorsHaveSimilarityZero() {
        let a: [Float] = [1, 0]
        let b: [Float] = [0, 1]
        XCTAssertEqual(cosineSimilarity(a, b), 0, accuracy: tolerance)
    }

    func testScaleInvariantParallelVectorsOfDifferentMagnitudeStillMatch() {
        let a: [Float] = [1, 2, 3]
        let b: [Float] = [10, 20, 30]
        XCTAssertEqual(cosineSimilarity(a, b), 1, accuracy: tolerance)
    }

    func testZeroVectorReturnsZeroInsteadOfNaN() {
        // A real embedder should never emit an all-zero vector, but a divide-by-zero here would
        // silently corrupt every ranked search result with a NaN, so this is worth pinning down.
        let zero: [Float] = [0, 0, 0]
        let other: [Float] = [1, 1, 1]
        XCTAssertEqual(cosineSimilarity(zero, other), 0, accuracy: tolerance)
        XCTAssertEqual(cosineSimilarity(zero, zero), 0, accuracy: tolerance)
    }
}
