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
    @Published private(set) var piFloor: Int
    @Published private(set) var piBestScore: Int

    @Published private(set) var mathLevel: Int
    @Published private(set) var mathLevelProgress: Int
    @Published private(set) var mathBestScore: Int

    @Published private(set) var dailyUsed: Int
    @Published private(set) var totalRoundsPlayed: Int
    @Published private(set) var isFlagged: Bool

    private var quotaResetEpoch: Double
    private var fastRoundCount: Int

    // MARK: – Init

    private init() {
        let d = UserDefaults.standard
        piPosition        = d.integer(forKey: "piPosition")
        piFloor           = d.integer(forKey: "piFloor")
        piBestScore       = d.integer(forKey: "piBestScore")
        let storedLevel   = d.integer(forKey: "mathLevel")
        mathLevel         = storedLevel < 1 ? 1 : storedLevel
        mathLevelProgress = d.integer(forKey: "mathLevelProgress")
        mathBestScore     = d.integer(forKey: "mathBestScore")
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

    var piLevel: Int { min(20, piPosition / 50 + 1) }

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
        guard correctCount > 0, avgTime > 0.2 else { return 0 }
        return max(0, Int(Double(correctCount) * (Self.K / avgTime)))
    }

    func mathScore(correctCount: Int, level: Int, avgTime: Double) -> Int {
        guard correctCount > 0, avgTime > 0.2 else { return 0 }
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
        if correctCount > 0 {
            if won {
                set(piPosition: piPosition + correctCount)
            } else {
                let rollback = max(0, Int(Double(correctCount) * Self.rollbackRate))
                set(piPosition: max(piFloor, piPosition - rollback))
            }
        }
        let pb = score > 0 && score > piBestScore
        if pb { set(piBestScore: score) }
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
        let pb = score > 0 && score > mathBestScore
        if pb { set(mathBestScore: score) }
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

    private func set(dailyUsed val: Int) {
        dailyUsed = val
        UserDefaults.standard.set(val, forKey: "dailyUsed")
    }

    // MARK: – Multiplayer integration

    func recordMultiplayerScore(mode: GameMode, score: Int, correctCount: Int = 0) {
        if mode == .pi {
            // Accumulate so every game contributes, regardless of round size
            if score > 0 { set(piBestScore: piBestScore + score) }
            if correctCount > 0 { set(piPosition: piPosition + correctCount) }
        } else {
            if score > 0 { set(mathBestScore: mathBestScore + score) }
            for _ in 0..<correctCount { advanceMathLevel() }
        }
        incrementRounds()
    }
}
