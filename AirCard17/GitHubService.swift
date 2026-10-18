import UIKit

/// Community submission is intentionally disabled in AirCard17.
///
/// The app is a personal Wallet artwork tool and should never upload card
/// images or carry a repository credential. Keeping this small compatibility
/// surface lets the inherited community views compile without transmitting
/// anything from the device.
enum GitHubService {
    struct SubmissionResult {
        let success: Bool
        let message: String
        let issueURL: String?
    }

    static func submitCustomCard(name: String, image: UIImage) async -> SubmissionResult {
        disabledResult
    }

    static func submitDumpedCard(name: String, issuer: String, country: String, image: UIImage) async -> SubmissionResult {
        disabledResult
    }

    private static var disabledResult: SubmissionResult {
        SubmissionResult(
            success: false,
            message: "Community submissions are disabled in AirCard17. Artwork stays on this device.",
            issueURL: nil
        )
    }
}
