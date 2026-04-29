import Foundation

enum MathProblemGenerator {
    static func generate() -> MathProblem {
        let opIndex = Int.random(in: 0..<4)
        let (display, answer) = makeEquation(opIndex: opIndex)
        return MathProblem(display: display, correctAnswer: answer, options: makeOptions(correct: answer))
    }

    private static func makeEquation(opIndex: Int) -> (String, Int) {
        switch opIndex {
        case 0:
            let a = Int.random(in: 10...99)
            let b = Int.random(in: 10...99)
            return ("\(a) + \(b) = ?", a + b)
        case 1:
            let a = Int.random(in: 20...99)
            let b = Int.random(in: 10...(a - 1))
            return ("\(a) − \(b) = ?", a - b)
        case 2:
            let a = Int.random(in: 2...12)
            let b = Int.random(in: 2...12)
            return ("\(a) × \(b) = ?", a * b)
        default:
            let b = Int.random(in: 2...12)
            let answer = Int.random(in: 2...12)
            let a = b * answer
            return ("\(a) ÷ \(b) = ?", answer)
        }
    }

    private static func makeOptions(correct: Int) -> [Int] {
        var options = Set<Int>([correct])
        let offsets = [-3, -2, -1, 1, 2, 3, 5, 10, -5, -10]
        var shuffled = offsets.shuffled()
        while options.count < 4 {
            let offset = shuffled.isEmpty ? Int.random(in: 1...15) * (Bool.random() ? 1 : -1) : shuffled.removeFirst()
            let candidate = correct + offset
            if candidate > 0 { options.insert(candidate) }
        }
        return Array(options).shuffled()
    }
}
