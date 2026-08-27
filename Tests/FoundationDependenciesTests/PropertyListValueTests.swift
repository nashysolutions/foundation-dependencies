//
//  PropertyListValueTests.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 27/08/2026.
//

import Foundation
import Testing
@testable import FoundationDependencies

/// Which case a literal builds, and what each case converts to.
///
/// These are the two claims the type makes that nothing else checks directly. The
/// contract suites exercise `setPropertyList` end to end, but they read back through
/// coercing readers, and a Boolean and the integer one read alike through most of
/// them: `string` renders both a stored `true` and a stored `1` as `"1"`. So a literal
/// that built the wrong case would pass the contract suites and still write the wrong
/// thing into the `plist`, which is what a consumer reading the file, or an
/// Objective-C component reading the domain, would see.
///
/// `@testable` because `foundationValue` is internal: it is the bridge the stores use,
/// not something a consumer needs.
@Suite("Property list values")
struct PropertyListValueTests {

    @Test("A literal builds the case it names")
    func literalsBuildTheirCase() {
        #expect(PropertyListValue.boolean(true) == true)
        #expect(PropertyListValue.integer(1) == 1)
        #expect(PropertyListValue.double(1.5) == 1.5)
        #expect(PropertyListValue.string("abc") == "abc")
        #expect(PropertyListValue.array([.string("a"), .integer(1)]) == ["a", 1])
        #expect(
            PropertyListValue.dictionary(["a": .integer(1)]) == ["a": 1]
        )
    }

    /// The one a literal could plausibly get wrong. `true` is a Boolean and not the
    /// integer one, and `1` is the integer and not `true`.
    @Test("A Boolean literal and an integer literal are different cases")
    func booleanAndIntegerLiteralsDiffer() {
        let flag: PropertyListValue = true
        let number: PropertyListValue = 1

        #expect(flag == .boolean(true))
        #expect(number == .integer(1))
        #expect(flag != number)
    }

    @Test("Every case converts to a property list type")
    func everyCaseConvertsToAPropertyListType() {
        let value: PropertyListValue = [
            "flag": true,
            "number": 42,
            "fraction": 3.5,
            "text": "abc",
            "moment": .date(Date(timeIntervalSince1970: 0)),
            "blob": .data(Data([0x01])),
            "list": ["a", 1],
            "nested": ["deeper": ["a"]]
        ]

        #expect(
            PropertyListSerialization.propertyList(value.foundationValue, isValidFor: .binary),
            """
            A case converted to something a property list cannot hold, which is the \
            one thing this type exists to make impossible.
            """
        )
    }

    /// The conversion is recursive, so a nested value is not left as a
    /// `PropertyListValue` inside an otherwise converted container.
    @Test("Conversion reaches nested values")
    func conversionReachesNestedValues() {
        let converted = PropertyListValue.array([.array([.string("a")])]).foundationValue

        let outer = converted as? [Any]
        let inner = outer?.first as? [Any]
        #expect(inner?.first as? String == "a")
    }
}
