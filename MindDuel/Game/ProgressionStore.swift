import Foundation
import SwiftUI

@MainActor final class ProgressionStore: ObservableObject {

    static let shared = ProgressionStore()

    // MARK: – Constants

    static let dailyQuota = 20
    private static let rollbackRate: Double = 0.15
    private static let mathLevelUpThreshold = 12
    private static let K: Double = 50.0
    /// Gentler level multiplier so high levels don't dwarf low-level
    /// scores (#69). Linear `level` made level-20 worth 20× a level-1
    /// answer; this curve is ~5× at level 20 and ~2× at level 10.
    private static func levelMultiplier(_ level: Int) -> Double {
        (3.0 + Double(level)) / 4.0
    }

    /// Adaptive level-up threshold (#43). Uses the player's pace within the
    /// CURRENT level — not lifetime — so a long-tenured player who has slowed
    /// down still gets extra questions, and a player on a hot streak ramps up
    /// quickly. Recent wrongs in the current level grow the threshold so
    /// slip-ups buy more practice before progression. Bounded [3, 10].
    private static func adaptiveThreshold(avgTime: Double, recentWrongs: Int) -> Int {
        var t = mathLevelUpThreshold
        if avgTime > 0 && avgTime < 1.2 { t -= 4 }       // very fast → -4
        else if avgTime > 0 && avgTime < 2.0 { t -= 2 }  // fast → -2
        if avgTime > 4.0                { t += 4 }       // slow → +4
        else if avgTime > 3.0           { t += 2 }       // somewhat slow → +2
        t += min(8, max(0, recentWrongs))                // each wrong adds one extra Q
        return max(8, min(25, t))
    }

    /// Per-mode running stats inside the current level. Both reset on
    /// level-up so each level starts clean. In-memory — no need to persist.
    private var mathRecentWrongs: Int = 0
    private var chemRecentWrongs: Int = 0
    private var geoRecentWrongs: Int = 0
    private var brainRecentWrongs: Int = 0
    private var scienceRecentWrongs: Int = 0
    private var historyRecentWrongs: Int = 0
    private var physicsRecentWrongs: Int = 0
    private var sportRecentWrongs: Int = 0
    private var grammarRecentWrongs: Int = 0

    private var mathLevelTimeSum: Double = 0; private var mathLevelAnswerCount: Int = 0
    private var chemLevelTimeSum: Double = 0; private var chemLevelAnswerCount: Int = 0
    private var geoLevelTimeSum:  Double = 0; private var geoLevelAnswerCount:  Int = 0
    private var brainLevelTimeSum: Double = 0; private var brainLevelAnswerCount: Int = 0
    private var scienceLevelTimeSum: Double = 0; private var scienceLevelAnswerCount: Int = 0
    private var historyLevelTimeSum: Double = 0; private var historyLevelAnswerCount: Int = 0
    private var physicsLevelTimeSum: Double = 0; private var physicsLevelAnswerCount: Int = 0
    private var sportLevelTimeSum:   Double = 0; private var sportLevelAnswerCount:   Int = 0
    private var grammarLevelTimeSum: Double = 0; private var grammarLevelAnswerCount: Int = 0

    private var mathLevelAvgTime: Double {
        mathLevelAnswerCount > 0 ? mathLevelTimeSum / Double(mathLevelAnswerCount) : averageAnswerTime
    }
    private var chemLevelAvgTime: Double {
        chemLevelAnswerCount > 0 ? chemLevelTimeSum / Double(chemLevelAnswerCount) : averageAnswerTime
    }
    private var geoLevelAvgTime: Double {
        geoLevelAnswerCount > 0 ? geoLevelTimeSum / Double(geoLevelAnswerCount) : averageAnswerTime
    }
    private var brainLevelAvgTime: Double {
        brainLevelAnswerCount > 0 ? brainLevelTimeSum / Double(brainLevelAnswerCount) : averageAnswerTime
    }
    private var scienceLevelAvgTime: Double {
        scienceLevelAnswerCount > 0 ? scienceLevelTimeSum / Double(scienceLevelAnswerCount) : averageAnswerTime
    }
    private var historyLevelAvgTime: Double {
        historyLevelAnswerCount > 0 ? historyLevelTimeSum / Double(historyLevelAnswerCount) : averageAnswerTime
    }
    private var physicsLevelAvgTime: Double {
        physicsLevelAnswerCount > 0 ? physicsLevelTimeSum / Double(physicsLevelAnswerCount) : averageAnswerTime
    }
    private var sportLevelAvgTime: Double {
        sportLevelAnswerCount > 0 ? sportLevelTimeSum / Double(sportLevelAnswerCount) : averageAnswerTime
    }
    private var grammarLevelAvgTime: Double {
        grammarLevelAnswerCount > 0 ? grammarLevelTimeSum / Double(grammarLevelAnswerCount) : averageAnswerTime
    }

    // MARK: – Published state (mirrors UserDefaults)

    @Published private(set) var piPosition: Int
    @Published private(set) var piBestScore: Int

    @Published private(set) var mathLevel: Int
    @Published private(set) var mathLevelProgress: Int
    @Published private(set) var mathBestScore: Int

    @Published private(set) var chemLevel: Int
    @Published private(set) var chemLevelProgress: Int
    @Published private(set) var chemBestScore: Int

