import Foundation

/// #116: brain-training puzzle generator. Rotates between several puzzle
/// families so a round feels varied rather than "math problems with a
/// different label". All answers are short strings so the existing
/// 4-option AnswerButton grid renders them directly.
enum BrainTrainingProblemGenerator {

    private enum Kind: CaseIterable {
        case arithmeticSequence       // 2, 4, 6, 8, ?
        case geometricSequence        // 2, 4, 8, 16, ?
        case oddOneOut                // 3, 7, 11, 12, 19  → 12 (only even)
        case mentalMath               // 25 % av 80
        case workingMemory            // antall sifre i 4-1-7-2-9
    }

    static func generate(level: Int = 1) -> BrainTrainingProblem {
        let clampedLevel = max(1, min(20, level))
        // Level scales the difficulty band a kind produces, but every kind
        // is reachable at every level so the rotation stays varied.
        let kind = Kind.allCases.randomElement() ?? .arithmeticSequence
        switch kind {
        case .arithmeticSequence: return arithmetic(level: clampedLevel)
        case .geometricSequence:  return geometric(level: clampedLevel)
        case .oddOneOut:          return oddOneOut(level: clampedLevel)
        case .mentalMath:         return mentalMath(level: clampedLevel)
        case .workingMemory:      return workingMemory(level: clampedLevel)
        }
    }

    static func curriculumLabel(forLevel level: Int) -> String {
        let l = max(1, min(20, level))
        if l <= 5      { return String(localized: "brain_training_label_warmup") }
        else if l <= 12 { return String(localized: "brain_training_label_standard") }
        else            { return String(localized: "brain_training_label_advanced") }
    }

    // MARK: – Puzzle kinds

    private static func arithmetic(level: Int) -> BrainTrainingProblem {
        let step = Int.random(in: max(2, level / 2)...max(4, level + 2))
        let start = Int.random(in: 1...10)
        let values = (0...4).map { start + $0 * step }
        let answer = values.last!
        let prompt = (values.dropLast().map(String.init).joined(separator: ", ")) + ", ?"
        return makeMC(prompt: prompt, answer: answer, spread: max(2, step))
    }

    private static func geometric(level: Int) -> BrainTrainingProblem {
        let ratio = Int.random(in: 2...max(2, min(4, 2 + level / 8)))
        let start = Int.random(in: 1...4)
        var values = [start]
        for _ in 0..<4 { values.append(values.last! * ratio) }
        let answer = values.last!
        let prompt = (values.dropLast().map(String.init).joined(separator: ", ")) + ", ?"
        return makeMC(prompt: prompt, answer: answer, spread: max(2, answer / 4))
    }

    private static func oddOneOut(level: Int) -> BrainTrainingProblem {
        // Five numbers, four share a property; pick the odd one.
        let pickEven = Bool.random()
        let upper = 20 + level * 4
        var nums: [Int] = []
        while nums.count < 4 {
            let n = Int.random(in: 2...upper)
            if (pickEven ? n % 2 == 0 : n % 2 != 0), !nums.contains(n) {
                nums.append(n)
            }
        }
        var odd = Int.random(in: 2...upper)
        while (pickEven ? odd % 2 == 0 : odd % 2 != 0) || nums.contains(odd) {
            odd = Int.random(in: 2...upper)
        }
        let insertAt = Int.random(in: 0...nums.count)
        nums.insert(odd, at: insertAt)
        let prompt = String(format: String(localized: "brain_training_odd_one_out_format"),
                            nums.map(String.init).joined(separator: ", "))
        var options = nums.map(String.init)
        options.shuffle()
        return BrainTrainingProblem(prompt: prompt,
                                    correctAnswer: String(odd),
                                    options: Array(options.prefix(4)).contains("\(odd)")
                                        ? Array(options.prefix(4))
                                        : Array(options.prefix(3)) + ["\(odd)"])
    }

    private static func mentalMath(level: Int) -> BrainTrainingProblem {
        // % of N — useful, fast, no calculator allowed.
        let pcts = [10, 20, 25, 50, 75]
        let pct = pcts.randomElement() ?? 25
        let base = (Int.random(in: 4...20)) * 10
        let answer = base * pct / 100
        let prompt = String(format: String(localized: "brain_training_percent_format"),
                            pct, base)
        return makeMC(prompt: prompt, answer: answer, spread: max(3, answer / 3))
    }

    private static func workingMemory(level: Int) -> BrainTrainingProblem {
        // Show a digit string, ask "what was the third digit?" or count.
        let count = min(8, 4 + level / 5)
        var digits: [Int] = []
        while digits.count < count {
            let d = Int.random(in: 0...9)
            digits.append(d)
        }
        let target = Int.random(in: 1...digits.count)
        let answer = digits[target - 1]
        let sequence = digits.map(String.init).joined(separator: "-")
        let prompt = String(format: String(localized: "brain_training_memory_format"),
                            sequence, target)
        var options = Array(Set(digits + [answer])).map(String.init)
        options.shuffle()
        // Ensure the answer is in there.
        var finalOptions = Array(options.prefix(4))
        if !finalOptions.contains(String(answer)) {
            finalOptions[Int.random(in: 0..<finalOptions.count)] = String(answer)
        }
        // Pad to 4 with random digits if needed.
        while finalOptions.count < 4 {
            let d = String(Int.random(in: 0...9))
            if !finalOptions.contains(d) { finalOptions.append(d) }
        }
        finalOptions.shuffle()
        return BrainTrainingProblem(prompt: prompt,
                                    correctAnswer: String(answer),
                                    options: finalOptions)
    }

    // MARK: – Multiple-choice helper

    private static func makeMC(prompt: String, answer: Int, spread: Int) -> BrainTrainingProblem {
        var options = Set<Int>([answer])
        while options.count < 4 {
            let delta = Int.random(in: 1...max(2, spread))
            let sign  = Bool.random() ? 1 : -1
            let candidate = max(0, answer + sign * delta)
            options.insert(candidate)
        }
        var arr = options.map(String.init)
        arr.shuffle()
        return BrainTrainingProblem(prompt: prompt,
                                    correctAnswer: String(answer),
                                    options: arr)
    }
}
