//
//  ScriptDraftGenerator.swift
//  ReTakeAi
//

import Foundation

struct ScriptDraftGenerator {
    struct Inputs: Hashable {
        var projectTitle: String
        var intent: ScriptIntent
        var toneMood: ScriptToneMood
        var expectedDurationSeconds: Int
    }

    static func generateDraft(inputs: Inputs) -> String {
        let seconds = max(10, min(inputs.expectedDurationSeconds, 5 * 60))
        let wordCount = approximateWordCount(forSeconds: seconds)

        let hook = hookLine(intent: inputs.intent, tone: inputs.toneMood, projectTitle: inputs.projectTitle)
        let promise = promiseLine(intent: inputs.intent, tone: inputs.toneMood)
        let body = bodyParagraph(intent: inputs.intent, tone: inputs.toneMood, targetWordCount: max(40, wordCount - 35))
        let close = closingLine(intent: inputs.intent, tone: inputs.toneMood)

        return [hook, "", promise, "", body, "", close].joined(separator: "\n")
    }

    private static func approximateWordCount(forSeconds seconds: Int) -> Int {
        // ~150 words/min ≈ 2.5 words/sec
        Int(Double(seconds) * 2.5)
    }

    private static func hookLine(intent: ScriptIntent, tone: ScriptToneMood, projectTitle: String) -> String {
        let titleBit = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : " (\(projectTitle))"

        switch (intent, tone) {
        case (.promote, .energetic):
            return "Quick one\(titleBit): here’s what you’re missing—and how to fix it today."
        case (.promote, _):
            return "In the next few seconds\(titleBit), I’ll show you the simplest way to get a better result."
        case (.explain, .calm):
            return "Let’s break this down simply\(titleBit)—no fluff, just the core idea."
        case (.explain, _):
            return "Here’s the simplest way to understand this\(titleBit)."
        case (.educate, _):
            return "Here’s a quick lesson you can use immediately\(titleBit)."
        case (.storytelling, .cinematic):
            return "Picture this\(titleBit): one moment changed everything."
        case (.storytelling, _):
            return "Let me tell you a short story\(titleBit)."
        case (.entertainment, .fun):
            return "Okay, this is going to be fun\(titleBit)—watch this."
        case (.entertainment, _):
            return "You’re going to love this\(titleBit)."
        case (.corporate, .professional):
            return "Here’s the key update\(titleBit) and what it means for you."
        case (.corporate, _):
            return "Here’s a clear summary\(titleBit) and the next step."
        }
    }

    private static func promiseLine(intent: ScriptIntent, tone: ScriptToneMood) -> String {
        let ending = (tone == .energetic || tone == .fun) ? "—let’s go." : "."
        switch intent {
        case .explain:
            return "By the end, you’ll know exactly what it is and when to use it\(ending)"
        case .promote:
            return "I’ll show you what it does, who it’s for, and how to get started\(ending)"
        case .storytelling:
            return "It’s short, it’s real, and there’s a takeaway at the end\(ending)"
        case .educate:
            return "You’ll learn one practical framework you can apply today\(ending)"
        case .entertainment:
            return "Stick around for the twist—and the quick tip at the end\(ending)"
        case .corporate:
            return "We’ll cover the context, the impact, and the recommended action\(ending)"
        }
    }

    private static func bodyParagraph(intent: ScriptIntent, tone: ScriptToneMood, targetWordCount: Int) -> String {
        let core = coreBodyLines(intent: intent, tone: tone)
        let filler = supportingLines(intent: intent, tone: tone)

        var lines: [String] = []
        lines.append(contentsOf: core)

        // Add supporting lines until we roughly hit the desired length.
        var currentWords = lines.joined(separator: " ").split(separator: " ").count
        var fillerIndex = 0
        while currentWords < targetWordCount, fillerIndex < filler.count {
            lines.append(filler[fillerIndex])
            fillerIndex += 1
            currentWords = lines.joined(separator: " ").split(separator: " ").count
        }

        return lines.joined(separator: "\n")
    }

    private static func coreBodyLines(intent: ScriptIntent, tone: ScriptToneMood) -> [String] {
        switch intent {
        case .explain:
            return [
                "First: define the problem in one sentence.",
                "Second: explain the key idea using a simple example.",
                "Third: show the common mistake—and the correct approach."
            ]
        case .promote:
            return [
                "Here’s what it is: a simple solution that removes a painful step.",
                "Here’s why it matters: it saves time and reduces mistakes.",
                "Here’s how you start: pick one small use-case and try it today."
            ]
        case .storytelling:
            return [
                "I thought I was doing everything right… until one detail proved me wrong.",
                "That moment forced a change: I simplified, focused, and repeated the basics.",
                "The result wasn’t magic—it was consistency with a clear next action."
            ]
        case .educate:
            return [
                "Use this framework: Context → Constraint → Choice.",
                "Context: what’s happening and why it matters.",
                "Constraint: what you can’t change.",
                "Choice: the one action that moves the needle."
            ]
        case .entertainment:
            return [
                "Rule #1: set the expectation.",
                "Rule #2: surprise them with a quick switch.",
                "Rule #3: land a clean takeaway so it’s satisfying."
            ]
        case .corporate:
            return [
                "Background: this change is driven by a clear business need.",
                "Impact: it affects timeline, scope, and how we communicate status.",
                "Action: align on the next milestone and owners."
            ]
        }
    }

    private static func supportingLines(intent: ScriptIntent, tone: ScriptToneMood) -> [String] {
        let toneLine: String = {
            switch tone {
            case .professional: return "Keep it crisp: one point per sentence."
            case .emotional: return "Name the feeling, then deliver the solution."
            case .energetic: return "Keep the pace up and land each point fast."
            case .calm: return "Slow down, breathe, and let the message land."
            case .cinematic: return "Paint the scene, then cut to the key detail."
            case .fun: return "Add a playful beat—then bring it back to value."
            case .serious: return "Stay direct, avoid filler, and be precise."
            }
        }()

        let intentLine: String = {
            switch intent {
            case .explain: return "If you remember one thing, remember the definition and one example."
            case .promote: return "If you’re the right fit, the next step is simple."
            case .storytelling: return "The point isn’t the story—it’s the lesson."
            case .educate: return "Practice it once today, and it sticks."
            case .entertainment: return "Make it punchy, then end clean."
            case .corporate: return "Document the decision and communicate it clearly."
            }
        }()

        return [toneLine, intentLine]
    }

    private static func closingLine(intent: ScriptIntent, tone: ScriptToneMood) -> String {
        switch (intent, tone) {
        case (.promote, .energetic), (.promote, .fun):
            return "Want the exact steps? Comment “START” and I’ll share the checklist."
        case (.promote, _):
            return "If you want to go deeper, I’ll share the next step—just ask."
        case (.corporate, _):
            return "Thanks—let’s align on owners and the next milestone."
        case (.educate, _):
            return "Try it once today, and you’ll feel the difference."
        case (.explain, _):
            return "That’s the core idea—keep it simple and apply it once."
        case (.storytelling, _):
            return "That’s the lesson: simplify, commit, and follow through."
        case (.entertainment, _):
            return "If you enjoyed this, do one small thing today and you’ll win."
        }
    }
}


