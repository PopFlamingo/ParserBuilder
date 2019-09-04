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
    public func advancedIndex<D>(in collection: D) -> C.Index? where D: Collection, D.Element == C.Element, D.Index == C.Index {
        return advancedIndex(in: collection, range: collection.startIndex..<collection.endIndex)
        
    }
    
    @inlinable
    public func advancedIndex<D>(in collection: D, range: Range<C.Index>) -> C.Index? where D: Collection, D.Element == C.Element, D.Index == C.Index {
        switch self.matcher {
        case .single(let value):
            guard !range.isEmpty && range.lowerBound < collection.endIndex else {
                return nil
            }
            if value == collection[range.lowerBound] {
                return collection.index(after: range.lowerBound)
            } else {
                return nil
            }
            
        case .collection(let matchedCollection):
            guard !matchedCollection.isEmpty else {
                return range.lowerBound
            }
            var matchedIndex = matchedCollection.startIndex
            var index = range.lowerBound
            
            while matchedIndex < matchedCollection.endIndex {
                guard index < collection.endIndex else {
                    return nil
                }
                if matchedCollection[matchedIndex] == collection[index] {
                    matchedIndex = matchedCollection.index(after: matchedIndex)
                    index = collection.index(after: index)
                } else {
                    return nil
                }
            }
            return index
            
        case .or(let lhs, let rhs):
            if let first = lhs.advancedIndex(in: collection, range: range) {
                return first
            } else if let second = rhs.advancedIndex(in: collection, range: range) {
                return second
            } else {
                return nil
            }
            
        case .concatenation(let first, let second):
            guard let firstIndex = first.advancedIndex(in: collection, range: range) else {
                return nil
            }
            let secondIndex = second.advancedIndex(in: collection, range: firstIndex..<range.upperBound)
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
            
            while currentIndex < range.upperBound, repeatCount != actualMax, let newIndex = matcher.advancedIndex(in: collection, range: currentIndex..<range.upperBound) {
                currentIndex = newIndex
                repeatCount += 1
            }
            
            if let min = min {
                return (repeatCount >= min) ? currentIndex : nil
            } else {
                return currentIndex
            }
            
        case .closedRange(let elementRange):
            if !collection.isEmpty, case let first = collection[range.lowerBound], elementRange.contains(first) {
                return collection.index(after: range.lowerBound)
            } else {
                return nil
            }
            
        case .not(let matcher):
            if matcher.advancedIndex(in: collection, range: range) != nil {
                return nil
            } else {
                return range.lowerBound
            }
            
        case .and(let lhs, let rhs):
            if let lhsIndex = lhs.advancedIndex(in: collection, range: range), let rhsIndex = rhs.advancedIndex(in: collection, range: range) {
                return max(lhsIndex, rhsIndex)
            } else {
                return nil
            }
            
        case .any:
            if range.lowerBound != range.upperBound && !collection.isEmpty {
                return collection.index(after: range.lowerBound)
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
    
    @usableFromInline
    static func never() -> GenericMatcher<C> {
        !GenericMatcher<C>.any()
    }
    
    @usableFromInline
    let matcher: InternalMatcher
    
    @inlinable
    func optimizeToSingle() -> GenericMatcher<C> {
        switch self.matcher {
        case .single(_):
            return self
            
        case .collection(let c):
            if let first = c.first, c.count == 1 {
                return GenericMatcher<C>(matcher: .single(first))
            } else {
                return self
            }
            
        case .concatenation(let lhs, let rhs):
            return lhs.optimizeToSingle() + rhs.optimizeToSingle()
            
        case .or(let lhs, let rhs):
            return lhs.optimizeToSingle() || rhs.optimizeToSingle()
            
        case .repeated(let val, let min, let max, let maxIsIncluded):
            return GenericMatcher<C>(matcher: .repeated(val.optimizeToSingle(), min, max, maxIsIncluded))
            
        case .closedRange(_):
            return self
            
        case .not(let inverted):
            return !(inverted.optimizeToSingle())
            
        case .and(let lhs, let rhs):
            return lhs.optimizeToSingle() && rhs.optimizeToSingle()
            
        case .any:
            return self
        }
    }
    
    @usableFromInline
    indirect enum InternalMatcher {
        case single(C.Element)
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
    public func optimized() -> MatcherKind {
        if let asciiOptimized = self.optimizedToASCII() {
            return .optimized(asciiOptimized.optimizeToSingle())
        } else {
            return .standard(self.optimizeToSingle())
        }
    }
    
    @inlinable
    public func optimizedToASCII() -> GenericMatcher<[UInt8]>? {
        switch self.matcher {
        case .single(let value):
            if let asciiValue = value.asciiValue {
                return GenericMatcher<[UInt8]>(matcher: .single(asciiValue))
            } else {
                return nil
            }
            
        case .collection(let string):
            if string.allSatisfy({ $0.isASCII }) {
                return GenericMatcher<[UInt8]>(string.utf8Characters)
            } else {
                return nil
            }
        
        case .concatenation(let lhs, let rhs):
            if let oLHS = lhs.optimizedToASCII(), let oRHS = rhs.optimizedToASCII() {
                return oLHS + oRHS
            } else {
                return nil
            }
            
        case .or(let lhs, let rhs):
            if let oLHS = lhs.optimizedToASCII(), let oRHS = rhs.optimizedToASCII() {
                return oLHS || oRHS
            } else {
                return nil
            }
            
        case .repeated(let matcher, let min, let max, let maxIsIncluded):
            if let oMatcher = matcher.optimizedToASCII() {
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
            if let optimized = inverted.optimizedToASCII() {
                return !optimized
            } else {
                return nil
            }
            
        case .and(let lhs, let rhs):
            if let oLHS = lhs.optimizedToASCII(), let oRHS = rhs.optimizedToASCII() {
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


public enum MatcherKind {
    case standard(Matcher)
    case optimized(GenericMatcher<[UInt8]>)
}