    @Published private(set) var geoLevel: Int
    @Published private(set) var geoLevelProgress: Int
    @Published private(set) var geoBestScore: Int

    @Published private(set) var brainLevel: Int
    @Published private(set) var brainLevelProgress: Int
    @Published private(set) var brainBestScore: Int

    @Published private(set) var scienceLevel: Int
    @Published private(set) var scienceLevelProgress: Int
    @Published private(set) var scienceBestScore: Int

    @Published private(set) var historyLevel: Int
    @Published private(set) var historyLevelProgress: Int
    @Published private(set) var historyBestScore: Int

    @Published private(set) var physicsLevel: Int
    @Published private(set) var physicsLevelProgress: Int
    @Published private(set) var physicsBestScore: Int

    @Published private(set) var sportLevel: Int
    @Published private(set) var sportLevelProgress: Int
    @Published private(set) var sportBestScore: Int

    @Published private(set) var grammarLevel: Int
    @Published private(set) var grammarLevelProgress: Int
    @Published private(set) var grammarBestScore: Int

    @Published private(set) var dailyUsed: Int
    @Published private(set) var totalRoundsPlayed: Int
    @Published private(set) var isFlagged: Bool

    /// Lifetime sum of correct-answer times (seconds) and total correct
    /// answers — used to compute avg answer time on the profile (#57).
    @Published private(set) var totalCorrectAnswerTime: Double
    @Published private(set) var totalCorrectAnswers: Int

    /// Last time the user submitted any answer. Surfaced on the profile (#54).
    @Published private(set) var lastActiveAt: Date

    /// Whether the user has a premium subscription. Local mock until M6;
    /// surfaced on profiles (#58) so opponents know who can be quota-blocked.
    @Published var isPremium: Bool {
        didSet { UserDefaults.standard.set(isPremium, forKey: "isPremium") }
    }

    private var quotaResetEpoch: Double
    private var fastRoundCount: Int

    // MARK: – Init

    private init() {
        let d = UserDefaults.standard
        piPosition        = d.integer(forKey: "piPosition")
        piBestScore       = d.integer(forKey: "piBestScore")
        let storedLevel   = d.integer(forKey: "mathLevel")
        mathLevel         = storedLevel < 1 ? 1 : storedLevel
        mathLevelProgress = d.integer(forKey: "mathLevelProgress")
        mathBestScore     = d.integer(forKey: "mathBestScore")
        let storedChemLvl = d.integer(forKey: "chemLevel")
        chemLevel         = storedChemLvl < 1 ? 1 : storedChemLvl
        chemLevelProgress = d.integer(forKey: "chemLevelProgress")
        chemBestScore     = d.integer(forKey: "chemBestScore")
        let storedGeoLvl  = d.integer(forKey: "geoLevel")
        geoLevel          = storedGeoLvl < 1 ? 1 : storedGeoLvl
        geoLevelProgress  = d.integer(forKey: "geoLevelProgress")
        geoBestScore      = d.integer(forKey: "geoBestScore")
        let storedBrainLvl = d.integer(forKey: "brainLevel")
        brainLevel         = storedBrainLvl < 1 ? 1 : storedBrainLvl
        brainLevelProgress = d.integer(forKey: "brainLevelProgress")
        brainBestScore     = d.integer(forKey: "brainBestScore")
        let storedSciLvl   = d.integer(forKey: "scienceLevel")
        scienceLevel       = storedSciLvl < 1 ? 1 : storedSciLvl
        scienceLevelProgress = d.integer(forKey: "scienceLevelProgress")
        scienceBestScore   = d.integer(forKey: "scienceBestScore")
        let storedHistLvl  = d.integer(forKey: "historyLevel")
        historyLevel       = storedHistLvl < 1 ? 1 : storedHistLvl
        historyLevelProgress = d.integer(forKey: "historyLevelProgress")
        historyBestScore   = d.integer(forKey: "historyBestScore")
        let storedPhysLvl  = d.integer(forKey: "physicsLevel")
        physicsLevel       = storedPhysLvl < 1 ? 1 : storedPhysLvl
        physicsLevelProgress = d.integer(forKey: "physicsLevelProgress")
        physicsBestScore   = d.integer(forKey: "physicsBestScore")
        let storedSportLvl = d.integer(forKey: "sportLevel")
        sportLevel         = storedSportLvl < 1 ? 1 : storedSportLvl
        sportLevelProgress = d.integer(forKey: "sportLevelProgress")
        sportBestScore     = d.integer(forKey: "sportBestScore")
        let storedGramLvl  = d.integer(forKey: "grammarLevel")
        grammarLevel       = storedGramLvl < 1 ? 1 : storedGramLvl
        grammarLevelProgress = d.integer(forKey: "grammarLevelProgress")
        grammarBestScore   = d.integer(forKey: "grammarBestScore")
        dailyUsed         = d.integer(forKey: "dailyUsed")
        quotaResetEpoch   = d.double(forKey: "quotaResetEpoch")
        totalRoundsPlayed = d.integer(forKey: "totalRoundsPlayed")
        isFlagged         = d.bool(forKey: "isFlagged")
        fastRoundCount    = d.integer(forKey: "fastRoundCount")
        totalCorrectAnswerTime = d.double(forKey: "totalCorrectAnswerTime")
        totalCorrectAnswers    = d.integer(forKey: "totalCorrectAnswers")
        let storedActive       = d.double(forKey: "lastActiveAt")
        lastActiveAt           = storedActive > 0 ? Date(timeIntervalSince1970: storedActive) : Date()
        isPremium              = d.bool(forKey: "isPremium")
        checkResetQuota()
    }

