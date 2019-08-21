public struct Extractor {
    @inlinable
    public init(_ string: String) {
        var contiguousString = string
        contiguousString.makeContiguousUTF8()
        self.string = contiguousString
        self.currentIndex = string.startIndex
    }
    @usableFromInline
    let string: String
    @usableFromInline
    var currentIndex: String.Index
    
    @inlinable
    mutating public func matches(for matcher: Matcher) -> [Substring] {
        var matches = [Substring]()
        while currentIndex < string.endIndex {
            if let nextIndex = matcher.advancedIndex(in: string, range: currentIndex...string.index(before: string.endIndex)) {
                matches.append(string[currentIndex..<nextIndex])
                currentIndex = nextIndex
            } else {
                currentIndex = string.index(after: currentIndex)
            }
        }
        return matches
    }
    @inlinable
    public mutating func peekCurrent(with matcher: Matcher) -> Substring? {
        guard currentIndex < string.endIndex else {
            return nil
        }
        if let endIndex = matcher.advancedIndex(in: string, range: currentIndex...string.index(before: string.endIndex)) {
            return string[currentIndex..<endIndex]
        } else {
            return nil
        }
    }
    
    @discardableResult
    @inlinable
    public mutating func popCurrent(with matcher: Matcher) -> Substring? {
        guard currentIndex < string.endIndex else {
            return nil
        }
        if let endIndex = matcher.advancedIndex(in: string, range: currentIndex...string.index(before: string.endIndex)) {
            defer {
                currentIndex = endIndex
            }
            return string[currentIndex..<endIndex]
        } else {
            return nil
        }
    }
}
