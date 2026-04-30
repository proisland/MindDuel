import Foundation

enum MathProblemGenerator {

    // Level 1–10 per PRD §4.3 / milestones M3
    static func generate(level: Int = 1) -> MathProblem {
        let clamped = max(1, min(10, level))
        let (display, answer) = makeEquation(level: clamped)
        return MathProblem(display: display, correctAnswer: answer, options: makeOptions(correct: answer, level: clamped))
    }

    // MARK: – Equation by level

    private static func makeEquation(level: Int) -> (String, Int) {
        switch level {
        case 1:
            // Simple addition 1–9
            let a = Int.random(in: 1...9), b = Int.random(in: 1...9)
            return ("\(a) + \(b) = ?", a + b)
        case 2:
            // Addition/subtraction 10–30
            let a = Int.random(in: 10...30), b = Int.random(in: 1...a)
            return Bool.random()
                ? ("\(a) + \(b) = ?", a + b)
                : ("\(a) − \(b) = ?", a - b)
        case 3:
            // Addition/subtraction 10–50
            let a = Int.random(in: 10...50), b = Int.random(in: 5...a)
            return Bool.random()
                ? ("\(a) + \(b) = ?", a + b)
                : ("\(a) − \(b) = ?", a - b)
        case 4:
            // Addition/subtraction 10–99
            let a = Int.random(in: 20...99), b = Int.random(in: 10...a)
            return Bool.random()
                ? ("\(a) + \(b) = ?", a + b)
                : ("\(a) − \(b) = ?", a - b)
        case 5:
            // Multiplication tables 2–6
            let a = Int.random(in: 2...6), b = Int.random(in: 2...6)
            return ("\(a) × \(b) = ?", a * b)
        case 6:
            // Multiplication/division 2–12
            if Bool.random() {
                let a = Int.random(in: 2...12), b = Int.random(in: 2...12)
                return ("\(a) × \(b) = ?", a * b)
            } else {
                let b = Int.random(in: 2...12), ans = Int.random(in: 2...12)
                return ("\(b * ans) ÷ \(b) = ?", ans)
            }
        case 7:
            // All four ops, moderate numbers
            let op = Int.random(in: 0...3)
            switch op {
            case 0:
                let a = Int.random(in: 20...99), b = Int.random(in: 10...50)
                return ("\(a) + \(b) = ?", a + b)
            case 1:
                let a = Int.random(in: 30...99), b = Int.random(in: 10...a)
                return ("\(a) − \(b) = ?", a - b)
            case 2:
                let a = Int.random(in: 2...15), b = Int.random(in: 2...15)
                return ("\(a) × \(b) = ?", a * b)
            default:
                let b = Int.random(in: 2...15), ans = Int.random(in: 2...15)
                return ("\(b * ans) ÷ \(b) = ?", ans)
            }
        case 8:
            // Mixed, larger numbers + simple percentages as integer (e.g. 50% of 60)
            let op = Int.random(in: 0...3)
            switch op {
            case 0:
                let a = Int.random(in: 50...200), b = Int.random(in: 10...99)
                return ("\(a) + \(b) = ?", a + b)
            case 1:
                let a = Int.random(in: 50...200), b = Int.random(in: 10...a)
                return ("\(a) − \(b) = ?", a - b)
            case 2:
                let a = Int.random(in: 5...20), b = Int.random(in: 5...20)
                return ("\(a) × \(b) = ?", a * b)
            default:
                let b = Int.random(in: 2...20), ans = Int.random(in: 2...20)
                return ("\(b * ans) ÷ \(b) = ?", ans)
            }
        case 9:
            // Two-digit × single-digit, multi-step subtraction
            let op = Int.random(in: 0...2)
            switch op {
            case 0:
                let a = Int.random(in: 11...25), b = Int.random(in: 2...9)
                return ("\(a) × \(b) = ?", a * b)
            case 1:
                let a = Int.random(in: 100...500), b = Int.random(in: 50...a)
                return ("\(a) − \(b) = ?", a - b)
            default:
                let b = Int.random(in: 2...25), ans = Int.random(in: 2...25)
                return ("\(b * ans) ÷ \(b) = ?", ans)
            }
        default: // Level 10
            // Two-digit × two-digit, squares
            if Bool.random() {
                let a = Int.random(in: 11...25), b = Int.random(in: 11...25)
                return ("\(a) × \(b) = ?", a * b)
            } else {
                let a = Int.random(in: 5...15)
                return ("\(a)² = ?", a * a)
            }
        }
    }

    // MARK: – Plausible distractors

    private static func makeOptions(correct: Int, level: Int) -> [Int] {
        var options = Set<Int>([correct])
        let spread  = max(2, correct / 5)
        let pool: [Int] = [-spread * 3, -spread * 2, -spread, spread, spread * 2, spread * 3,
                           -1, 1, -2, 2, -5, 5, -10, 10]
        var shuffled = pool.shuffled()
        while options.count < 4 {
            let offset = shuffled.isEmpty
                ? Int.random(in: 1...spread) * (Bool.random() ? 1 : -1)
                : shuffled.removeFirst()
            let candidate = correct + offset
            if candidate > 0, candidate != correct { options.insert(candidate) }
        }
        return Array(options).shuffled()
    }
}