    var averageAnswerTime: Double {
        totalCorrectAnswers > 0 ? totalCorrectAnswerTime / Double(totalCorrectAnswers) : 0
    }

    /// Record a correct answer's time so the running average can be shown
    /// on the profile (#57). Wrong answers are excluded — they're typically
    /// resolved by the engine penalty and don't reflect the user's pace.
    func recordCorrectAnswerTime(_ seconds: Double, mode: GameMode = .pi) {
        totalCorrectAnswerTime += seconds
        totalCorrectAnswers += 1
        UserDefaults.standard.set(totalCorrectAnswerTime, forKey: "totalCorrectAnswerTime")
        UserDefaults.standard.set(totalCorrectAnswers,    forKey: "totalCorrectAnswers")
        switch mode {
        case .math:      mathLevelTimeSum += seconds; mathLevelAnswerCount += 1
        case .chemistry: chemLevelTimeSum += seconds; chemLevelAnswerCount += 1
        case .geography: geoLevelTimeSum  += seconds; geoLevelAnswerCount  += 1
        case .brainTraining: brainLevelTimeSum += seconds; brainLevelAnswerCount += 1
        case .science:   scienceLevelTimeSum += seconds; scienceLevelAnswerCount += 1
        case .history:   historyLevelTimeSum += seconds; historyLevelAnswerCount += 1
        case .physics:   physicsLevelTimeSum += seconds; physicsLevelAnswerCount += 1
        case .sport:     sportLevelTimeSum   += seconds; sportLevelAnswerCount   += 1
        case .grammar:   grammarLevelTimeSum += seconds; grammarLevelAnswerCount += 1
        case .pi:        break
        }
    }

    private func bumpLastActive() {
        lastActiveAt = Date()
        UserDefaults.standard.set(lastActiveAt.timeIntervalSince1970, forKey: "lastActiveAt")
    }

    // MARK: – Quota

    var questionsRemaining: Int { Self.dailyQuota - dailyUsed }
    var isQuotaExhausted: Bool  { dailyUsed >= Self.dailyQuota }
    var isNearQuota: Bool       { dailyUsed >= 16 }

    var piLevel: Int { Self.piLevel(forPosition: piPosition) }

    /// Pure formula: which Pi level a given absolute digit position belongs to (1–20).
    /// Each level covers 50 digits; capped at 20.
    static func piLevel(forPosition position: Int) -> Int {
        min(20, max(0, position) / 50 + 1)
    }

    func checkResetQuota() {
        let lastReset = Date(timeIntervalSince1970: quotaResetEpoch)
        guard !Calendar.current.isDateInToday(lastReset) else { return }
        set(dailyUsed: 0)
        quotaResetEpoch = Date().timeIntervalSince1970
        UserDefaults.standard.set(quotaResetEpoch, forKey: "quotaResetEpoch")
    }

    func consumeQuestion() {
        checkResetQuota()
        set(dailyUsed: min(Self.dailyQuota, dailyUsed + 1))
        bumpLastActive()
    }

    /// Per-mode best-score / level lookup so views can iterate
    /// `GameMode.allCases` without a per-mode switch (#52).
    func bestScore(for mode: GameMode) -> Int {
        switch mode {
        case .pi:            return piBestScore
        case .math:          return mathBestScore
        case .chemistry:     return chemBestScore
        case .geography:     return geoBestScore
        case .brainTraining: return brainBestScore
        case .science:       return scienceBestScore
        case .history:       return historyBestScore
        case .physics:       return physicsBestScore
        case .sport:         return sportBestScore
        case .grammar:       return grammarBestScore
        }
    }

    func level(for mode: GameMode) -> Int {
        switch mode {
        case .pi:            return piLevel
        case .math:          return mathLevel
        case .chemistry:     return chemLevel
        case .geography:     return geoLevel
        case .brainTraining: return brainLevel
        case .science:       return scienceLevel
        case .history:       return historyLevel
        case .physics:       return physicsLevel
        case .sport:         return sportLevel
        case .grammar:       return grammarLevel
        }
    }

    func resetDailyQuota() {
        set(dailyUsed: 0)
        quotaResetEpoch = Date().timeIntervalSince1970
        UserDefaults.standard.set(quotaResetEpoch, forKey: "quotaResetEpoch")
    }

    // MARK: – Score calculation

    func piScore(correctCount: Int, avgTime: Double) -> Int {
        // Flagged accounts (suspected automation) earn no further score.
        // Why: anti-cheat threshold tripped (>= 5 sub-0.4s rounds) and we don't want
        //      to keep promoting the leaderboard until manual review clears the flag.
        guard !isFlagged, correctCount > 0, avgTime > 0.2 else { return 0 }
        return max(0, Int(Double(correctCount) * (Self.K / avgTime)))
    }

