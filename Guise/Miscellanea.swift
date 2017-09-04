//
//  Miscellanea.swift
//  Guise
//
//  Created by Gregory Higley on 9/3/17.
//  Copyright © 2017 Gregory Higley. All rights reserved.
//

import Foundation

public enum Name {
    case `default`
}

/**
 Used in filters and resolution.
 
 This type exists primarily to emphasize that the `metathunk` method should be applied to
 `Metafilter<M>` before the metafilter is passed to the master `filter` or `exists` method.
 */
typealias Metathunk = Metafilter<Any>

func metathunk<M>(_ metafilter: @escaping Metafilter<M>) -> Metathunk {
    return {
        guard let metadata = $0 as? M else { return false }
        return metafilter(metadata)
    }
}

/// Generates a hash value for one or more hashable values.
func hash<H: Hashable>(_ hashables: H...) -> Int {
    // djb2 hash algorithm: http://www.cse.yorku.ca/~oz/hash.html
    // &+ operator handles Int overflow
    return hashables.reduce(5381) { (result, hashable) in ((result << 5) &+ result) &+ hashable.hashValue }
}

infix operator ??= : AssignmentPrecedence

func ??=<T>(lhs: inout T?, rhs: @autoclosure () -> T?) {
    if lhs != nil { return }
    lhs = rhs()
}

extension Array {
    // https://stackoverflow.com/a/43107628/27779
    func dictionary<K: Hashable, V>() -> [K: V] where Element == Dictionary<K, V>.Element {
        var dictionary = [K: V]()
        for element in self {
            dictionary[element.key] = element.value
        }
        return dictionary
    }
}
