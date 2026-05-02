import Foundation
import SwiftUI

@MainActor final class ProgressionStore: ObservableObject {

    static let shared = ProgressionStore()

    // MARK: – Constants

    static let dailyQuota = 20
    private static let rollbackRate: Double = 0.15
    private static let mathLevelUpThreshold = 5
    private static let K: Double = 100.0

    // MARK: – Published state (mirrors UserDefaults)

    @Published private(set) var piPosition: Int
    @Published private(set) var piBestScore: Int

    @Published private(set) var mathLevel: Int
    @Published private(set) var mathLevelProgress: Int
    @Published private(set) var mathBestScore: Int

    @Published private(set) var chemLevel: Int
    @Published private(set) var chemLevelProgress: Int
    @Published private(set) var chemBestScore: Int

    @Published private(set) var dailyUsed: Int
    @Published private(set) var totalRoundsPlayed: Int
    @Published private(set) var isFlagged: Bool

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
        dailyUsed         = d.integer(forKey: "dailyUsed")
        quotaResetEpoch   = d.double(forKey: "quotaResetEpoch")
        totalRoundsPlayed = d.integer(forKey: "totalRoundsPlayed")
        isFlagged         = d.bool(forKey: "isFlagged")
        fastRoundCount    = d.integer(forKey: "fastRoundCount")
        checkResetQuota()
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
        let pts = Double(level * correctCount)
        return max(0, Int(pts * (Self.K / avgTime)))
    }

    /// Chemistry uses the same level-scaled scoring formula as Math.
    func chemScore(correctCount: Int, level: Int, avgTime: Double) -> Int {
        guard !isFlagged, correctCount > 0, avgTime > 0.2 else { return 0 }
        let pts = Double(level * correctCount)
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

    // Called after each correct Math answer (live level progression during round)
    func advanceMathLevel() {
        var prog = mathLevelProgress + 1
        var lvl  = mathLevel
        if prog >= Self.mathLevelUpThreshold {
            prog = 0
            lvl  = min(20, lvl + 1)
        }
        set(mathLevel: lvl, mathLevelProgress: prog)
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

    /// Live chem-level progression — same threshold model as Math.
    func advanceChemLevel() {
        var prog = chemLevelProgress + 1
        var lvl  = chemLevel
        if prog >= Self.mathLevelUpThreshold {
            prog = 0
            lvl  = min(20, lvl + 1)
        }
        set(chemLevel: lvl, chemLevelProgress: prog)
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
        }
        incrementRounds()
    }
}
