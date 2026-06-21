//
//  TerminalLogTests.swift
//  ColimaStackTests
//
//  Tests for the terminal-view capability: FIFO eviction, LogLine
//  identity, color rules, streaming append.
//

import XCTest
import AppKit
@testable import ColimaStack

@MainActor
final class TerminalLogTests: XCTestCase {
    func testFIFOEviction() {
        let buffer = LogStreamBuffer(maxLines: 3)
        buffer.append(LogLine(stream: .stdout, text: "a"))
        buffer.append(LogLine(stream: .stdout, text: "b"))
        buffer.append(LogLine(stream: .stdout, text: "c"))
        XCTAssertEqual(buffer.lines.map(\.text), ["a", "b", "c"])
        buffer.append(LogLine(stream: .stdout, text: "d"))
        XCTAssertEqual(buffer.lines.map(\.text), ["b", "c", "d"])
    }

    func testFIFOEvictionAtBoundary() {
        let buffer = LogStreamBuffer(maxLines: 1)
        buffer.append(LogLine(stream: .stdout, text: "a"))
        XCTAssertEqual(buffer.lines.count, 1)
        buffer.append(LogLine(stream: .stdout, text: "b"))
        XCTAssertEqual(buffer.lines.count, 1)
        XCTAssertEqual(buffer.lines.first?.text, "b")
    }

    func testAppendTextSplitsOnNewlines() {
        let buffer = LogStreamBuffer()
        buffer.append(text: "line1\nline2\nline3", stream: .stdout)
        XCTAssertEqual(buffer.lines.count, 3)
        XCTAssertEqual(buffer.lines.map(\.text), ["line1", "line2", "line3"])
    }

    func testAppendTextEmptyString() {
        let buffer = LogStreamBuffer()
        buffer.append(text: "", stream: .stdout)
        XCTAssertEqual(buffer.lines.count, 0)
    }

    func testClear() {
        let buffer = LogStreamBuffer()
        buffer.append(LogLine(stream: .stdout, text: "a"))
        buffer.append(LogLine(stream: .stdout, text: "b"))
        buffer.clear()
        XCTAssertEqual(buffer.lines.count, 0)
    }

    func testLogStreamColors() {
        XCTAssertEqual(LogStream.stdout.nsColor, .labelColor)
        XCTAssertEqual(LogStream.stderr.nsColor, .systemOrange)
        XCTAssertEqual(LogStream.system.nsColor, .secondaryLabelColor)
        XCTAssertEqual(LogStream.error.nsColor, .systemRed)
    }

    func testLogLineIdentity() {
        let line = LogLine(stream: .stdout, text: "hello")
        XCTAssertEqual(line.stream, .stdout)
        XCTAssertEqual(line.text, "hello")
    }

    func testAttributedStringIncludesLineNumbers() {
        let lines = [
            LogLine(stream: .stdout, text: "a"),
            LogLine(stream: .stderr, text: "b")
        ]
        let attributed = LogTextStorage.attributedString(for: lines, startingAt: 1, showLineNumbers: true)
        let string = attributed.string
        XCTAssertTrue(string.contains("1"), "Expected line number '1' in \(string)")
        XCTAssertTrue(string.contains("2"), "Expected line number '2' in \(string)")
        XCTAssertTrue(string.contains("a"))
        XCTAssertTrue(string.contains("b"))
    }

    func testAttributedStringOmitsLineNumbers() {
        let lines = [LogLine(stream: .stdout, text: "a")]
        let attributed = LogTextStorage.attributedString(for: lines, startingAt: 1, showLineNumbers: false)
        XCTAssertFalse(attributed.string.contains("1"))
        XCTAssertTrue(attributed.string.contains("a"))
    }

    func testTextInitBackwardCompat() {
        let view = TerminalLogView(text: "hello world")
        XCTAssertEqual(view.buffer.lines.count, 1)
        XCTAssertEqual(view.buffer.lines.first?.text, "hello world")
    }

    func testTextInitEmptyString() {
        let view = TerminalLogView(text: "")
        XCTAssertEqual(view.buffer.lines.count, 0)
    }
}
