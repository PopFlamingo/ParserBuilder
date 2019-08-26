import Foundation

public struct Matcher: ExpressibleByStringLiteral, ExpressibleByArrayLiteral {
    
    @inlinable
    public init(stringLiteral value: String) {
        self.matcher = .string(value)
    }
    
    @inlinable
    public init(arrayLiteral elements: Matcher...) {
        self = .init(elements)
    }
    
    @inlinable
    public init(_ matcherArray: [Matcher]) {
        self = matcherArray.reduce(Matcher.never, ||)
    }
    
    @inlinable
    public init(_ matchedString: String) {
        self.matcher = .string(matchedString)
    }
    
    @inlinable
    init(_ predicate: @escaping (Character)->Bool) {
        self.matcher = .predicate(predicate)
    }
    
    @inlinable
    public init(_ characterRange: ClosedRange<Character>) {
        self.matcher = .closedRange(characterRange)
    }
    
    @inlinable
    public init(charactersIn setString: String) {
        self = .init { character in
            let set = CharacterSet(charactersIn: setString)
            return character.unicodeScalars.allSatisfy(set.contains)
        }
    }
    
    @usableFromInline
    init(matcher: InternalMatcher) {
        self.matcher = matcher
    }
    
    @inlinable
    public static prefix func !(matcher: Matcher) -> Matcher {
        return Matcher(matcher: .not(matcher))
    }
    
    @inlinable
    public static func +(lhs: Matcher, rhs: Matcher) -> Matcher {
        return Matcher(matcher: .concatenation(lhs, rhs))
    }
    
    @inlinable
    public static func ||(lhs: Matcher, rhs: Matcher) -> Matcher {
        return Matcher(matcher: .or(lhs, rhs))
    }
    
    @inlinable
    public static func &&(lhs: Matcher, rhs: Matcher) -> Matcher {
        return Matcher(matcher: .and(lhs, rhs))
    }
    
    @inlinable
    public func advancedIndex(in string: String) -> String.Index? {
        return advancedIndex(in: string, range: string.startIndex..<string.endIndex)
        
    }
    
    @inlinable
    public func advancedIndex(in string: String, range: Range<String.Index>) -> String.Index? {
        switch self.matcher {
        case .string(let matchedString):
            guard !matchedString.isEmpty else {
                return range.lowerBound
            }
            var matchedIndex = matchedString.startIndex
            var index = range.lowerBound
            
            while matchedIndex < matchedString.endIndex {
                guard index < string.endIndex else {
                    return nil
                }
                if matchedString[matchedIndex] == string[index] {
                    matchedIndex = matchedString.index(after: matchedIndex)
                    index = string.index(after: index)
                } else {
                    return nil
                }
            }
            return index
            
        case .predicate(let predicate):
            guard range.lowerBound < string.endIndex else {
                return nil
            }
            if !string.isEmpty, case let firstCharacter = string[range.lowerBound], predicate(firstCharacter) {
                return string.index(after: range.lowerBound)
            } else {
                return nil
            }
            
        case .or(let lhs, let rhs):
            if let first = lhs.advancedIndex(in: string, range: range) {
                return first
            } else if let second = rhs.advancedIndex(in: string, range: range) {
                return second
            } else {
                return nil
            }
            
        case .concatenation(let first, let second):
            guard let firstIndex = first.advancedIndex(in: string, range: range) else {
                return nil
            }
            let secondIndex = second.advancedIndex(in: string, range: firstIndex..<range.upperBound)
            return secondIndex
            
        case .repeated(let matcher, let min, let max, let maxIsIncluded):
            if let max = max, max == 0 {
                return nil
            }
            var currentIndex = range.lowerBound
            var repeatCount = 0
            let actualMax: Int?
            if let max = max {
                actualMax = maxIsIncluded ? max : max-1
            } else {
                actualMax = nil
            }
            
            while currentIndex < range.upperBound, repeatCount != actualMax, let newIndex = matcher.advancedIndex(in: string, range: currentIndex..<range.upperBound) {
                currentIndex = newIndex
                repeatCount += 1
            }
            
            if let min = min {
                return (repeatCount >= min) ? currentIndex : nil
            } else {
                return currentIndex
            }
            
        case .closedRange(let charRange):
            if !string.isEmpty, case let first = string[range.lowerBound], charRange.contains(first) {
                return string.index(after: range.lowerBound)
            } else {
                return nil
            }
            
        case .not(let matcher):
            if matcher.advancedIndex(in: string, range: range) != nil {
                return nil
            } else {
                return range.lowerBound
            }
            
        case .and(let lhs, let rhs):
            if let lhsIndex = lhs.advancedIndex(in: string, range: range), let rhsIndex = rhs.advancedIndex(in: string, range: range) {
                return max(lhsIndex, rhsIndex)
            } else {
                return nil
            }
        }
    }
    
    @inlinable
    public func count(_ repeatRange: PartialRangeThrough<Int>) -> Matcher {
        precondition(repeatRange.upperBound >= 0)
        return Matcher(matcher: .repeated(self, nil, repeatRange.upperBound, true))
    }
    
    @inlinable
    public func count(_ repeatRange: PartialRangeUpTo<Int>) -> Matcher {
        precondition(repeatRange.upperBound >= 0)
        return Matcher(matcher: .repeated(self, nil, repeatRange.upperBound, false))
    }
    
    @inlinable
    public func count(_ repeatRange: PartialRangeFrom<Int>) -> Matcher {
        precondition(repeatRange.lowerBound >= 0)
        return Matcher(matcher: .repeated(self, repeatRange.lowerBound, nil, true))
    }
    
    @inlinable
    public func count(_ repeatRange: ClosedRange<Int>) -> Matcher {
        precondition(repeatRange.lowerBound >= 0 && repeatRange.upperBound >= 0)
        return Matcher(matcher: .repeated(self, repeatRange.lowerBound, repeatRange.upperBound, true))
    }
    
    @inlinable
    public func count(_ repeatRange: Range<Int>) -> Matcher {
        precondition(repeatRange.lowerBound >= 0 && repeatRange.upperBound >= 0)
        return Matcher(matcher: .repeated(self, repeatRange.lowerBound, repeatRange.upperBound, false))
    }
    
    @inlinable
    public func count(_ times: Int) -> Matcher {
        self.count(times...times)
    }
    
    @inlinable
    public func optional() -> Matcher {
        return self.count(0...1)
    }
    
    @inlinable
    public func atLeast(_ minimum: Int) -> Matcher {
        return self.count(minimum...)
    }
    
    //FIXME: This is not the same as `Matcher("")`, is this correct?
    @usableFromInline
    static let never: Matcher = Matcher { _ in false }
    
    @usableFromInline
    let matcher: InternalMatcher
    
    @usableFromInline
    indirect enum InternalMatcher {
        case string(String)
        case predicate((Character)->Bool)
        case concatenation(Matcher, Matcher)
        case or(Matcher, Matcher)
        case repeated(Matcher, Int?, Int?, Bool)
        case closedRange(ClosedRange<Character>)
        case not(Matcher)
        case and(Matcher, Matcher)
    }
}
