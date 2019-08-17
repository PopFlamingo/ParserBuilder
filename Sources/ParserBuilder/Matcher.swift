struct Matcher: ExpressibleByStringLiteral, ExpressibleByArrayLiteral {
    
    init(stringLiteral value: String) {
        self.matcher = .string(value)
    }
    
    init(arrayLiteral elements: Matcher...) {
        self = .init(elements)
    }
    
    init(_ matcherArray: [Matcher]) {
        self = matcherArray.reduce(Matcher(""), ||)
    }
    
    init(_ matchedString: String) {
        self.matcher = .string(matchedString)
    }
    
    init(_ predicate: @escaping (Character)->Bool) {
        self.matcher = .predicate(predicate)
    }
    
    init(_ characterRange: ClosedRange<Character>) {
        self = .init { character in
            characterRange.contains(character)
        }
    }
    
    private init(matcher: InternalMatcher) {
        self.matcher = matcher
    }
    
    static func +(lhs: Matcher, rhs: Matcher) -> Matcher {
        return Matcher(matcher: .concatenation(lhs, rhs))
    }
    
    static func ||(lhs: Matcher, rhs: Matcher) -> Matcher {
        return Matcher(matcher: .or(lhs, rhs))
    }
    
    func advancedIndex<T: StringProtocol>(in string: T) -> String.Index? {
        switch self.matcher {
        case .string(let matchedString):
            guard matchedString != "" else {
                return string.startIndex
            }
            var index = matchedString.startIndex
            let prefixed = string.prefix { character in
                guard index < matchedString.endIndex else {
                    return false
                }
                if character == matchedString[index] {
                    defer {
                        index = matchedString.index(after: index)
                    }
                    return true
                } else {
                    return false
                }
            }
            return index != matchedString.endIndex ? nil : prefixed.endIndex
            
        case .predicate(let predicate):
            if let firstCharacter = string.first, predicate(firstCharacter) {
                return string.index(after: string.startIndex)
            } else {
                return nil
            }
            
        case .or(let lhs, let rhs):
            if let first = lhs.advancedIndex(in: string) {
                return first
            } else if let second = rhs.advancedIndex(in: string) {
                return second
            } else {
                return nil
            }
            
        case .concatenation(let first, let second):
            guard let firstIndex = first.advancedIndex(in: string), firstIndex < string.endIndex else {
                return nil
            }
            let secondIndex = second.advancedIndex(in: string[firstIndex...])
            return secondIndex != firstIndex ? secondIndex : nil
            
        case .repeated(let matcher, let min, let max, let maxIsIncluded):
            if let max = max, max == 0 {
                return nil
            }
            var currentIndex = string.startIndex
            var repeatCount = 0
            let actualMax: Int?
            if let max = max {
                actualMax = maxIsIncluded ? max : max-1
            } else {
                actualMax = nil
            }
            
            while currentIndex < string.endIndex, repeatCount != actualMax, let newIndex = matcher.advancedIndex(in: string[currentIndex...]) {
                currentIndex = newIndex
                repeatCount += 1
            }
            
            if let min = min {
                return (repeatCount >= min) ? currentIndex : nil
            } else {
                return currentIndex
            }
            
        }
    }
    
    func count(_ repeatRange: PartialRangeThrough<Int>) -> Matcher {
        precondition(repeatRange.upperBound >= 0)
        return Matcher(matcher: .repeated(self, nil, repeatRange.upperBound, true))
    }
    
    func count(_ repeatRange: PartialRangeFrom<Int>) -> Matcher {
        precondition(repeatRange.lowerBound >= 0)
        return Matcher(matcher: .repeated(self, repeatRange.lowerBound, nil, true))
    }
    
    func count(_ repeatRange: ClosedRange<Int>) -> Matcher {
        precondition(repeatRange.lowerBound >= 0 && repeatRange.upperBound >= 0)
        return Matcher(matcher: .repeated(self, repeatRange.lowerBound, repeatRange.upperBound, true))
    }
    
    func count(_ repeatRange: Range<Int>) -> Matcher {
        precondition(repeatRange.lowerBound >= 0 && repeatRange.upperBound >= 0)
        return Matcher(matcher: .repeated(self, repeatRange.lowerBound, repeatRange.upperBound, false))
    }
    
    func count(_ times: Int) -> Matcher {
        self.count(times...times)
    }
    
    func optional() -> Matcher {
        return self.count(0...1)
    }
    
    private let matcher: InternalMatcher
    
    private indirect enum InternalMatcher {
        case string(String)
        case predicate((Character)->Bool)
        case concatenation(Matcher, Matcher)
        case or(Matcher, Matcher)
        case repeated(Matcher, Int?, Int?, Bool)
    }
}