    func mathScore(correctCount: Int, level: Int, avgTime: Double) -> Int {
        guard !isFlagged, correctCount > 0, avgTime > 0.2 else { return 0 }
        let pts = Double(correctCount) * Self.levelMultiplier(level)
        return max(0, Int(pts * (Self.K / avgTime)))
    }

    /// Chemistry uses the same level-scaled scoring formula as Math.
    func chemScore(correctCount: Int, level: Int, avgTime: Double) -> Int {
        guard !isFlagged, correctCount > 0, avgTime > 0.2 else { return 0 }
        let pts = Double(correctCount) * Self.levelMultiplier(level)
        return max(0, Int(pts * (Self.K / avgTime)))
    }

    /// Geography uses the same level-scaled scoring formula as Math/Chem.
    func geoScore(correctCount: Int, level: Int, avgTime: Double) -> Int {
        guard !isFlagged, correctCount > 0, avgTime > 0.2 else { return 0 }
        let pts = Double(correctCount) * Self.levelMultiplier(level)
        return max(0, Int(pts * (Self.K / avgTime)))
    }

    // MARK: – Round results

    struct RoundResult {
        let score: Int
        let isPersonalBest: Bool
    }

    func applyPiRound(correctCount: Int, avgTime: Double, won: Bool) -> RoundResult {
        let score = piScore(correctCount: correctCount, avgTime: avgTime)
        // piPosition is advanced live via advancePiPosition() during the round.
        // On loss we still apply a small rollback as a soft "make-it-stick" penalty.
        if !won && correctCount > 0 {
            let rollback = max(0, Int(Double(correctCount) * Self.rollbackRate))
            set(piPosition: max(0, piPosition - rollback))
        }
        let pb = score > 0
        if pb { set(piBestScore: piBestScore + score) }
        incrementRounds()
        checkAntiCheat(avgTime: avgTime, correctCount: correctCount)
        return RoundResult(score: score, isPersonalBest: pb)
    }

    // Called after each correct Math answer (live level progression during round).
    // Threshold adapts to avg answer time and recent mistakes (#43).
    func advanceMathLevel() {
        var prog = mathLevelProgress + 1
        var lvl  = mathLevel
        let threshold = Self.adaptiveThreshold(avgTime: mathLevelAvgTime,
                                               recentWrongs: mathRecentWrongs)
        if prog >= threshold {
            prog = 0
            lvl  = min(20, lvl + 1)
            mathRecentWrongs = 0
            mathLevelTimeSum = 0
            mathLevelAnswerCount = 0
        }
        set(mathLevel: lvl, mathLevelProgress: prog)
    }

    /// Hook for math/chem game views to report wrong answers — feeds the
    /// adaptive threshold so the player sees more questions before levelling
    /// up after slip-ups.
    func recordWrongAnswer(mode: GameMode) {
        switch mode {
        case .math:          mathRecentWrongs += 1
        case .chemistry:     chemRecentWrongs += 1
        case .geography:     geoRecentWrongs += 1
        case .brainTraining: brainRecentWrongs += 1
        case .science:       scienceRecentWrongs += 1
        case .history:       historyRecentWrongs += 1
        case .physics:       physicsRecentWrongs += 1
        case .sport:         sportRecentWrongs   += 1
        case .grammar:       grammarRecentWrongs += 1
        case .pi:            break  // Pi has its own digit-position progression
        }
    }

    // Called after each correct Pi answer (live position progression during round).
    // Why: previously piPosition only advanced on `applyPiRound(won: true)`, which
    //      in solo Pi only fires on quota exhaustion. So a player could grind every
    //      day and never level up. Now Pi mirrors Math's live-progression model.
    // Only advances when the user is at or past the frontier — replaying digits
    // they've already mastered (e.g. starting at the level boundary) doesn't count.
    func advancePiPosition(toFrontier nextFrontier: Int) {
        if nextFrontier > piPosition {
            set(piPosition: nextFrontier)
        }
    }

    /// Live chem-level progression — same adaptive threshold as Math (#43).
    func advanceChemLevel() {
        var prog = chemLevelProgress + 1
        var lvl  = chemLevel
        let threshold = Self.adaptiveThreshold(avgTime: chemLevelAvgTime,
                                               recentWrongs: chemRecentWrongs)
        if prog >= threshold {
            prog = 0
            lvl  = min(20, lvl + 1)
            chemRecentWrongs = 0
            chemLevelTimeSum = 0
            chemLevelAnswerCount = 0
        }
        set(chemLevel: lvl, chemLevelProgress: prog)
    }

    /// Live geo-level progression — same adaptive threshold as Math/Chem.
    func advanceGeoLevel() {
        var prog = geoLevelProgress + 1
        var lvl  = geoLevel
        let threshold = Self.adaptiveThreshold(avgTime: geoLevelAvgTime,
                                               recentWrongs: geoRecentWrongs)
        if prog >= threshold {
            prog = 0
            lvl  = min(20, lvl + 1)
            geoRecentWrongs = 0
            geoLevelTimeSum = 0
            geoLevelAnswerCount = 0
        }
        set(geoLevel: lvl, geoLevelProgress: prog)
    }

