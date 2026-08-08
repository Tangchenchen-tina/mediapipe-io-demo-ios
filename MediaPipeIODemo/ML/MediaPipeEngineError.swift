import Foundation

enum MediaPipeEngineError: LocalizedError {
    case modelNotFound(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "Model asset \"\(name)\" isn't bundled with the app. Run RunScripts/download_models.sh, then re-add it to the Xcode project if needed."
        }
    }
}
