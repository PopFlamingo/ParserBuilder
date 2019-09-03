public struct Extractor {
    @inlinable
    public init(_ string: String) {
        var contiguousString = string
        contiguousString.makeContiguousUTF8()
        self._string = contiguousString
        self._currentIndex = string.startIndex
        self.utf8Index = 0
    }
    
    public var string: String {
        _string
    }
    
    public var _string: String
    
    @usableFromInline
    var _currentIndex: String.Index
    
    @usableFromInline
    var utf8Index: Int
    
    @inlinable
    public var currentIndex: String.Index {
        _currentIndex
    }
    
    @inlinable
    mutating public func matches(for matcher: Matcher) -> [Substring] {
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
    public mutating func peekCurrent(with matcher: Matcher) -> Substring? {
        guard _currentIndex < _string.endIndex else {
            return nil
        }
        let endIndex = _string.endIndex
        if let endIndex = matcher.advancedIndex(in: _string, range: _currentIndex..<endIndex) {
            return _string[_currentIndex..<endIndex]
        } else {
            return nil
        }
    }
    
    @discardableResult
    @inlinable
    public mutating func popCurrent(with matcher: Matcher) -> Substring? {
        guard _currentIndex < _string.endIndex else {
            return nil
        }
        
        if let optimized = matcher.optimized.value {
            let endIndex = _string.withUTF8 { buffer -> Int? in
                let endIndex = buffer.endIndex
                if let endIndex = optimized.advancedIndex(in: buffer, range: utf8Index..<endIndex) {
                    return endIndex
                } else {
                    return nil
                }
            }
            
            if let endIndex = endIndex {
                let converted = string.utf8.index(string.utf8.startIndex, offsetBy: endIndex)
                defer {
                    self.utf8Index = endIndex
                    self._currentIndex = converted
                }
                return string[currentIndex..<converted]
            } else {
                return nil
            }
            
        } else {
            let endIndex = _string.endIndex
            if let endIndex = matcher.advancedIndex(in: _string, range: _currentIndex..<endIndex) {
                defer {
                    _currentIndex = endIndex
                    utf8Index = string.utf8.distance(from: string.startIndex, to: _currentIndex)
                }
                
                return _string[_currentIndex..<endIndex]
            } else {
                return nil
            }
        }
        
    }
}