    func applyGeoRound(correctCount: Int, level: Int, avgTime: Double, won: Bool) -> RoundResult {
        let score = geoScore(correctCount: correctCount, level: level, avgTime: avgTime)
        if !won && correctCount > 0 {
            let rollback     = max(0, Int(Double(correctCount) * Self.rollbackRate))
            var total        = (geoLevel - 1) * Self.mathLevelUpThreshold + geoLevelProgress
            total            = max(0, total - rollback)
            let newLevel     = min(20, max(1, total / Self.mathLevelUpThreshold + 1))
            let newProgress  = total % Self.mathLevelUpThreshold
            set(geoLevel: newLevel, geoLevelProgress: newProgress)
        }
        let pb = score > 0
        if pb { set(geoBestScore: geoBestScore + score) }
        incrementRounds()
        checkAntiCheat(avgTime: avgTime, correctCount: correctCount)
        return RoundResult(score: score, isPersonalBest: pb)
    }

    func applyChemRound(correctCount: Int, level: Int, avgTime: Double, won: Bool) -> RoundResult {
        let score = chemScore(correctCount: correctCount, level: level, avgTime: avgTime)
        if !won && correctCount > 0 {
            let rollback     = max(0, Int(Double(correctCount) * Self.rollbackRate))
            var total        = (chemLevel - 1) * Self.mathLevelUpThreshold + chemLevelProgress
            total            = max(0, total - rollback)
            let newLevel     = min(20, max(1, total / Self.mathLevelUpThreshold + 1))
            let newProgress  = total % Self.mathLevelUpThreshold
            set(chemLevel: newLevel, chemLevelProgress: newProgress)
        }
        let pb = score > 0
        if pb { set(chemBestScore: chemBestScore + score) }
        incrementRounds()
        checkAntiCheat(avgTime: avgTime, correctCount: correctCount)
        return RoundResult(score: score, isPersonalBest: pb)
    }

    /// Same scoring formula as math/chem/geo — keeps brain-training a peer
    /// rather than a special case.
    func brainScore(correctCount: Int, level: Int, avgTime: Double) -> Int {
        guard !isFlagged, correctCount > 0, avgTime > 0.2 else { return 0 }
        let pts = Double(correctCount) * Self.levelMultiplier(level)
        return max(0, Int(pts * (Self.K / avgTime)))
    }

    func advanceBrainLevel() {
        var prog = brainLevelProgress + 1
        var lvl  = brainLevel
        let threshold = Self.adaptiveThreshold(avgTime: brainLevelAvgTime,
                                               recentWrongs: brainRecentWrongs)
        if prog >= threshold {
            prog = 0
            lvl  = min(20, lvl + 1)
            brainRecentWrongs = 0
            brainLevelTimeSum = 0
            brainLevelAnswerCount = 0
        }
        set(brainLevel: lvl, brainLevelProgress: prog)
    }

    func applyBrainRound(correctCount: Int, level: Int, avgTime: Double, won: Bool) -> RoundResult {
        let score = brainScore(correctCount: correctCount, level: level, avgTime: avgTime)
        if !won && correctCount > 0 {
            let rollback     = max(0, Int(Double(correctCount) * Self.rollbackRate))
            var total        = (brainLevel - 1) * Self.mathLevelUpThreshold + brainLevelProgress
            total            = max(0, total - rollback)
            let newLevel     = min(20, max(1, total / Self.mathLevelUpThreshold + 1))
            let newProgress  = total % Self.mathLevelUpThreshold
            set(brainLevel: newLevel, brainLevelProgress: newProgress)
        }
        let pb = score > 0
        if pb { set(brainBestScore: brainBestScore + score) }
        incrementRounds()
        checkAntiCheat(avgTime: avgTime, correctCount: correctCount)
        return RoundResult(score: score, isPersonalBest: pb)
    }

    private func set(brainLevel lvl: Int, brainLevelProgress prog: Int) {
        brainLevel = lvl
        brainLevelProgress = prog
        UserDefaults.standard.set(lvl,  forKey: "brainLevel")
        UserDefaults.standard.set(prog, forKey: "brainLevelProgress")
    }

    private func set(brainBestScore val: Int) {
        brainBestScore = val
        UserDefaults.standard.set(val, forKey: "brainBestScore")
    }

    // MARK: – Science (#98)

    func scienceScore(correctCount: Int, level: Int, avgTime: Double) -> Int {
        guard !isFlagged, correctCount > 0, avgTime > 0.2 else { return 0 }
        let pts = Double(correctCount) * Self.levelMultiplier(level)
        return max(0, Int(pts * (Self.K / avgTime)))
    }

    func advanceScienceLevel() {
        var prog = scienceLevelProgress + 1
        var lvl  = scienceLevel
        let threshold = Self.adaptiveThreshold(avgTime: scienceLevelAvgTime,
                                               recentWrongs: scienceRecentWrongs)
        if prog >= threshold {
            prog = 0
            lvl  = min(20, lvl + 1)
            scienceRecentWrongs = 0
            scienceLevelTimeSum = 0
            scienceLevelAnswerCount = 0
        }
        set(scienceLevel: lvl, scienceLevelProgress: prog)
    }

