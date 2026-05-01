import Foundation

enum MathProblemGenerator {
    // level 1-3: addition/subtraction with small numbers
    // level 4-6: medium numbers, multiplication introduced
    // level 7-10: all operations, larger numbers (two-digit)
    static func generate(level: Int = 1) -> MathProblem {
        let l = max(1, min(10, level))
        let (display, answer) = makeEquation(level: l)
        return MathProblem(display: display, correctAnswer: answer, options: makeOptions(correct: answer))
    }

    private static func makeEquation(level: Int) -> (String, Int) {
        let canMultiply = level >= 4
        let canDivide   = level >= 7

        let opCount = canDivide ? 4 : canMultiply ? 3 : 2
        let opIndex = Int.random(in: 0..<opCount)

        switch opIndex {
        case 0: // addition
            let (a, b) = additionOperands(level: level)
            return ("\(a) + \(b) = ?", a + b)
        case 1: // subtraction
            let (a, b) = subtractionOperands(level: level)
            return ("\(a) − \(b) = ?", a - b)
        case 2: // multiplication
            let a = Int.random(in: 2...multiMax(level))
            let b = Int.random(in: 2...multiMax(level))
            return ("\(a) × \(b) = ?", a * b)
        default: // division
            let divisor = Int.random(in: 2...12)
            let answer  = Int.random(in: 2...12)
            return ("\(divisor * answer) ÷ \(divisor) = ?", answer)
        }
    }

    private static func additionOperands(level: Int) -> (Int, Int) {
        switch level {
        case 1:  return (Int.random(in: 1...9),  Int.random(in: 1...9))
        case 2:  return (Int.random(in: 1...15), Int.random(in: 1...10))
        case 3:  return (Int.random(in: 5...25), Int.random(in: 5...20))
        case 4:  return (Int.random(in: 10...40), Int.random(in: 5...25))
        case 5:  return (Int.random(in: 10...50), Int.random(in: 10...30))
        default: return (Int.random(in: 10...99), Int.random(in: 10...99))
        }
    }

    private static func subtractionOperands(level: Int) -> (Int, Int) {
        switch level {
        case 1:  let a = Int.random(in: 2...18);  return (a, Int.random(in: 1...(a - 1)))
        case 2:  let a = Int.random(in: 5...25);  return (a, Int.random(in: 1...(a - 1)))
        case 3:  let a = Int.random(in: 10...35); return (a, Int.random(in: 5...(a - 1)))
        case 4:  let a = Int.random(in: 15...50); return (a, Int.random(in: 5...(a - 1)))
        case 5:  let a = Int.random(in: 20...65); return (a, Int.random(in: 10...(a - 1)))
        default: let a = Int.random(in: 20...99); return (a, Int.random(in: 10...(a - 1)))
        }
    }

    private static func multiMax(_ level: Int) -> Int {
        switch level {
        case 4:  return 6
        case 5:  return 9
        case 6:  return 10
        default: return 12
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
