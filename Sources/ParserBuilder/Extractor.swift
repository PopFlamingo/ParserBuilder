public struct Extractor {
    public init(_ string: String) {
        self.string = string
        self.currentIndex = string.startIndex
    }
    private let string: String
    private var currentIndex: String.Index
    mutating public func matches(for matcher: Matcher) -> [Substring] {
        var matches = [Substring]()
        while currentIndex < string.endIndex {
            if let nextIndex = matcher.advancedIndex(in: string[currentIndex...]) {
                matches.append(string[currentIndex..<nextIndex])
                currentIndex = nextIndex
            } else {
                currentIndex = string.index(after: currentIndex)
            }
        }
        return matches
    }
    
    public mutating func peekCurrent(with matcher: Matcher) -> Substring? {
        guard currentIndex < string.endIndex else {
            return nil
        }
        if let endIndex = matcher.advancedIndex(in: string[currentIndex...]) {
            return string[currentIndex..<endIndex]
        } else {
            return nil
        }
    }
    
    @discardableResult
    public mutating func popCurrent(with matcher: Matcher) -> Substring? {
        guard currentIndex < string.endIndex else {
            return nil
        }
        if let endIndex = matcher.advancedIndex(in: string[currentIndex...]) {
            defer {
                currentIndex = endIndex
            }
            return string[currentIndex..<endIndex]
        } else {
            return nil
        }
    }
}