    func applyScienceRound(correctCount: Int, level: Int, avgTime: Double, won: Bool) -> RoundResult {
        let score = scienceScore(correctCount: correctCount, level: level, avgTime: avgTime)
        if !won && correctCount > 0 {
            let rollback     = max(0, Int(Double(correctCount) * Self.rollbackRate))
            var total        = (scienceLevel - 1) * Self.mathLevelUpThreshold + scienceLevelProgress
            total            = max(0, total - rollback)
            let newLevel     = min(20, max(1, total / Self.mathLevelUpThreshold + 1))
            let newProgress  = total % Self.mathLevelUpThreshold
            set(scienceLevel: newLevel, scienceLevelProgress: newProgress)
        }
        let pb = score > 0
        if pb { set(scienceBestScore: scienceBestScore + score) }
        incrementRounds()
        checkAntiCheat(avgTime: avgTime, correctCount: correctCount)
        return RoundResult(score: score, isPersonalBest: pb)
    }

    private func set(scienceLevel lvl: Int, scienceLevelProgress prog: Int) {
        scienceLevel = lvl
        scienceLevelProgress = prog
        UserDefaults.standard.set(lvl,  forKey: "scienceLevel")
        UserDefaults.standard.set(prog, forKey: "scienceLevelProgress")
    }

    private func set(scienceBestScore val: Int) {
        scienceBestScore = val
        UserDefaults.standard.set(val, forKey: "scienceBestScore")
    }

    // MARK: – History (#59)

    func historyScore(correctCount: Int, level: Int, avgTime: Double) -> Int {
        guard !isFlagged, correctCount > 0, avgTime > 0.2 else { return 0 }
        let pts = Double(correctCount) * Self.levelMultiplier(level)
        return max(0, Int(pts * (Self.K / avgTime)))
    }

    func advanceHistoryLevel() {
        var prog = historyLevelProgress + 1
        var lvl  = historyLevel
        let threshold = Self.adaptiveThreshold(avgTime: historyLevelAvgTime,
                                               recentWrongs: historyRecentWrongs)
        if prog >= threshold {
            prog = 0
            lvl  = min(20, lvl + 1)
            historyRecentWrongs = 0
            historyLevelTimeSum = 0
            historyLevelAnswerCount = 0
        }
        set(historyLevel: lvl, historyLevelProgress: prog)
    }

    func applyHistoryRound(correctCount: Int, level: Int, avgTime: Double, won: Bool) -> RoundResult {
        let score = historyScore(correctCount: correctCount, level: level, avgTime: avgTime)
        if !won && correctCount > 0 {
            let rollback     = max(0, Int(Double(correctCount) * Self.rollbackRate))
            var total        = (historyLevel - 1) * Self.mathLevelUpThreshold + historyLevelProgress
            total            = max(0, total - rollback)
            let newLevel     = min(20, max(1, total / Self.mathLevelUpThreshold + 1))
            let newProgress  = total % Self.mathLevelUpThreshold
            set(historyLevel: newLevel, historyLevelProgress: newProgress)
        }
        let pb = score > 0
        if pb { set(historyBestScore: historyBestScore + score) }
        incrementRounds()
        checkAntiCheat(avgTime: avgTime, correctCount: correctCount)
        return RoundResult(score: score, isPersonalBest: pb)
    }

    private func set(historyLevel lvl: Int, historyLevelProgress prog: Int) {
        historyLevel = lvl
        historyLevelProgress = prog
        UserDefaults.standard.set(lvl,  forKey: "historyLevel")
        UserDefaults.standard.set(prog, forKey: "historyLevelProgress")
    }

    private func set(historyBestScore val: Int) {
        historyBestScore = val
        UserDefaults.standard.set(val, forKey: "historyBestScore")
    }

    // MARK: – Physics (#16)

    func physicsScore(correctCount: Int, level: Int, avgTime: Double) -> Int {
        guard !isFlagged, correctCount > 0, avgTime > 0.2 else { return 0 }
        let pts = Double(correctCount) * Self.levelMultiplier(level)
        return max(0, Int(pts * (Self.K / avgTime)))
    }

    func advancePhysicsLevel() {
        var prog = physicsLevelProgress + 1
        var lvl  = physicsLevel
        let threshold = Self.adaptiveThreshold(avgTime: physicsLevelAvgTime,
                                               recentWrongs: physicsRecentWrongs)
        if prog >= threshold {
            prog = 0
            lvl  = min(20, lvl + 1)
            physicsRecentWrongs = 0
            physicsLevelTimeSum = 0
            physicsLevelAnswerCount = 0
        }
        set(physicsLevel: lvl, physicsLevelProgress: prog)
    }

    func applyPhysicsRound(correctCount: Int, level: Int, avgTime: Double, won: Bool) -> RoundResult {
        let score = physicsScore(correctCount: correctCount, level: level, avgTime: avgTime)
        if !won && correctCount > 0 {
            let rollback     = max(0, Int(Double(correctCount) * Self.rollbackRate))
            var total        = (physicsLevel - 1) * Self.mathLevelUpThreshold + physicsLevelProgress
            total            = max(0, total - rollback)
            let newLevel     = min(20, max(1, total / Self.mathLevelUpThreshold + 1))
            let newProgress  = total % Self.mathLevelUpThreshold
            set(physicsLevel: newLevel, physicsLevelProgress: newProgress)
        }
        let pb = score > 0
        if pb { set(physicsBestScore: physicsBestScore + score) }
        incrementRounds()
        checkAntiCheat(avgTime: avgTime, correctCount: correctCount)
        return RoundResult(score: score, isPersonalBest: pb)
    }

