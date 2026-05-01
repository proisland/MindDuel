import Foundation

/// Generates math problems whose difficulty is aligned with the Norwegian
/// school curriculum (issue #27):
///   • Levels 1–10  → grunnskolen (1.–10. klasse)
///   • Levels 11–13 → videregående skole (1VGS – 3VGS, R1/R2)
///   • Levels 14–20 → universitetsmatte (innføring → forskning)
///
/// All answers are integers so the existing 4-option multiple-choice UI keeps
/// working. Where a topic naturally produces a non-integer (e.g. an integral),
/// coefficients are picked so the result is whole.
enum MathProblemGenerator {

    static func generate(level: Int = 1) -> MathProblem {
        let clamped = max(1, min(20, level))
        let (display, answer) = makeEquation(level: clamped)
        return MathProblem(display: display, correctAnswer: answer, options: makeOptions(correct: answer, level: clamped))
    }

    /// Localized curriculum label for a level (e.g. "1. klasse", "VGS 2",
    /// "Universitet (nivå 3)"). Useful for showing context next to the level
    /// number in the UI so the player knows what grade they're at.
    static func curriculumLabel(forLevel level: Int) -> String {
        let l = max(1, min(20, level))
        if l <= 10 {
            return String(format: String(localized: "curriculum_grade_format"), l)
        } else if l <= 13 {
            return String(format: String(localized: "curriculum_vgs_format"), l - 10)
        } else {
            return String(format: String(localized: "curriculum_university_format"), l - 13)
        }
    }

    // MARK: – Equation by level

    private static func makeEquation(level: Int) -> (String, Int) {
        switch level {

        // MARK: Grunnskolen (1.–10. klasse)

        case 1: // 1. klasse: addisjon/subtraksjon innen 10
            let a = Int.random(in: 1...9)
            let b = Int.random(in: 1...(10 - a))
            return Bool.random()
                ? ("\(a) + \(b) = ?", a + b)
                : ("\(a + b) − \(b) = ?", a)

        case 2: // 2. klasse: +/- innen 20, gangetabell 2 og 5
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                let a = Int.random(in: 5...15), b = Int.random(in: 1...(20 - a))
                return ("\(a) + \(b) = ?", a + b)
            case 1:
                let a = Int.random(in: 5...20), b = Int.random(in: 1...a)
                return ("\(a) − \(b) = ?", a - b)
            default:
                let a = [2, 5].randomElement()!, b = Int.random(in: 1...10)
                return ("\(a) × \(b) = ?", a * b)
            }

        case 3: // 3. klasse: +/- innen 100, gangetabell 1–5
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                let a = Int.random(in: 10...60), b = Int.random(in: 5...40)
                return Bool.random()
                    ? ("\(a) + \(b) = ?", a + b)
                    : ("\(a + b) − \(b) = ?", a)
            case 1:
                let a = Int.random(in: 2...5), b = Int.random(in: 2...10)
                return ("\(a) × \(b) = ?", a * b)
            default:
                let b = Int.random(in: 2...5), ans = Int.random(in: 2...10)
                return ("\(b * ans) ÷ \(b) = ?", ans)
            }

