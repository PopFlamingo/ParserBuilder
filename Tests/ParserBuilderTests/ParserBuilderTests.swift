import XCTest
@testable import ParserBuilder

final class ParserBuilderTests: XCTestCase {
    
    func testMatcherString() {
        let foo = "hey"
        XCTAssertEqual(StringMatcher("hey").advancedIndex(in: foo), foo.endIndex)
        XCTAssertNil(StringMatcher("hey").advancedIndex(in: "afoo"))
        XCTAssertNil(StringMatcher("hey").advancedIndex(in: "hez"))
    }
    
    func testMatcherAddition() {
        let foo = "hey"
        let bar = "heyyou"
        let sequence = Matcher("hey") + Matcher("you")
        XCTAssertNotEqual(sequence.advancedIndex(in: foo), foo.endIndex)
        XCTAssertEqual(sequence.advancedIndex(in: bar), bar.endIndex)
    }
    
    func testMatcherOptional() {
        let bar = "heyyou"
        let baz = "@" + bar
        let optionalAndSeq = Matcher("@").optional() + Matcher("heyyou")
        let seqAndOptional = Matcher("heyyou") + StringMatcher("@").optional()
        let optionalOr = StringMatcher("foo").optional() || StringMatcher("bar").optional()
        let optionalAnd = StringMatcher("foo").optional() && StringMatcher("bar").optional()
        XCTAssertEqual(optionalAndSeq.advancedIndex(in: baz), baz.endIndex)
        XCTAssertEqual(optionalAndSeq.advancedIndex(in: bar), bar.endIndex)
        XCTAssertEqual(seqAndOptional.advancedIndex(in: bar), bar.endIndex)
        XCTAssertEqual(optionalOr.advancedIndex(in: bar), bar.startIndex)
        XCTAssertEqual(optionalAnd.advancedIndex(in: bar), bar.startIndex)
    }
    
    func testMatcherEmpty() {
        XCTAssertNotNil(StringMatcher("").advancedIndex(in: ""))
    }
    
    func testMatcherZeroRepetition() {
        XCTAssertNil(StringMatcher("a").count(0...0).advancedIndex(in: "a"))
        XCTAssertNil(StringMatcher("a").count(...0).advancedIndex(in: "a"))
    }
    
    func testMatcherMultipleRepetitions() {
        XCTAssertEqual(StringMatcher("a").count(0...1).advancedIndex(in: "a"), "a".endIndex)
        XCTAssertEqual(StringMatcher("a").count(0...1).advancedIndex(in: ""), "".endIndex)
        XCTAssertEqual(StringMatcher("a").count(...1).advancedIndex(in: "a"), "a".endIndex)
        XCTAssertEqual(StringMatcher("a").count(...3).advancedIndex(in: "aaa"), "aaa".endIndex)
        XCTAssertEqual(StringMatcher("a").count(..<3).advancedIndex(in: "aaa"), "aa".endIndex)
        let quadA = "aaaa"
        XCTAssertEqual(StringMatcher("a").count(...3).advancedIndex(in: quadA), quadA.index(before: quadA.endIndex))
        XCTAssertEqual(StringMatcher("a").count(0..<4).advancedIndex(in: quadA), quadA.index(before: quadA.endIndex))
        XCTAssertEqual(StringMatcher("a").count(4...4).advancedIndex(in: quadA), quadA.endIndex)
        XCTAssertEqual(StringMatcher("a").count(4).advancedIndex(in: quadA), quadA.endIndex)
        XCTAssertNil(StringMatcher("a").count(3...).advancedIndex(in: "aa"))
        XCTAssertNil(StringMatcher("a").atLeast(3).advancedIndex(in: "aa"))
        XCTAssertNil(StringMatcher("a").count(3...10).advancedIndex(in: "aa"))
        XCTAssertNil(StringMatcher("unmatched").count(1).advancedIndex(in: "hey"))
    }
    
    func testMatcherOr() {
        XCTAssertEqual((StringMatcher("foo") || StringMatcher("bar")).advancedIndex(in: "foo"), "foo".endIndex)
        XCTAssertEqual((StringMatcher("foo") || StringMatcher("bar")).advancedIndex(in: "bar"), "bar".endIndex)
        XCTAssertEqual((StringMatcher("foo") || StringMatcher("abc") || StringMatcher("bar")).advancedIndex(in: "bar"), "bar".endIndex)
        XCTAssertNil((StringMatcher("foo") || StringMatcher("bar")).advancedIndex(in: "baz"))
    }
    
    func testMatcherPredicate() {
        XCTAssertEqual(StringMatcher({ $0.isNumber }).advancedIndex(in: "1"), "1".endIndex)
        XCTAssertEqual(StringMatcher({ $0.isNumber }).count(1...).advancedIndex(in: "12345"), "12345".endIndex)
        XCTAssertNil(StringMatcher({ $0.isNumber }).advancedIndex(in: "hello"))
    }
    