    private func set(physicsLevel lvl: Int, physicsLevelProgress prog: Int) {
        physicsLevel = lvl
        physicsLevelProgress = prog
        UserDefaults.standard.set(lvl,  forKey: "physicsLevel")
        UserDefaults.standard.set(prog, forKey: "physicsLevelProgress")
    }

    private func set(physicsBestScore val: Int) {
        physicsBestScore = val
        UserDefaults.standard.set(val, forKey: "physicsBestScore")
    }

    // MARK: – Sport (#67)

    func sportScore(correctCount: Int, level: Int, avgTime: Double) -> Int {
        guard !isFlagged, correctCount > 0, avgTime > 0.2 else { return 0 }
        let pts = Double(correctCount) * Self.levelMultiplier(level)
        return max(0, Int(pts * (Self.K / avgTime)))
    }

    func advanceSportLevel() {
        var prog = sportLevelProgress + 1
        var lvl  = sportLevel
        let threshold = Self.adaptiveThreshold(avgTime: sportLevelAvgTime,
                                               recentWrongs: sportRecentWrongs)
        if prog >= threshold {
            prog = 0
            lvl  = min(20, lvl + 1)
            sportRecentWrongs = 0
            sportLevelTimeSum = 0
            sportLevelAnswerCount = 0
        }
        set(sportLevel: lvl, sportLevelProgress: prog)
    }

    func applySportRound(correctCount: Int, level: Int, avgTime: Double, won: Bool) -> RoundResult {
        let score = sportScore(correctCount: correctCount, level: level, avgTime: avgTime)
        if !won && correctCount > 0 {
            let rollback     = max(0, Int(Double(correctCount) * Self.rollbackRate))
            var total        = (sportLevel - 1) * Self.mathLevelUpThreshold + sportLevelProgress
            total            = max(0, total - rollback)
            let newLevel     = min(20, max(1, total / Self.mathLevelUpThreshold + 1))
            let newProgress  = total % Self.mathLevelUpThreshold
            set(sportLevel: newLevel, sportLevelProgress: newProgress)
        }
        let pb = score > 0
        if pb { set(sportBestScore: sportBestScore + score) }
        incrementRounds()
        checkAntiCheat(avgTime: avgTime, correctCount: correctCount)
        return RoundResult(score: score, isPersonalBest: pb)
    }

    private func set(sportLevel lvl: Int, sportLevelProgress prog: Int) {
        sportLevel = lvl
        sportLevelProgress = prog
        UserDefaults.standard.set(lvl,  forKey: "sportLevel")
        UserDefaults.standard.set(prog, forKey: "sportLevelProgress")
    }

    private func set(sportBestScore val: Int) {
        sportBestScore = val
        UserDefaults.standard.set(val, forKey: "sportBestScore")
    }

    // MARK: – Grammar (#39)

    func grammarScore(correctCount: Int, level: Int, avgTime: Double) -> Int {
        guard !isFlagged, correctCount > 0, avgTime > 0.2 else { return 0 }
        let pts = Double(correctCount) * Self.levelMultiplier(level)
        return max(0, Int(pts * (Self.K / avgTime)))
    }

    func advanceGrammarLevel() {
        var prog = grammarLevelProgress + 1
        var lvl  = grammarLevel
        let threshold = Self.adaptiveThreshold(avgTime: grammarLevelAvgTime,
                                               recentWrongs: grammarRecentWrongs)
        if prog >= threshold {
            prog = 0
            lvl  = min(20, lvl + 1)
            grammarRecentWrongs = 0
            grammarLevelTimeSum = 0
            grammarLevelAnswerCount = 0
        }
        set(grammarLevel: lvl, grammarLevelProgress: prog)
    }

    func applyGrammarRound(correctCount: Int, level: Int, avgTime: Double, won: Bool) -> RoundResult {
        let score = grammarScore(correctCount: correctCount, level: level, avgTime: avgTime)
        if !won && correctCount > 0 {
            let rollback     = max(0, Int(Double(correctCount) * Self.rollbackRate))
            var total        = (grammarLevel - 1) * Self.mathLevelUpThreshold + grammarLevelProgress
            total            = max(0, total - rollback)
            let newLevel     = min(20, max(1, total / Self.mathLevelUpThreshold + 1))
            let newProgress  = total % Self.mathLevelUpThreshold
            set(grammarLevel: newLevel, grammarLevelProgress: newProgress)
        }
        let pb = score > 0
        if pb { set(grammarBestScore: grammarBestScore + score) }
        incrementRounds()
        checkAntiCheat(avgTime: avgTime, correctCount: correctCount)
        return RoundResult(score: score, isPersonalBest: pb)
    }

    private func set(grammarLevel lvl: Int, grammarLevelProgress prog: Int) {
        grammarLevel = lvl
        grammarLevelProgress = prog
        UserDefaults.standard.set(lvl,  forKey: "grammarLevel")
        UserDefaults.standard.set(prog, forKey: "grammarLevelProgress")
    }

    private func set(grammarBestScore val: Int) {
        grammarBestScore = val
        UserDefaults.standard.set(val, forKey: "grammarBestScore")
    }

