public struct Extractor {
    @inlinable
    public init(_ string: String) {
        var contiguousString = string
        contiguousString.makeContiguousUTF8()
        self.string = contiguousString
        self._currentIndex = string.startIndex
    }
    public let string: String
    
    @usableFromInline
    var _currentIndex: String.Index
    
    @inlinable
    public var currentIndex: String.Index {
        _currentIndex
    }
    
    @inlinable
    mutating public func matches(for matcher: GenericMatcher<String>) -> [Substring] {
        var matches = [Substring]()
        let endIndex = string.endIndex
        while _currentIndex < string.endIndex {
            if let nextIndex = matcher.advancedIndex(in: string, range: _currentIndex..<endIndex) {
                matches.append(string[_currentIndex..<nextIndex])
                _currentIndex = nextIndex
            } else {
                _currentIndex = string.index(after: _currentIndex)
            }
        }
        return matches
    }
    @inlinable
    public mutating func peekCurrent(with matcher: GenericMatcher<String>) -> Substring? {
        guard _currentIndex < string.endIndex else {
            return nil
        }
        let endIndex = string.endIndex
        if let endIndex = matcher.advancedIndex(in: string, range: _currentIndex..<endIndex) {
            return string[_currentIndex..<endIndex]
        } else {
            return nil
        }
    }
    
    @discardableResult
    @inlinable
    public mutating func popCurrent(with matcher: GenericMatcher<String>) -> Substring? {
        guard _currentIndex < string.endIndex else {
            return nil
        }
        let endIndex = string.endIndex
        if let endIndex = matcher.advancedIndex(in: string, range: _currentIndex..<endIndex) {
            defer {
                _currentIndex = endIndex
            }
            return string[_currentIndex..<endIndex]
        } else {
            return nil
        }
    }
}