    func testMatcherArray() {
        let matcher: Matcher = [Matcher("a"),Matcher("b"),Matcher("c")]
        let orMatcher = StringMatcher("a") || StringMatcher("b") || StringMatcher("c")
        XCTAssertEqual(matcher.advancedIndex(in: "abababa"), orMatcher.advancedIndex(in: "abababa"))
        XCTAssertEqual(matcher.advancedIndex(in: "xyz"), orMatcher.advancedIndex(in: "xyz"))
        XCTAssertEqual(matcher.advancedIndex(in: "axyz"), orMatcher.advancedIndex(in: "axyz"))
    }
    
    func testMatcherMix() {
        let matcher: Matcher = (StringMatcher("abc") + StringMatcher("a").count(3...3)) || StringMatcher({ $0.isNumber }).count(1...)
        XCTAssertEqual(matcher.advancedIndex(in: "abcaaa"), "abcaaa".endIndex)
        XCTAssertEqual(matcher.advancedIndex(in: "1"), "1".endIndex)
        XCTAssertEqual(matcher.advancedIndex(in: "12345678910"), "12345678910".endIndex)
        XCTAssertNil(matcher.advancedIndex(in: "hello"))
        
        let aOrEven = (StringMatcher("a") || Matcher { character in
            if let digit = Int("\(character)") {
                return digit.isMultiple(of: 2)
            } else {
                return false
            }
        }).count(1...)
        
        XCTAssertEqual(aOrEven.advancedIndex(in: "a02aa000248a"), "a02aa000248a".endIndex)
        XCTAssertNil(aOrEven.advancedIndex(in: "bc37"))
        
        // E-mail
        let letter = StringMatcher("a"..."z")
        let number = StringMatcher("0"..."9")
        
        let user = (letter || number) + (StringMatcher([Matcher("."),Matcher("-"),Matcher("_"),Matcher("+")]).optional() + (letter || number)).atLeast(0)
        let domain = (letter || number) + (StringMatcher([Matcher("."),Matcher("-")]).optional() + (letter || number)).atLeast(0)
        let emailMatcher = user  + Matcher("@") + domain
        let test = "ab_cd@example.org"
        XCTAssertEqual(emailMatcher.advancedIndex(in: test), test.endIndex)
    }
    
    func testConcatOpt() {
        let foo = "aba"
        let bar = "aa"
        let matcher = StringMatcher("a") + StringMatcher("b").optional() + StringMatcher("a")
        XCTAssertEqual(matcher.advancedIndex(in: foo), foo.endIndex)
        XCTAssertEqual(matcher.advancedIndex(in: bar), bar.endIndex)
    }
    
    func testNot() {
        let notA = !StringMatcher("abc")
        XCTAssertNil(notA.advancedIndex(in: "abc"))
        XCTAssertEqual(notA.advancedIndex(in: "b"), "b".startIndex)
    }
    
    func testAnd() {
        let abc = StringMatcher("abc")
        let empty = StringMatcher("")
        XCTAssertEqual((abc && empty).advancedIndex(in: "abc"), "abc".endIndex)
        XCTAssertNil((StringMatcher("a") && StringMatcher("b")).advancedIndex(in: "a"))
        
        // "Manual" lazy matcher
        let foo = "AAAAAAAB"
        let otherMatched = StringMatcher("AB")
        let manualLazy = (StringMatcher("A") && !otherMatched).count(1...)
        if let endIndex = manualLazy.advancedIndex(in: foo) {
            XCTAssertEqual(foo[..<endIndex], "AAAAAA") // Doesn't contain the last AB
        } else {
            XCTFail("Shouldn't be nil")
        }
    }
    
    func testMatcherLongerThanString() {
        let matcher: Matcher = Matcher("abcdef")
        XCTAssertNil(matcher.advancedIndex(in: "a"))
    }
    
    func testMatcherAnyCharacter() {
        let any = StringMatcher.any()
        XCTAssertNil(any.advancedIndex(in: ""))
        XCTAssertEqual(any.advancedIndex(in: "a"), "a".endIndex)
        XCTAssertEqual(any.advancedIndex(in: "⛵️"), "⛵️".endIndex)
        let twoCharacters = "🍾🌃"
        XCTAssertEqual(any.advancedIndex(in: twoCharacters), twoCharacters.index(after: twoCharacters.startIndex))
    }
        
    static var allTests = [
        ("testMatcherString", testMatcherString),
        ("testMatcherAddition", testMatcherAddition),
        ("testMatcherOptional", testMatcherOptional),
        ("testMatcherEmpty", testMatcherEmpty),
        ("testMatcherZeroRepetition", testMatcherZeroRepetition),
        ("testMatcherMultipleRepetitions", testMatcherMultipleRepetitions),
        ("testMatcherOr", testMatcherOr),
        ("testMatcherPredicate", testMatcherPredicate),
        ("testMatcherArray", testMatcherArray),
        ("testMatcherMix", testMatcherMix),
        ("testConcatOpt", testConcatOpt),
        ("testNot", testNot),
        ("testAnd", testAnd),
        ("testMatcherLongerThanString", testMatcherLongerThanString),
        ("testMatcherAnyCharacter", testMatcherAnyCharacter)
    ]
}
