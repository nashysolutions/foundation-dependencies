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
//  Exit status is 0 when every fence either type-checks cleanly or is recorded
//  below as deliberately illustrative, and 1 otherwise.
//
//  What "cleanly" means, and why
//  -----------------------------
//  A fence passes only when it type-checks *and* emits no warning this gate
//  holds the documentation to. An example that compiles with a warning teaches
//  the reader to write the warning, so exit status alone is too weak a test.
//
//  Issue #36 is the shape of that damage, and it was measured rather than
//  argued: a retroactive conformance written without `@retroactive` is a
//  warning and nothing else, so with the status-only check this script
//  originally had, that defect planted in an ordinary compiled fence printed
//  `ok` and exited 0.
//
//  The verdict is read out of the compiler's output rather than taken from
//  `-warnings-as-errors`, for one reason: a single group has to be held back
//  (see `toleratedWarningGroups`), and `-Wwarning no-usage` is rejected as an
//  unknown warning group by the 6.2 toolchain this package builds with. Should
//  a later toolchain accept it, the flag is the better mechanism and this
//  parsing should go.
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

    // `@MainActor` is the honest context rather than a convenience. The places
    // these excerpts are lifted from — an `App.init()`, a view, a view model —
    // are main-actor isolated already, so a snippet that touches anything
    // requiring the main actor is in the context its reader is in.
    //
    // It is deliberately the wider context, not the narrower one. No client in
    // this package requires the main actor any longer; every endpoint is a
    // nonisolated `@Sendable` closure, and a nonisolated function is callable
    // from here. A snippet that only compiles because of this annotation is
    // therefore reaching for something outside this package, which is a fair
    // thing for a documentation example to do.
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
    let modulePath: String
    let sdkPath: String
    let target: String
}

/// What one type-check run found.
///
/// `status` alone is not the verdict. A fence that compiles with a warning
/// teaches the reader to write the warning, so a clean run is one that exits
/// zero *and* emits nothing this gate holds the documentation to.
struct TypeCheckOutcome {

    let status: Int32
    let output: String
    let warnings: [String]

    var isClean: Bool { status == 0 && warnings.isEmpty }
}

/// Warning groups reported but never failed on, by the tag `swiftc` prints at
/// the end of a diagnostic's first line.
///
/// `no-usage` is here because this script manufactures it rather than finding
/// it. Half the excerpts in these articles end on the line that matters —
/// `let url = try bundle.urlForResource("Localisable", "strings")` is showing
/// the reader what the call hands back — and the binding is unread only
/// because the function this script wraps the excerpt in has nothing after it.
/// Failing on that would be demanding the articles consume every value they
/// demonstrate, which is the documentation getting worse: the same judgement
/// the excerpt prelude above already makes about imports. Five fences were
/// measured to trip this group and nothing else.
///
/// Add a group here only after reading its diagnostics and finding all of them
/// to be artefacts of the wrapping. Anything a reader would meet in their own
/// file stays a failure.
let toleratedWarningGroups: Set<String> = ["no-usage"]

/// The warnings in a type-check run that this gate holds the documentation to.
///
/// Two filters, both load-bearing.
///
/// A diagnostic's first line is the one beginning with the file's absolute
/// path. The compiler repeats the same text on the caret continuation lines,
/// so matching every occurrence reads one warning as several — the same
/// over-counting the strict-concurrency job in `ci.yml` guards against.
///
/// `ownedPrefixes` keeps the verdict to files this gate wrote: the fence, its
/// supporting fences, and the stubs. A warning inside a dependency's module
/// interface is real information and is printed with the rest of the output,
/// but it is not something an article can be edited to fix, so failing a fence
/// for it would make this gate red for reasons no author here controls.
func gatedWarnings(in output: String, ownedPrefixes: [String]) -> [String] {
    output
        .components(separatedBy: "\n")
        .filter { line in
            guard line.contains(": warning: ") else { return false }
            guard ownedPrefixes.contains(where: { line.hasPrefix($0) }) else { return false }
            return !toleratedWarningGroups.contains { line.hasSuffix("[#\($0)]") }
        }
}