    func applyMathRound(correctCount: Int, level: Int, avgTime: Double, won: Bool) -> RoundResult {
        let score = mathScore(correctCount: correctCount, level: level, avgTime: avgTime)
        if !won && correctCount > 0 {
            let rollback     = max(0, Int(Double(correctCount) * Self.rollbackRate))
            var total        = (mathLevel - 1) * Self.mathLevelUpThreshold + mathLevelProgress
            total            = max(0, total - rollback)
            let newLevel     = min(20, max(1, total / Self.mathLevelUpThreshold + 1))
            let newProgress  = total % Self.mathLevelUpThreshold
            set(mathLevel: newLevel, mathLevelProgress: newProgress)
        }
        let pb = score > 0
        if pb { set(mathBestScore: mathBestScore + score) }
        incrementRounds()
        checkAntiCheat(avgTime: avgTime, correctCount: correctCount)
        return RoundResult(score: score, isPersonalBest: pb)
    }

    // MARK: – Anti-cheat

    private func checkAntiCheat(avgTime: Double, correctCount: Int) {
        guard correctCount >= 3, avgTime > 0, avgTime < 0.4 else { return }
        fastRoundCount += 1
        UserDefaults.standard.set(fastRoundCount, forKey: "fastRoundCount")
        if fastRoundCount >= 5 && !isFlagged {
            isFlagged = true
            UserDefaults.standard.set(true, forKey: "isFlagged")
        }
    }

    // MARK: – Private setters (keep published + UserDefaults in sync)

    private func incrementRounds() {
        totalRoundsPlayed += 1
        UserDefaults.standard.set(totalRoundsPlayed, forKey: "totalRoundsPlayed")
    }

    private func set(piPosition val: Int) {
        piPosition = val
        UserDefaults.standard.set(val, forKey: "piPosition")
    }

    private func set(piBestScore val: Int) {
        piBestScore = val
        UserDefaults.standard.set(val, forKey: "piBestScore")
    }

    private func set(mathLevel lvl: Int, mathLevelProgress prog: Int) {
        mathLevel = lvl
        mathLevelProgress = prog
        UserDefaults.standard.set(lvl,  forKey: "mathLevel")
        UserDefaults.standard.set(prog, forKey: "mathLevelProgress")
    }

    private func set(mathBestScore val: Int) {
        mathBestScore = val
        UserDefaults.standard.set(val, forKey: "mathBestScore")
    }

    private func set(chemLevel lvl: Int, chemLevelProgress prog: Int) {
        chemLevel = lvl
        chemLevelProgress = prog
        UserDefaults.standard.set(lvl,  forKey: "chemLevel")
        UserDefaults.standard.set(prog, forKey: "chemLevelProgress")
    }

    private func set(chemBestScore val: Int) {
        chemBestScore = val
        UserDefaults.standard.set(val, forKey: "chemBestScore")
    }

    private func set(geoLevel lvl: Int, geoLevelProgress prog: Int) {
        geoLevel = lvl
        geoLevelProgress = prog
        UserDefaults.standard.set(lvl,  forKey: "geoLevel")
        UserDefaults.standard.set(prog, forKey: "geoLevelProgress")
    }

    private func set(geoBestScore val: Int) {
        geoBestScore = val
        UserDefaults.standard.set(val, forKey: "geoBestScore")
    }

    private func set(dailyUsed val: Int) {
        dailyUsed = val
        UserDefaults.standard.set(val, forKey: "dailyUsed")
    }

    // MARK: – Multiplayer integration

    func recordMultiplayerScore(mode: GameMode, score: Int, correctCount: Int = 0) {
        switch mode {
        case .pi:
            if score > 0 { set(piBestScore: piBestScore + score) }
            if correctCount > 0 { set(piPosition: piPosition + correctCount) }
        case .math:
            if score > 0 { set(mathBestScore: mathBestScore + score) }
            for _ in 0..<correctCount { advanceMathLevel() }
        case .chemistry:
            if score > 0 { set(chemBestScore: chemBestScore + score) }
            for _ in 0..<correctCount { advanceChemLevel() }
        case .geography:
            if score > 0 { set(geoBestScore: geoBestScore + score) }
            for _ in 0..<correctCount { advanceGeoLevel() }
        case .brainTraining:
            if score > 0 { set(brainBestScore: brainBestScore + score) }
            for _ in 0..<correctCount { advanceBrainLevel() }
        case .science:
            if score > 0 { set(scienceBestScore: scienceBestScore + score) }
            for _ in 0..<correctCount { advanceScienceLevel() }
        case .history:
            if score > 0 { set(historyBestScore: historyBestScore + score) }
            for _ in 0..<correctCount { advanceHistoryLevel() }
        case .physics:
            if score > 0 { set(physicsBestScore: physicsBestScore + score) }
            for _ in 0..<correctCount { advancePhysicsLevel() }
        case .sport:
            if score > 0 { set(sportBestScore: sportBestScore + score) }
            for _ in 0..<correctCount { advanceSportLevel() }
        case .grammar:
            if score > 0 { set(grammarBestScore: grammarBestScore + score) }
            for _ in 0..<correctCount { advanceGrammarLevel() }
        }
        incrementRounds()
    }
}
