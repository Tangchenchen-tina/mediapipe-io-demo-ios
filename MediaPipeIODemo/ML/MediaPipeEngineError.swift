import Foundation

enum MediaPipeEngineError: LocalizedError {
    case modelNotFound(String)
    /// The input didn't have enough real text to be worth sending to the model — e.g. a PDF page
    /// that's almost entirely blank signature lines. See `TextSanitizer`.
    case inputNotSuitable

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "Model asset \"\(name)\" isn't bundled with the app. Run RunScripts/download_models.sh, then re-add it to the Xcode project if needed."
        case .inputNotSuitable:
            return "This text doesn't have enough real content to work with."
        }
    }
}
