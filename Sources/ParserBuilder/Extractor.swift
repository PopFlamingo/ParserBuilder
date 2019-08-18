public struct Extractor {
    public init(_ string: String) {
        self.string = string
    }
    private let string: String
    public func matches(for matcher: Matcher) -> [Substring] {
        var matches = [Substring]()
        var currentIndex = string.startIndex
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
}