/// The one directory holding the built `.swiftmodule` files.
///
/// Deliberately not the build directory itself. That directory also contains a
/// `*.build` subdirectory per target, several of which carry a `module.modulemap`,
/// and SwiftPM builds the macro plugins swift-syntax needs twice — once as
/// `X.build` and once as `X-tool.build`. Putting the build directory on the
/// import path therefore offers the same module under two names and every
/// type-check fails with `redefinition of module 'SwiftParser'`, which looks
/// exactly like a broken documentation example and is not one.
///
/// Locating the package's own module and using its directory avoids guessing at
/// a layout that has changed across SwiftPM versions, and fails with something
/// readable if the layout changes again.
func moduleSearchPath(under binaryPath: String) -> String? {
    let manager = FileManager.default
    let candidates = [binaryPath + "/Modules", binaryPath]

    return candidates.first { directory in
        manager.fileExists(atPath: directory + "/FoundationDependencies.swiftmodule")
    }
}

func typeCheck(
    _ fence: Fence,
    supporting: [Fence],
    wrapped: Bool,
    in environment: TypeCheckEnvironment
) -> TypeCheckOutcome {
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

    let result = run(
        "swiftc",
        [
            "-typecheck",
            "-swift-version", "5",
            "-target", environment.target,
            "-sdk", environment.sdkPath,
            "-I", environment.modulePath
        ] + files
    )

    return TypeCheckOutcome(
        status: result.status,
        output: result.output,
        warnings: gatedWarnings(
            in: result.output,
            ownedPrefixes: [directory, environment.stubsPath]
        )
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

guard let modulePath = moduleSearchPath(under: binaryPath) else {
    print("error: no FoundationDependencies.swiftmodule under \(binaryPath).")
    print("The build layout is not what this script expects, so every fence would")
    print("fail for want of the package rather than for anything wrong with it.")
    exit(1)
}

let sdkResult = run("xcrun", ["--show-sdk-path", "--sdk", "macosx"])
let sdkPath = sdkResult.output.trimmingCharacters(in: .whitespacesAndNewlines)

let architecture = run("uname", ["-m"]).output.trimmingCharacters(in: .whitespacesAndNewlines)

// The package's own macOS floor, so that an example calling something newer
// than the package claims to support is a failure here rather than a surprise
// for a reader on macOS 13.
let environment = TypeCheckEnvironment(
    stubsPath: root + "/Scripts/DocumentationExampleStubs.swift",
    modulePath: modulePath,
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

var failures: [(fence: Fence, headline: String, detail: String)] = []

for fence in checkable {
    let supporting = supportingFences(for: fence, among: checkable)
    let atFileScope = typeCheck(fence, supporting: supporting, wrapped: false, in: environment)

    if atFileScope.isClean {
        print("  ok        \(fence.label)")
        continue
    }

    let wrapped = typeCheck(fence, supporting: supporting, wrapped: true, in: environment)

    if wrapped.isClean {
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

    // A fence that type-checked and was failed only for its warnings is a
    // different defect from one that does not compile, and saying so is the
    // difference between a reader fixing the example and a reader hunting for
    // an error that is not there.
    let cleanlyCompiled = atFileScope.status == 0 || wrapped.status == 0
    let headline = cleanlyCompiled
        ? "compiles, but not without warnings"
        : "does not compile as written"

    // De-duplicated because a warning in a supporting fence or in the stubs is
    // reported once per shape, and reading it twice suggests two defects.
    let warnings = Set(atFileScope.warnings + wrapped.warnings).sorted()
    let warningNote = warnings.isEmpty
        ? ""
        : "\nHeld against the documentation:\n" + warnings.joined(separator: "\n") + "\n"

    failures.append(
        (
            fence,
            headline,
            """
            Compiled \(compiled).
            \(warningNote)
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
    for failure in failures {
        print("\n\(failure.fence.label) \(failure.headline):\n")
        print(failure.detail)
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
    print("\(checkable.count) documentation examples compile without warnings. \(exempt.count) exempt.")
    exit(0)
}

print("\(failures.count) documentation example(s) do not compile cleanly.")
if !unusedExemptions.isEmpty {
    print("\(unusedExemptions.count) exemption(s) match nothing.")
}
exit(1)
