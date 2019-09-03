public struct GenericMatcher<C>: ExpressibleByArrayLiteral where C: Collection, C.Element: Comparable {
    
    @inlinable
    public init(arrayLiteral elements: GenericMatcher...) {
        self = .init(set: elements)
    }
    
    @inlinable
    public init(set: [GenericMatcher]) {
        self = set.reduce(GenericMatcher.never(), ||)
    }
    
    @inlinable
    public init(_ exactPattern: C) {
        self.matcher = .collection(exactPattern)
    }
    
    @inlinable
    public init(_ characterRange: ClosedRange<C.Element>) {
        self.matcher = .closedRange(characterRange)
    }
    
     @inlinable
    public static func any() -> GenericMatcher<C> {
        return .init(matcher: .any)
    }
    
    @usableFromInline
    init(matcher: InternalMatcher) {
        self.matcher = matcher
    }
    
    @inlinable
    public static prefix func !(matcher: GenericMatcher<C>) -> GenericMatcher<C> {
        return GenericMatcher<C>(matcher: .not(matcher))
    }
    
    @inlinable
    public static func +(lhs: GenericMatcher<C>, rhs: GenericMatcher<C>) -> GenericMatcher<C> {
        return GenericMatcher<C>(matcher: .concatenation(lhs, rhs))
    }
    
    @inlinable
    public static func ||(lhs: GenericMatcher<C>, rhs: GenericMatcher<C>) -> GenericMatcher<C> {
        return GenericMatcher<C>(matcher: .or(lhs, rhs))
    }
    
    @inlinable
    public static func &&(lhs: GenericMatcher<C>, rhs: GenericMatcher<C>) -> GenericMatcher<C> {
        return GenericMatcher<C>(matcher: .and(lhs, rhs))
    }
    
    @inlinable
    public func advancedIndex<D>(in string: D) -> C.Index? where D: Collection, D.Element == C.Element, D.Index == C.Index {
        return advancedIndex(in: string, range: string.startIndex..<string.endIndex)
        
    }
    
    @inlinable
    public func advancedIndex<D>(in string: D, range: Range<C.Index>) -> C.Index? where D: Collection, D.Element == C.Element, D.Index == C.Index {
        switch self.matcher {
        case .collection(let matchedString):
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
            
        case .any:
            if range.lowerBound != range.upperBound && !string.isEmpty {
                return string.index(after: range.lowerBound)
            } else {
                return nil
            }
        }
    }
    
    @inlinable
    public func count(_ repeatRange: PartialRangeThrough<Int>) -> GenericMatcher<C> {
        precondition(repeatRange.upperBound >= 0)
        return GenericMatcher<C>(matcher: .repeated(self, nil, repeatRange.upperBound, true))
    }
    
    @inlinable
    public func count(_ repeatRange: PartialRangeUpTo<Int>) -> GenericMatcher<C> {
        precondition(repeatRange.upperBound >= 0)
        return GenericMatcher<C>(matcher: .repeated(self, nil, repeatRange.upperBound, false))
    }
    
    @inlinable
    public func count(_ repeatRange: PartialRangeFrom<Int>) -> GenericMatcher<C> {
        precondition(repeatRange.lowerBound >= 0)
        return GenericMatcher<C>(matcher: .repeated(self, repeatRange.lowerBound, nil, true))
    }
    
    @inlinable
    public func count(_ repeatRange: ClosedRange<Int>) -> GenericMatcher<C> {
        precondition(repeatRange.lowerBound >= 0 && repeatRange.upperBound >= 0)
        return GenericMatcher<C>(matcher: .repeated(self, repeatRange.lowerBound, repeatRange.upperBound, true))
    }
    
    @inlinable
    public func count(_ repeatRange: Range<Int>) -> GenericMatcher<C> {
        precondition(repeatRange.lowerBound >= 0 && repeatRange.upperBound >= 0)
        return GenericMatcher<C>(matcher: .repeated(self, repeatRange.lowerBound, repeatRange.upperBound, false))
    }
    
    @inlinable
    public func count(_ times: Int) -> GenericMatcher {
        self.count(times...times)
    }
    
    @inlinable
    public func optional() -> GenericMatcher {
        return self.count(0...1)
    }
    
    @inlinable
    public func atLeast(_ minimum: Int) -> GenericMatcher {
        return self.count(minimum...)
    }
    
    //FIXME: This is not the same as `StringMatcher("")`, is this correct?
    @usableFromInline
    static func never() -> GenericMatcher<C> {
        !GenericMatcher<C>.any()
    }
    
    @usableFromInline
    let matcher: InternalMatcher
    
    @usableFromInline
    indirect enum InternalMatcher {
        case collection(C)
        case concatenation(GenericMatcher, GenericMatcher)
        case or(GenericMatcher, GenericMatcher)
        case repeated(GenericMatcher, Int?, Int?, Bool)
        case closedRange(ClosedRange<C.Element>)
        case not(GenericMatcher)
        case and(GenericMatcher, GenericMatcher)
        case any
    }
}



extension String {
    @inlinable
    var utf8Characters: [UInt8] {
        var copy = self
        return copy.withUTF8({ Array($0) })
    }
}

extension GenericMatcher where C == String {
    
    @inlinable
    func toOptimizedASCII() -> GenericMatcher<[UInt8]>? {
        switch self.matcher {
        
        case .collection(let string):
            if string.allSatisfy({ $0.isASCII }) {
                return GenericMatcher<[UInt8]>(string.utf8Characters)
            } else {
                return nil
            }
        
        case .concatenation(let lhs, let rhs):
            if let oLHS = lhs.toOptimizedASCII(), let oRHS = rhs.toOptimizedASCII() {
                return oLHS + oRHS
            } else {
                return nil
            }
            
        case .or(let lhs, let rhs):
            if let oLHS = lhs.toOptimizedASCII(), let oRHS = rhs.toOptimizedASCII() {
                return oLHS || oRHS
            } else {
                return nil
            }
            
        case .repeated(let matcher, let min, let max, let maxIsIncluded):
            if let oMatcher = matcher.toOptimizedASCII() {
                return GenericMatcher<[UInt8]>(matcher: .repeated(oMatcher, min, max, maxIsIncluded))
            } else {
                return nil
            }
            
        case .closedRange(let range):
            if let lowerASCII = range.lowerBound.asciiValue, let upperASCII = range.upperBound.asciiValue {
                return GenericMatcher<[UInt8]>(matcher: .closedRange(lowerASCII...upperASCII))
            } else {
                return nil
            }
            
        case .not(let inverted):
            if let optimized = inverted.toOptimizedASCII() {
                return !optimized
            } else {
                return nil
            }
            
        case .and(let lhs, let rhs):
            if let oLHS = lhs.toOptimizedASCII(), let oRHS = rhs.toOptimizedASCII() {
                return oLHS && oRHS
            } else {
                return nil
            }
            
        case .any:
            return GenericMatcher<[UInt8]>.any()
        }
    }
}

extension GenericMatcher: ExpressibleByUnicodeScalarLiteral where C == String {
    public init(unicodeScalarLiteral value: String) {
        self.init(value)
    }
}

extension GenericMatcher: ExpressibleByExtendedGraphemeClusterLiteral where C == String {
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(value)
    }
}

public typealias Matcher = GenericMatcher<String>

extension GenericMatcher: ExpressibleByStringLiteral where C == String {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}
