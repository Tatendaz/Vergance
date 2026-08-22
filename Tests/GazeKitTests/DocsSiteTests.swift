import XCTest

/// Keeps the GitHub Pages landing page (docs/index.html) agent-readable: the text and the
/// `<h1>` sit inside `<main>`, and the Markdown twin advertised by
/// `<link rel="alternate" type="text/markdown">` mirrors the page. No network, no Vision.
final class DocsSiteTests: XCTestCase {
    private static let slug = "Vergance"
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // GazeKitTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // repo root

    private static func read(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Capture group 1 of every match (or the whole match when there is no group).
    private static func matches(_ pattern: String, in text: String) -> [String] {
        let re = try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
            ns.substring(with: $0.numberOfRanges > 1 ? $0.range(at: 1) : $0.range)
        }
    }

    /// Inner HTML of the single `<tag>…</tag>` element in the document.
    private static func section(_ tag: String, in html: String, file: StaticString = #filePath, line: UInt = #line) -> String {
        let found = matches("<\(tag)\\b[^>]*>(.*?)</\(tag)>", in: html)
        XCTAssertEqual(found.count, 1, "expected exactly one <\(tag)>", file: file, line: line)
        return found.first ?? ""
    }

    /// Tags removed by a character walk: a `<br>` becomes a space, every other tag vanishes.
    private static func stripTags(_ html: String) -> String {
        var out = ""
        var tag: String? = nil
        for ch in html {
            if var current = tag {
                if ch == ">" {
                    if current.lowercased().hasPrefix("br") { out.append(" ") }
                    tag = nil
                } else {
                    current.append(ch)
                    tag = current
                }
            } else if ch == "<" {
                tag = ""
            } else {
                out.append(ch)
            }
        }
        return out
    }

    /// One pass over the entities, so an "&amp;lt;" can never be unescaped twice.
    private static func decode(_ text: String) -> String {
        let entities = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "#39": "'", "nbsp": " "]
        var out = ""
        var rest = Substring(text)
        while let amp = rest.firstIndex(of: "&") {
            out += rest[..<amp]
            let afterAmp = rest[rest.index(after: amp)...]
            if let semi = afterAmp.firstIndex(of: ";"), let value = entities[String(afterAmp[..<semi])] {
                out += value
                rest = afterAmp[afterAmp.index(after: semi)...]
            } else {
                out.append("&")
                rest = afterAmp
            }
        }
        return out + rest
    }

    /// Collapse whitespace and drop the characters Markdown adds for emphasis/code.
    private static func squash(_ text: String) -> String {
        text.replacingOccurrences(of: "[*`\\\\]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func blockText(_ fragment: String) -> String { squash(decode(stripTags(fragment))) }

    /// The Markdown twin as plain text: no code blocks, links and images reduced to their text.
    private static func twinPlain(_ md: String) -> String {
        squash(md
            .replacingOccurrences(of: "(?s)```.*?```", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "!\\[([^\\]]*)\\]\\([^)]*\\)", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]*\\)", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "(?m)^>\\s?", with: "", options: .regularExpression))
    }

    func testH1AndContentLiveInsideMain() throws {
        let html = try Self.read("docs/index.html")
        let main = Self.section("main", in: html)
        XCTAssertEqual(Self.matches("<h1\\b", in: html).count, 1, "exactly one <h1>")
        XCTAssertEqual(Self.matches("<h1\\b", in: main).count, 1, "the <h1> must be inside <main>")
        XCTAssertGreaterThanOrEqual(Self.blockText(main).count, 500, "500+ chars of text inside <main>")
    }

    func testHeadAdvertisesMarkdownTwinAndLlmsTxt() throws {
        let html = try Self.read("docs/index.html")
        let head = Self.section("head", in: html)
        XCTAssertTrue(head.contains("<link rel=\"alternate\" type=\"text/markdown\" href=\"/\(Self.slug)/index.md\""))
        XCTAssertTrue(head.contains("<link rel=\"describedby\" href=\"/llms.txt\">"))
        XCTAssertTrue(Self.section("footer", in: html).contains("href=\"https://tatendaz.github.io/llms.txt\""))
    }

    func testMarkdownTwinMirrorsThePage() throws {
        let html = try Self.read("docs/index.html")
        let md = try Self.read("docs/index.md")
        XCTAssertTrue(md.hasPrefix("# "), "twin must start with an H1")
        let firstLine = md.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        XCTAssertEqual(String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespaces), Self.blockText(Self.section("h1", in: html)))
        for h2 in Self.matches("<h2\\b[^>]*>(.*?)</h2>", in: html) {
            let heading = "## " + Self.blockText(h2)
            XCTAssertTrue(md.contains(heading), "twin is missing \"\(heading)\"")
        }
        XCTAssertTrue(md.contains("HTML version: https://tatendaz.github.io/\(Self.slug)/"))
        XCTAssertTrue(md.contains("https://tatendaz.github.io/llms.txt"))
        for tag in ["<div", "<span", "<script", "<style"] {
            XCTAssertFalse(md.contains(tag), "twin must be plain Markdown (found \(tag))")
        }
    }

    func testMarkdownTwinCarriesEveryParagraph() throws {
        let html = try Self.read("docs/index.html")
        let md = try Self.read("docs/index.md")
        let main = Self.section("main", in: html)
        let blocks = Self.matches("<(?:p|li)\\b[^>]*>(.*?)</(?:p|li)>", in: main).map(Self.blockText).filter { !$0.isEmpty }
        XCTAssertGreaterThanOrEqual(blocks.count, 10, "expected 10+ text blocks inside <main>")
        let plain = Self.twinPlain(md)
        for block in blocks {
            XCTAssertTrue(plain.contains(block), "twin is missing the text: \(block.prefix(80))")
        }
    }
}
