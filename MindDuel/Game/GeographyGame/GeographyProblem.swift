import Foundation

struct GeographyProblem {
    let prompt: String
    /// Optional flag glyph rendered above the prompt for "which country has
    /// this flag?" questions (#63). Kept separate so the view can render it
    /// in plain emoji-friendly text rather than embedding it in heavy-weight
    /// text where the emoji can fail to render.
    let flag: String?
    let correctAnswer: String
    let options: [String]

    var correctIndex: Int? {
        options.firstIndex(of: correctAnswer)
    }
}
