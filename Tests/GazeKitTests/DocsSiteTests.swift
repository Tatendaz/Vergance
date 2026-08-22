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

    /// Visible text of an HTML fragment; `separator` replaces each tag (" " for blocks, "" for inline).
    private static func text(_ html: String, separator: String) -> String {
        let noCode = html.replacingOccurrences(of: "(?si)<(script|style)\\b[^>]*>.*?</\\1>", with: "", options: .regularExpression)
        let stripped = noCode.replacingOccurrences(of: "<[^>]+>", with: separator, options: .regularExpression)
        let decoded = stripped
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        return decoded
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func testH1AndContentLiveInsideMain() throws {
        let html = try Self.read("docs/index.html")
        let mains = Self.matches("<main\\b[^>]*>(.*?)</main>", in: html)
        XCTAssertEqual(mains.count, 1, "exactly one <main>")
        XCTAssertEqual(Self.matches("<h1\\b", in: html).count, 1, "exactly one <h1>")
        XCTAssertEqual(Self.matches("<h1\\b", in: mains.first ?? "").count, 1, "the <h1> must be inside <main>")
        XCTAssertGreaterThanOrEqual(Self.text(mains.first ?? "", separator: " ").count, 500, "500+ chars of text inside <main>")
    }

    func testHeadAdvertisesMarkdownTwinAndLlmsTxt() throws {
        let html = try Self.read("docs/index.html")
        XCTAssertTrue(html.contains("<link rel=\"alternate\" type=\"text/markdown\" href=\"/\(Self.slug)/index.md\""))
        XCTAssertTrue(html.contains("<link rel=\"describedby\" href=\"/llms.txt\">"))
        XCTAssertTrue(html.contains("href=\"https://tatendaz.github.io/llms.txt\""))
    }

    func testMarkdownTwinMirrorsThePage() throws {
        let html = try Self.read("docs/index.html")
        let md = try Self.read("docs/index.md")
        XCTAssertTrue(md.hasPrefix("# "), "twin must start with an H1")
        let h1 = Self.text(Self.matches("<h1\\b[^>]*>(.*?)</h1>", in: html).first ?? "", separator: "")
        let firstLine = md.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        XCTAssertEqual(String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespaces), h1)
        for h2 in Self.matches("<h2\\b[^>]*>(.*?)</h2>", in: html) {
            let heading = "## " + Self.text(h2, separator: "")
            XCTAssertTrue(md.contains(heading), "twin is missing \"\(heading)\"")
        }
        XCTAssertGreaterThanOrEqual(md.count, 500)
        XCTAssertTrue(md.contains("HTML version: https://tatendaz.github.io/\(Self.slug)/"))
        XCTAssertTrue(md.contains("https://tatendaz.github.io/llms.txt"))
        XCTAssertNil(md.range(of: "<(div|span|script|style)\\b", options: .regularExpression), "twin must be plain Markdown")
    }
}
