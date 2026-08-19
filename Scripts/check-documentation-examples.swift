#!/usr/bin/env swift
//
//  check-documentation-examples.swift
//  foundation-dependencies
//
//  Type-checks every Swift fence in `README.md` and in the DocC articles
//  against the package as it is actually built.
//
//  Why this exists
//  ---------------
//  Documentation is a set of claims about the API, and until this script
//  landed nothing in the repository could fail when one of those claims
//  stopped being true. Issue #27 is the shape of the damage: a registration
//  example in the README stopped compiling the same day it was written,
//  because the initialiser it called became failable, and it stayed broken
//  through three merges because no gate reads a fence. Issue #30 is the same
//  defect in a DocC article that the #27 sweep did not reach.
//
//  Run it from the package root:
//
//      swift Scripts/check-documentation-examples.swift
//
//  Exit status is 0 when every fence either type-checks or is recorded below
//  as deliberately illustrative, and 1 otherwise.
//
//  How a fence is compiled
//  -----------------------
//  Each fence is type-checked on its own, in a compilation unit containing
//  that fence, `DocumentationExampleStubs.swift`, and any other fence whose
//  declarations it refers to. Nothing is linked and nothing is run: a fence is
//  a claim about what compiles, so `-typecheck` is the whole question.
//
//  Two properties of that arrangement are load-bearing:
//
//  * **Imports are never injected into a fence that has any.** Swift resolves
//    `import` per file, so a fence that declares its own imports is judged on
//    exactly those. This is what makes the gate able to catch #27 and #30,
//    both of which are missing-import defects, and it is the first thing to
//    check if this script is ever changed.
//
//  * **A fence with no `import` line at all is an excerpt, not a file.** The
//    articles are full of three-line extracts that plainly sit inside some
//    larger file the reader already has, and demanding an import block on
//    those would be demanding the documentation get worse. Those fences, and
//    only those, are compiled under the fixed prelude below. The bright line
//    is "does this fence import anything", not a judgement call.
//
//  A fence is first tried at file scope. If that fails it is retried with its
//  body wrapped in a function, because an extract of statements is legal Swift
//  in the place it was extracted from and not at file scope. A fence passes if
//  either shape type-checks; it is reported with the file-scope diagnostics if
//  neither does.
//

import Foundation

// MARK: - Configuration

/// Markdown that carries claims about this package's API.
///
/// `README.md` is listed by name; everything under a `Documentation.docc`
/// directory is discovered, so a new article is covered the day it is added
/// rather than the day someone remembers to list it here.
let literalMarkdownPaths = ["README.md"]

/// Imports supplied to a fence that declares none of its own. See the note at
/// the top of the file: this list must stay minimal, because every entry is a
/// name a fence no longer has to import for itself. SwiftUI is deliberately
/// absent, since the missing-SwiftUI defect is one of the two this gate exists
/// to catch.
let preludeForExcerpts = """
import Dependencies
import Files
import Foundation
import FoundationDependencies
"""

/// A fence that is deliberately not compilable, together with the reason.
///
/// Matching is by content, not by position, which has two consequences worth
/// relying on. Reordering or inserting fences cannot silently shift an
/// exemption onto the wrong snippet. And editing an exempt fence changes its
/// content, so the exemption stops matching and the fence is compiled again —
/// an exemption granted once cannot quietly cover something else later.
///
/// An exemption that matches no fence is an error, so this list cannot rot
/// into a set of stale entries nobody has read.
struct Exemption {

    let reason: String
    let code: String
}

