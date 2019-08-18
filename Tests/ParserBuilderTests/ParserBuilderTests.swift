import XCTest
import ParserBuilder

final class ParserBuilderTests: XCTestCase {
    
    func testMatcherString() {
        let foo = "hey"
        XCTAssertEqual(Matcher("hey").advancedIndex(in: foo), foo.endIndex)
        XCTAssertNil(Matcher("hey").advancedIndex(in: "afoo"))
        XCTAssertNil(Matcher("hey").advancedIndex(in: "hez"))
    }
    
    func testMatcherAddition() {
        let foo = "hey"
        let bar = "heyyou"
        let sequence: Matcher = "hey" + "you"
        XCTAssertNotEqual(sequence.advancedIndex(in: foo), foo.endIndex)
        XCTAssertEqual(sequence.advancedIndex(in: bar), bar.endIndex)
    }
    
    func testMatcherOptional() {
        let bar = "heyyou"
        let baz = "@" + bar
        let optionalAndSeq = Matcher("@").optional() + "heyyou"
        XCTAssertEqual(optionalAndSeq.advancedIndex(in: baz), baz.endIndex)
        XCTAssertEqual(optionalAndSeq.advancedIndex(in: bar), bar.endIndex)
    }
    
    func testMatcherEmpty() {
        XCTAssertNotNil(Matcher("").advancedIndex(in: ""))
    }
    
    func testMatcherZeroRepetition() {
        XCTAssertNil(Matcher("a").count(0...0).advancedIndex(in: "a"))
        XCTAssertNil(Matcher("a").count(...0).advancedIndex(in: "a"))
    }
    
    func testMatcherMultipleRepetitions() {
        XCTAssertEqual(Matcher("a").count(0...1).advancedIndex(in: "a"), "a".endIndex)
        XCTAssertEqual(Matcher("a").count(0...1).advancedIndex(in: ""), "".endIndex)
        XCTAssertEqual(Matcher("a").count(...1).advancedIndex(in: "a"), "a".endIndex)
        XCTAssertEqual(Matcher("a").count(...3).advancedIndex(in: "aaa"), "aaa".endIndex)
        let quadA = "aaaa"
        XCTAssertEqual(Matcher("a").count(...3).advancedIndex(in: quadA), quadA.index(before: quadA.endIndex))
        XCTAssertEqual(Matcher("a").count(0..<4).advancedIndex(in: quadA), quadA.index(before: quadA.endIndex))
        XCTAssertEqual(Matcher("a").count(4...4).advancedIndex(in: quadA), quadA.endIndex)
        XCTAssertEqual(Matcher("a").count(4).advancedIndex(in: quadA), quadA.endIndex)
        XCTAssertNil(Matcher("a").count(3...).advancedIndex(in: "aa"))
        XCTAssertNil(Matcher("a").count(3...10).advancedIndex(in: "aa"))
        XCTAssertNil(Matcher("unmatched").count(1).advancedIndex(in: "hey"))
    }
    
    func testMatcherOr() {
        XCTAssertEqual((Matcher("foo") || Matcher("bar")).advancedIndex(in: "foo"), "foo".endIndex)
        XCTAssertEqual((Matcher("foo") || Matcher("bar")).advancedIndex(in: "bar"), "bar".endIndex)
        XCTAssertEqual((Matcher("foo") || Matcher("abc") || Matcher("bar")).advancedIndex(in: "bar"), "bar".endIndex)
        XCTAssertNil((Matcher("foo") || Matcher("bar")).advancedIndex(in: "baz"))
    }
    
    func testMatcherPredicate() {
        XCTAssertEqual(Matcher({ $0.isNumber }).advancedIndex(in: "1"), "1".endIndex)
        XCTAssertEqual(Matcher({ $0.isNumber }).count(1...).advancedIndex(in: "12345"), "12345".endIndex)
        XCTAssertNil(Matcher({ $0.isNumber }).advancedIndex(in: "hello"))
    }
    
    func testMatcherMix() {
        let matcher: Matcher = (Matcher("abc") + Matcher("a").count(3...3)) || Matcher({ $0.isNumber }).count(1...)
        XCTAssertEqual(matcher.advancedIndex(in: "abcaaa"), "abcaaa".endIndex)
        XCTAssertEqual(matcher.advancedIndex(in: "1"), "1".endIndex)
        XCTAssertEqual(matcher.advancedIndex(in: "12345678910"), "12345678910".endIndex)
        XCTAssertNil(matcher.advancedIndex(in: "hello"))
        
        let aOrEven = (Matcher("a") || Matcher { character in
            if let digit = Int("\(character)") {
                return digit.isMultiple(of: 2)
            } else {
                return false
            }
        }).count(1...)
        
        XCTAssertEqual(aOrEven.advancedIndex(in: "a02aa000248a"), "a02aa000248a".endIndex)
        XCTAssertNil(aOrEven.advancedIndex(in: "bc37"))
        
        // E-mail
        
        let letter = Matcher("a"..."z")
        let number = Matcher("0"..."9")
        let user = (Matcher(["_"]).optional() + (letter || number)).count(1...)
        
        XCTAssertEqual(user.advancedIndex(in: "_c"), "_c".endIndex)
        
        let emailMatcher = user  + "@" + letter.count(2...) + "." + letter.count(2...)
        let test = "ab_cd@example.org"
        XCTAssertEqual(emailMatcher.advancedIndex(in: test), test.endIndex)
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
        ("testMatcherMix", testMatcherMix),
    ]
}