        case 4: // 4. klasse: gangetabell 1–10, divisjon, halv/firedel av tall
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                let a = Int.random(in: 2...10), b = Int.random(in: 2...10)
                return ("\(a) × \(b) = ?", a * b)
            case 1:
                let b = Int.random(in: 2...10), ans = Int.random(in: 2...12)
                return ("\(b * ans) ÷ \(b) = ?", ans)
            default:
                // 1/2, 1/4 eller 1/5 av et heltall som gir heltall
                let denom = [2, 4, 5].randomElement()!
                let ans = Int.random(in: 2...12)
                return ("(1/\(denom)) × \(denom * ans) = ?", ans)
            }

        case 5: // 5. klasse: divisjon, prosent av runde tall
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                let a = Int.random(in: 6...12), b = Int.random(in: 6...12)
                return ("\(a) × \(b) = ?", a * b)
            case 1:
                let percent = [10, 25, 50, 75].randomElement()!
                let base = [100, 200, 400, 80, 60, 40].randomElement()!
                let ans = base * percent / 100
                if ans * 100 == base * percent {
                    return ("\(percent)% av \(base) = ?", ans)
                }
                return ("\(percent)% av 100 = ?", percent)
            default:
                let b = Int.random(in: 3...12), ans = Int.random(in: 5...20)
                return ("\(b * ans) ÷ \(b) = ?", ans)
            }

        case 6: // 6. klasse: brøk × heltall, prosent, areal
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                // a/b × c der b deler c
                let b = [2, 3, 4, 5].randomElement()!
                let a = Int.random(in: 1...(b - 1))
                let multiple = Int.random(in: 2...8)
                let c = b * multiple
                return ("(\(a)/\(b)) × \(c) = ?", a * multiple)
            case 1:
                // Areal av rektangel
                let w = Int.random(in: 4...20), h = Int.random(in: 3...15)
                return ("Areal: \(w) × \(h) = ?", w * h)
            default:
                let percent = [10, 20, 25, 50].randomElement()!
                let base = Int.random(in: 1...20) * (100 / percent)
                return ("\(percent)% av \(base) = ?", base * percent / 100)
            }

        case 7: // 7. klasse: negative tall, enkle likninger, potens av 2
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                let a = Int.random(in: -15 ... -1), b = Int.random(in: 1...20)
                return ("\(a) + \(b) = ?", a + b)
            case 1:
                // x + a = b
                let a = Int.random(in: 2...20), x = Int.random(in: 1...20)
                return ("x + \(a) = \(x + a),  x = ?", x)
            default:
                let n = Int.random(in: 2...6)
                return ("2^\(n) = ?", Int(pow(2.0, Double(n))))
            }

        case 8: // 8. klasse: ax+b=c, kvadratrøtter, Pythagoras
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                // ax + b = c
                let a = Int.random(in: 2...6), x = Int.random(in: 2...12)
                let b = Int.random(in: 1...20), c = a * x + b
                return ("\(a)x + \(b) = \(c),  x = ?", x)
            case 1:
                // sqrt of perfect square
                let n = Int.random(in: 4...15)
                return ("√\(n * n) = ?", n)
            default:
                // Pythagoras med integer triple
                let triples = [(3,4,5),(5,12,13),(6,8,10),(7,24,25),(8,15,17),(9,12,15)]
                let (a, b, c) = triples.randomElement()!
                let which = Int.random(in: 0...2)
                if which == 0 { return ("Hypotenus: a=\(a), b=\(b)", c) }
                if which == 1 { return ("Katet: c=\(c), b=\(b)", a) }
                return ("Katet: c=\(c), a=\(a)", b)
            }

        case 9: // 9. klasse: distributiv, GCD, lineær med flere ledd
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                // a(b + c)
                let a = Int.random(in: 2...9), b = Int.random(in: 2...12), c = Int.random(in: 2...12)
                return ("\(a) × (\(b) + \(c)) = ?", a * (b + c))
            case 1:
                // SFF / GCD av to tall
                let pairs = [(12, 18), (15, 25), (24, 36), (14, 21), (8, 12), (20, 30), (45, 60), (16, 24)]
                let (a, b) = pairs.randomElement()!
                return ("SFF(\(a), \(b)) = ?", gcd(a, b))
            default:
                // Lineær: ax + b = cx + d
                let a = Int.random(in: 3...8), c = Int.random(in: 1...(a - 1))
                let x = Int.random(in: 2...10), d = Int.random(in: 1...20)
                let b = (c - a) * x + d  // ensures ax + b = cx + d at integer x
                let lhs = "\(a)x + \(b)", rhs = "\(c)x + \(d)"
                return ("\(lhs) = \(rhs),  x = ?", x)
            }

        case 10: // 10. klasse: andregradsrøtter, system av likninger
            let pick = Int.random(in: 0...1)
            switch pick {
            case 0:
                // x² = N  → finn positive x
                let x = Int.random(in: 5...15)
                return ("x² = \(x * x),  x>0 = ?", x)
            default:
                // x + y = s, x - y = d  → x = (s+d)/2
                let x = Int.random(in: 5...15), y = Int.random(in: 1...(x - 1))
                let s = x + y, d = x - y
                return ("x+y=\(s), x−y=\(d),  x=?", x)
            }

        // MARK: Videregående (11–13)

        case 11: // 1VGS / 1T-1P: funksjonsverdier, stigningstall
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                // f(x) = ax + b
                let a = Int.random(in: 2...8), b = Int.random(in: 1...10)
                let x = Int.random(in: 2...8)
                return ("f(x)=\(a)x+\(b),  f(\(x))=?", a * x + b)
            case 1:
                // f(x) = ax² + b
                let a = Int.random(in: 1...3), b = Int.random(in: 0...10)
                let x = Int.random(in: 2...6)
                return ("f(x)=\(a)x²+\(b),  f(\(x))=?", a * x * x + b)
            default:
                // Stigningstall
                let m = Int.random(in: 2...6)
                let x1 = Int.random(in: 0...3), y1 = Int.random(in: 0...10)
                let dx = Int.random(in: 2...5)
                let x2 = x1 + dx, y2 = y1 + m * dx
                return ("Stigning (\(x1),\(y1))→(\(x2),\(y2))", m)
            }

        case 12: // 2VGS / R1: derivasjon polynom, vektor prikkprodukt
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                // d/dx (ax² + bx + c) at integer x  → 2ax + b
                let a = Int.random(in: 1...4), b = Int.random(in: 1...10)
                let x = Int.random(in: 2...8)
                return ("f(x)=\(a)x²+\(b)x,  f'(\(x))=?", 2 * a * x + b)
            case 1:
                // d/dx (ax³) at integer x  → 3ax²
                let a = Int.random(in: 1...3), x = Int.random(in: 2...5)
                return ("f(x)=\(a)x³,  f'(\(x))=?", 3 * a * x * x)
            default:
                // Prikkprodukt 2D
                let ax = Int.random(in: 1...8), ay = Int.random(in: 1...8)
                let bx = Int.random(in: 1...8), by = Int.random(in: 1...8)
                return ("(\(ax),\(ay))·(\(bx),\(by))=?", ax * bx + ay * by)
            }

        case 13: // 3VGS / R2: bestemt integral, summer
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                // ∫₀ᵇ ax dx = a·b²/2  — velg a, b så svaret er heltall
                let b = Int.random(in: 2...6) * 2  // partall
                let a = Int.random(in: 1...4)
                return ("∫₀\(b) \(a)x dx = ?", a * b * b / 2)
            case 1:
                // ∫₀ᵇ 3x² dx = b³
                let b = Int.random(in: 2...5)
                return ("∫₀\(b) 3x² dx = ?", b * b * b)
            default:
                // Σ(k=1..n) k = n(n+1)/2  — velg partall n eller partall (n+1)
                let n = [4, 6, 8, 10, 12, 14, 20].randomElement()!
                return ("Σ k=1..\(n) k = ?", n * (n + 1) / 2)
            }

        // MARK: Universitet (14–20)

        case 14: // Univ. innføring: grenser, fakultet
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                // lim(x→a) (x²-a²)/(x-a) = 2a
                let a = Int.random(in: 2...10)
                return ("lim(x→\(a)) (x²−\(a*a))/(x−\(a))", 2 * a)
            case 1:
                // n!
                let n = Int.random(in: 4...7)
                return ("\(n)! = ?", factorial(n))
            default:
                // d²/dx² (x³) at integer x = 6x
                let x = Int.random(in: 2...8)
                return ("f(x)=x³,  f''(\(x))=?", 6 * x)
            }

        case 15: // Univ. grunnleggende: modulær aritmetikk, binomkoeffisient, det 2x2
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                let a = Int.random(in: 50...500), m = Int.random(in: 3...12)
                return ("\(a) mod \(m) = ?", a % m)
            case 1:
                // C(n,k) små
                let pairs = [(5,2),(6,2),(6,3),(7,2),(7,3),(8,2),(8,3),(8,4),(9,3),(10,2),(10,3)]
                let (n, k) = pairs.randomElement()!
                return ("C(\(n),\(k)) = ?", binomial(n, k))
            default:
                // det 2x2
                let a = Int.random(in: 2...9), b = Int.random(in: 1...8)
                let c = Int.random(in: 1...8), d = Int.random(in: 2...9)
                return ("det[[\(a),\(b)],[\(c),\(d)]]=?", a * d - b * c)
            }

        case 16: // Univ. mellom: Fibonacci, kjederegel, lineær algebra
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                // F(n) — Fibonacci-tall, n ≤ 15
                let n = Int.random(in: 8...15)
                return ("F(\(n)) = ?", fibonacci(n))
            case 1:
                // d/dx (sin replaced by polynom shortcut): d/dx[(ax+b)²] at x = 2a(ax+b)
                let a = Int.random(in: 2...5), b = Int.random(in: 1...8), x = Int.random(in: 2...5)
                return ("g(x)=(\(a)x+\(b))²,  g'(\(x))=?", 2 * a * (a * x + b))
            default:
                // Spor av matrise (sum av diagonal) 3x3 — bare gi diagonal verdiene
                let d1 = Int.random(in: 1...20), d2 = Int.random(in: 1...20), d3 = Int.random(in: 1...20)
                return ("tr(diag(\(d1),\(d2),\(d3)))=?", d1 + d2 + d3)
            }

        case 17: // Univ. høy: kombinatorikk, integraler, store summer
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                // Permutasjoner P(n,k) = n!/(n-k)!
                let pairs = [(5,2),(6,2),(6,3),(7,2),(7,3),(8,3),(9,3)]
                let (n, k) = pairs.randomElement()!
                return ("P(\(n),\(k)) = ?", permutation(n, k))
            case 1:
                // ∫₁ᵇ 1/x dx → bytt til ∫₁ᵇ a dx = a(b-1) for heltallssvar
                let a = Int.random(in: 2...6), b = Int.random(in: 4...10)
                return ("∫₁\(b) \(a) dx = ?", a * (b - 1))
            default:
                // Σ(k=1..n) k² = n(n+1)(2n+1)/6
                let n = [3, 5, 6, 7, 8, 10].randomElement()!
                return ("Σ k=1..\(n) k² = ?", n * (n + 1) * (2 * n + 1) / 6)
            }

        case 18: // Univ. avansert: vektorer 3D, sammensatte
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                // 3D prikkprodukt
                let a = (Int.random(in: 1...6), Int.random(in: 1...6), Int.random(in: 1...6))
                let b = (Int.random(in: 1...6), Int.random(in: 1...6), Int.random(in: 1...6))
                return ("(\(a.0),\(a.1),\(a.2))·(\(b.0),\(b.1),\(b.2))",
                        a.0 * b.0 + a.1 * b.1 + a.2 * b.2)
            case 1:
                // |v|² i 3D
                let x = Int.random(in: 1...8), y = Int.random(in: 1...8), z = Int.random(in: 1...8)
                return ("|(\(x),\(y),\(z))|² = ?", x * x + y * y + z * z)
            default:
                // Σ(k=1..n) k³ = (n(n+1)/2)²
                let n = [3, 4, 5, 6, 7, 8].randomElement()!
                let s = n * (n + 1) / 2
                return ("Σ k=1..\(n) k³ = ?", s * s)
            }

        case 19: // Univ. master: tallteori, store kombinatoriske
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                // φ(n) — Euler's totient for små n
                let n = [12, 15, 16, 18, 20, 24, 30].randomElement()!
                return ("φ(\(n)) = ?", eulerPhi(n))
            case 1:
                // Større fakultet n!
                let n = Int.random(in: 7...9)
                return ("\(n)! = ?", factorial(n))
            default:
                // Modulær potens: a^b mod m  (små verdier)
                let a = Int.random(in: 2...9), b = Int.random(in: 3...8), m = Int.random(in: 5...20)
                let val = modPow(a, b, m)
                return ("\(a)^\(b) mod \(m) = ?", val)
            }

        case 20: // Univ. forskning: hardeste — store binom, store summer, modular
            fallthrough
        default:
            let pick = Int.random(in: 0...2)
            switch pick {
            case 0:
                // C(n,k) større
                let pairs = [(12,3),(12,4),(15,3),(15,4),(20,2),(20,3)]
                let (n, k) = pairs.randomElement()!
                return ("C(\(n),\(k)) = ?", binomial(n, k))
            case 1:
                // Σ(k=1..n) (2k-1) = n²
                let n = Int.random(in: 8...20)
                return ("Σ k=1..\(n) (2k−1) = ?", n * n)
            default:
                // a^b mod m med litt større tall
                let a = Int.random(in: 3...12), b = Int.random(in: 5...10), m = Int.random(in: 7...25)
                return ("\(a)^\(b) mod \(m) = ?", modPow(a, b, m))
            }
        }
    }

    // MARK: – Plausible distractors
    //
    // Allows negative correct answers (needed from level 7 onward) and treats
    // 0 as a valid distractor; only blocks the exact correct value.
    private static func makeOptions(correct: Int, level: Int) -> [Int] {
        var options = Set<Int>([correct])
        let absCorrect = abs(correct)
        let spread = max(2, absCorrect / 5)
        let pool: [Int] = [-spread * 3, -spread * 2, -spread, spread, spread * 2, spread * 3,
                           -1, 1, -2, 2, -5, 5, -10, 10]
        var shuffled = pool.shuffled()
        var safety = 50
        while options.count < 4 && safety > 0 {
            let offset = shuffled.isEmpty
                ? Int.random(in: 1...max(2, spread)) * (Bool.random() ? 1 : -1)
                : shuffled.removeFirst()
            let candidate = correct + offset
            if candidate != correct { options.insert(candidate) }
            safety -= 1
        }
        // Worst-case: pad with sequential values around correct.
        var pad = 1
        while options.count < 4 {
            let cand = correct + pad
            if cand != correct { options.insert(cand) }
            pad += 1
        }
        return Array(options).shuffled()
    }

    // MARK: – Math helpers (integer-only)

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var (a, b) = (abs(a), abs(b))
        while b != 0 { (a, b) = (b, a % b) }
        return a
    }

    private static func factorial(_ n: Int) -> Int {
        n <= 1 ? 1 : (1...n).reduce(1, *)
    }

    private static func binomial(_ n: Int, _ k: Int) -> Int {
        guard k >= 0, k <= n else { return 0 }
        let k = min(k, n - k)
        var result = 1
        for i in 0..<k {
            result = result * (n - i) / (i + 1)
        }
        return result
    }

    private static func permutation(_ n: Int, _ k: Int) -> Int {
        guard k >= 0, k <= n else { return 0 }
        var result = 1
        for i in 0..<k { result *= (n - i) }
        return result
    }

    private static func fibonacci(_ n: Int) -> Int {
        if n <= 1 { return n }
        var (a, b) = (0, 1)
        for _ in 2...n { (a, b) = (b, a + b) }
        return b
    }

    private static func eulerPhi(_ n: Int) -> Int {
        var result = n, x = n, p = 2
        while p * p <= x {
            if x % p == 0 {
                while x % p == 0 { x /= p }
                result -= result / p
            }
            p += 1
        }
        if x > 1 { result -= result / x }
        return result
    }

    private static func modPow(_ base: Int, _ exp: Int, _ mod: Int) -> Int {
        var result = 1, b = base % mod, e = exp
        while e > 0 {
            if e & 1 == 1 { result = (result * b) % mod }
            e >>= 1
            b = (b * b) % mod
        }
        return result
    }
}