let exemptions: [Exemption] = [

    Exemption(
        reason: """
            A `Package.swift` dependency fragment, not source for a target. It \
            is checked instead by being the exact line a consumer writes, and \
            SwiftPM resolves it every time this package is depended upon.
            """,
        code: #"""
            .product(name: "FoundationDependencies", package: "foundation-dependencies")
            """#
    ),

    Exemption(
        reason: """
            Carries a deliberate elision. The article is showing where a live \
            value goes, not what goes in it, and `...` is not Swift.
            """,
        code: """
            final class BundleLocator: XcodeBundle {}

            extension MainBundleClientKey: DependencyKey {
                public static let liveValue = MainBundleClient(
                    ...
                )
            }
            """
    ),

    Exemption(
        reason: """
            Carries a deliberate elision, and is a statement of the problem \
            rather than advice: the second line is labelled as the mistake the \
            article goes on to correct.
            """,
        code: """
            let itemA = withDependencies { ... } operation: { ItemA() }
            let itemB = ItemB() // Will use testValue unexpectedly
            """
    ),

    Exemption(
        reason: """
            A single SwiftUI modifier quoted as an analogy for dependency \
            scoping. A leading-dot expression has no meaning without the \
            receiver it is chained onto, so there is no context in which it \
            could be compiled.
            """,
        code: """
            .environment(\\.colorScheme, .dark)
            """
    ),

    Exemption(
        reason: """
            The body of an `XCTestCase.invokeTest()` override. `override` is \
            only legal inside a class that inherits the method, and this \
            package's own suite is Swift Testing, so there is no such class \
            here to compile it against.
            """,
        code: """
            override func invokeTest() {
                var bundle = MainBundleClientKey.testValue
                bundle.extractName = { "Test App" }

                withDependencies {
                    $0.mainBundleClient = bundle
                } operation: {
                    super.invokeTest()
                }
            }
            """
    )
]

// MARK: - Model

/// One Swift fence, located well enough to be reported by file and line.
struct Fence {

    let path: String
    let ordinal: Int
    let firstCodeLine: Int
    let code: String

    var label: String { "\(path) fence \(ordinal) (line \(firstCodeLine))" }
}

// MARK: - Shell

struct CommandResult {

    let status: Int32
    let output: String
}

func run(_ executable: String, _ arguments: [String]) -> CommandResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [executable] + arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
    } catch {
        return CommandResult(status: 127, output: "could not launch \(executable): \(error)")
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    return CommandResult(
        status: process.terminationStatus,
        output: String(data: data, encoding: .utf8) ?? ""
    )
}

// MARK: - Text helpers

/// Strips trailing whitespace from every line and blank lines from both ends,
/// so that content matching is not defeated by invisible differences.
func normalised(_ text: String) -> String {
    let lines = text
        .components(separatedBy: "\n")
        .map { line -> String in
            var trimmed = line
            while let last = trimmed.last, last == " " || last == "\t" {
                trimmed.removeLast()
            }
            return trimmed
        }

    var start = 0
    var end = lines.count
    while start < end, lines[start].isEmpty { start += 1 }
    while end > start, lines[end - 1].isEmpty { end -= 1 }

    return lines[start..<end].joined(separator: "\n")
}

func matches(_ pattern: String, in text: String) -> [[String]] {
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(text.startIndex..., in: text)

    return expression.matches(in: text, range: range).map { match in
        (0..<match.numberOfRanges).map { index in
            guard let subrange = Range(match.range(at: index), in: text) else { return "" }
            return String(text[subrange])
        }
    }
}

// MARK: - Discovery

func markdownPaths(root: String) -> [String] {
    let manager = FileManager.default
    var paths = literalMarkdownPaths.filter { manager.fileExists(atPath: root + "/" + $0) }

    let enumerator = manager.enumerator(atPath: root + "/Sources")
    while let entry = enumerator?.nextObject() as? String {
        guard entry.hasSuffix(".md"), entry.contains("Documentation.docc/") else { continue }
        paths.append("Sources/" + entry)
    }

    return paths.sorted()
}

func fences(inMarkdownAt path: String, root: String) -> [Fence] {
    guard let contents = try? String(contentsOfFile: root + "/" + path, encoding: .utf8) else {
        return []
    }

    var found: [Fence] = []
    var collecting: [String] = []
    var isCollecting = false
    var openedAt = 0

    for (index, line) in contents.components(separatedBy: "\n").enumerated() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if isCollecting, trimmed == "```" {
            isCollecting = false
            found.append(
                Fence(
                    path: path,
                    ordinal: found.count + 1,
                    firstCodeLine: openedAt + 2,
                    code: normalised(collecting.joined(separator: "\n"))
                )
            )
            continue
        }

        if isCollecting {
            collecting.append(line)
            continue
        }

        if trimmed == "```swift" {
            isCollecting = true
            collecting = []
            openedAt = index
        }
    }

    return found
}

// MARK: - Cross-fence references

/// The names a fence introduces that another fence could legitimately use.
///
/// Only declarations the reader would see at the top of the snippet count: a
/// type, function or type alias written at column zero, plus the members of a
/// top-level `extension`, which is how the file system articles publish the
/// `.fileManager` factories. Members nested inside a type are deliberately
/// excluded, because names like `read` and `write` appear in half the fences
/// in the package and indexing them would wire every snippet to every other.
func declaredNames(in fence: Fence) -> Set<String> {
    let modifiers = "(?:(?:public|internal|private|fileprivate|open|final|static|indirect)\\s+)*"
    let keywords = "(?:struct|class|enum|protocol|actor|typealias|func)"

    var names: Set<String> = []

    for match in matches(
        "(?m)^\(modifiers)\(keywords)\\s+([A-Za-z_][A-Za-z0-9_]*)",
        in: fence.code
    ) where match.count > 1 {
        names.insert(match[1])
    }

    let declaresExtension = !matches("(?m)^extension\\s", in: fence.code).isEmpty

    if declaresExtension {
        for match in matches(
            "(?m)^\\s+\(modifiers)func\\s+([A-Za-z_][A-Za-z0-9_]*)",
            in: fence.code
        ) where match.count > 1 {
            names.insert(match[1])
        }
    }

    return names
}

func identifiers(in fence: Fence) -> Set<String> {
    Set(
        matches("[A-Za-z_][A-Za-z0-9_]*", in: fence.code)
            .compactMap(\.first)
    )
}

/// Every other fence whose declarations this one needs, followed transitively.
///
/// The file system articles are written as a sequence — here is a
/// `FileManagerContext`, here is the factory that takes one, here is the app
/// that registers it — and one of those steps means nothing without the ones
/// before it. Resolving that by reference rather than by position means the
/// articles can be reordered without this script needing to know.
func supportingFences(for fence: Fence, among candidates: [Fence]) -> [Fence] {
    var resolved: [Fence] = []
    var seen: Set<String> = [fence.label]
    var frontier = [fence]

    while let current = frontier.popLast() {
        let wanted = identifiers(in: current)
        let alreadyDeclared = declaredNames(in: current)

        for candidate in candidates where !seen.contains(candidate.label) {
            let offered = declaredNames(in: candidate).subtracting(alreadyDeclared)
            guard !offered.isDisjoint(with: wanted) else { continue }

            seen.insert(candidate.label)
            resolved.append(candidate)
            frontier.append(candidate)
        }
    }

    return resolved
}

// MARK: - Compilation

func hasImport(_ fence: Fence) -> Bool {
    !matches("(?m)^import\\s", in: fence.code).isEmpty
}

/// A fence as it will be written to disk: its own imports if it has any, the
/// fixed prelude if it has none.
func sourceFile(for fence: Fence) -> String {
    hasImport(fence) ? fence.code : preludeForExcerpts + "\n\n" + fence.code
}

/// The same fence with its statements moved inside a function body, for the
/// snippets that are an extract from somewhere rather than a whole file.
/// Imports stay at file scope, where Swift requires them.
func functionWrappedSourceFile(for fence: Fence) -> String {
    let text = sourceFile(for: fence)
    var imports: [String] = []
    var body: [String] = []

    for line in text.components(separatedBy: "\n") {
        if line.hasPrefix("import ") {
            imports.append(line)
        } else {
            body.append(line)
        }
    }

    // `@MainActor` is the honest context rather than a convenience. Every
    // accessor on `UserDefaultsStoreProtocol` is declared `@MainActor`, which
    // the protocol states as its thread-safety contract, and the places these
    // excerpts are lifted from — an `App.init()`, a view, a view model — are
    // main-actor isolated already. Wrapping in a nonisolated function would
    // fail these snippets for being called from a context no reader is in.
    //
    // `async throws` covers the excerpts that use `try` or `await`; a snippet
    // that needs neither is not penalised for it.
    return """
        \(imports.joined(separator: "\n"))

        @MainActor
        func __documentationExample() async throws {
        \(body.joined(separator: "\n"))
        }
        """
}

struct TypeCheckEnvironment {

    let stubsPath: String
    let binaryPath: String
    let sdkPath: String
    let target: String
}

func typeCheck(
    _ fence: Fence,
    supporting: [Fence],
    wrapped: Bool,
    in environment: TypeCheckEnvironment
) -> CommandResult {
    let directory = NSTemporaryDirectory()
        + "fd-doc-examples/"
        + UUID().uuidString
    try? FileManager.default.createDirectory(
        atPath: directory,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(atPath: directory) }

    var files = [environment.stubsPath]

    // Each fence keeps its own file. Swift resolves `import` per file, so a
    // supporting fence's imports must not become visible to the fence under
    // test — merging them into one file would silently supply the very import
    // whose absence this gate is looking for.
    for (index, supportingFence) in supporting.enumerated() {
        let path = directory + "/Supporting\(index).swift"
        try? sourceFile(for: supportingFence).write(
            toFile: path,
            atomically: true,
            encoding: .utf8
        )
        files.append(path)
    }

    let subjectPath = directory + "/Example.swift"
    let subject = wrapped ? functionWrappedSourceFile(for: fence) : sourceFile(for: fence)
    try? subject.write(toFile: subjectPath, atomically: true, encoding: .utf8)
    files.append(subjectPath)

    return run(
        "swiftc",
        [
            "-typecheck",
            "-swift-version", "5",
            "-target", environment.target,
            "-sdk", environment.sdkPath,
            "-I", environment.binaryPath + "/Modules",
            "-I", environment.binaryPath
        ] + files
    )
}

// MARK: - Driver

let root = FileManager.default.currentDirectoryPath

guard FileManager.default.fileExists(atPath: root + "/Package.swift") else {
    print("error: run this from the package root; no Package.swift in \(root)")
    exit(1)
}

print("Building the package so the fences can be checked against it...")
let build = run("swift", ["build"])
guard build.status == 0 else {
    print(build.output)
    print("error: `swift build` failed, so there is nothing to check the fences against")
    exit(1)
}

let binaryPathResult = run("swift", ["build", "--show-bin-path"])
guard binaryPathResult.status == 0 else {
    print(binaryPathResult.output)
    print("error: could not locate the build directory")
    exit(1)
}
let binaryPath = binaryPathResult.output.trimmingCharacters(in: .whitespacesAndNewlines)

let sdkResult = run("xcrun", ["--show-sdk-path", "--sdk", "macosx"])
let sdkPath = sdkResult.output.trimmingCharacters(in: .whitespacesAndNewlines)

let architecture = run("uname", ["-m"]).output.trimmingCharacters(in: .whitespacesAndNewlines)

// The package's own macOS floor, so that an example calling something newer
// than the package claims to support is a failure here rather than a surprise
// for a reader on macOS 13.
let environment = TypeCheckEnvironment(
    stubsPath: root + "/Scripts/DocumentationExampleStubs.swift",
    binaryPath: binaryPath,
    sdkPath: sdkPath,
    target: "\(architecture)-apple-macosx13.0"
)

let allFences = markdownPaths(root: root).flatMap { fences(inMarkdownAt: $0, root: root) }

guard !allFences.isEmpty else {
    print("error: found no Swift fences at all, which means the scan is broken")
    exit(1)
}

let normalisedExemptions = exemptions.map { ($0, normalised($0.code)) }
var usedExemptions: Set<Int> = []
var exempt: [(Fence, Exemption)] = []
var checkable: [Fence] = []

for fence in allFences {
    if let index = normalisedExemptions.firstIndex(where: { $0.1 == fence.code }) {
        usedExemptions.insert(index)
        exempt.append((fence, normalisedExemptions[index].0))
    } else {
        checkable.append(fence)
    }
}

print("Found \(allFences.count) Swift fences across \(markdownPaths(root: root).count) files.")
print("\(checkable.count) to compile, \(exempt.count) exempt.\n")

var failures: [(Fence, String)] = []

for fence in checkable {
    let supporting = supportingFences(for: fence, among: checkable)
    let atFileScope = typeCheck(fence, supporting: supporting, wrapped: false, in: environment)

    if atFileScope.status == 0 {
        print("  ok        \(fence.label)")
        continue
    }

    let wrapped = typeCheck(fence, supporting: supporting, wrapped: true, in: environment)

    if wrapped.status == 0 {
        print("  ok (body) \(fence.label)")
        continue
    }

    print("  FAILED    \(fence.label)")

    // Both shapes are reported, because which one carries the real diagnostic
    // depends on the fence. A whole-file fence fails informatively at file
    // scope and produces noise when wrapped; an excerpt does the opposite,
    // failing at file scope with nothing but "statements are not allowed at
    // the top level", which says only that the wrapping was needed.
    let compiled = supporting.isEmpty
        ? "on its own"
        : "with " + supporting.map(\.label).joined(separator: ", ")

    failures.append(
        (
            fence,
            """
            Compiled \(compiled).

            --- as written, at file scope ---
            \(atFileScope.output)
            --- with the body wrapped in a function ---
            \(wrapped.output)
            """
        )
    )
}

var unusedExemptions: [Exemption] = []
for (index, exemption) in exemptions.enumerated() where !usedExemptions.contains(index) {
    unusedExemptions.append(exemption)
}

print("")

for (fence, exemption) in exempt {
    print("  exempt    \(fence.label)")
    print("            \(exemption.reason.replacingOccurrences(of: "\n", with: "\n            "))")
}

if !failures.isEmpty {
    print("\n\(String(repeating: "-", count: 72))")
    for (fence, output) in failures {
        print("\n\(fence.label) does not compile as written:\n")
        print(output)
    }
}

if !unusedExemptions.isEmpty {
    print("\n\(String(repeating: "-", count: 72))")
    print("\nThese exemptions match no fence. The snippet they covered was edited or")
    print("removed, so the exemption is stale and must be re-decided or deleted:\n")
    for exemption in unusedExemptions {
        print(exemption.code)
        print("")
    }
}

print("\n\(String(repeating: "=", count: 72))")

if failures.isEmpty, unusedExemptions.isEmpty {
    print("\(checkable.count) documentation examples compile. \(exempt.count) exempt.")
    exit(0)
}

print("\(failures.count) documentation example(s) do not compile.")
if !unusedExemptions.isEmpty {
    print("\(unusedExemptions.count) exemption(s) match nothing.")
}
exit(1)
