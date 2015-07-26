//
//  RegexSwift.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 04/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Foundation

class Regex {
    let internalExpression:NSRegularExpression
    let pattern:String
    
    init(_ pattern:String) {
        self.pattern = pattern;
        var error:NSError?
        self.internalExpression = NSRegularExpression(pattern: pattern, options: NSRegularExpressionOptions.CaseInsensitive, error: &error)!
    }
    
    func test(input:String) -> Bool {
        let matches = self.internalExpression.matchesInString(input, options: nil, range: NSMakeRange(0, count(input)));
        return matches.count > 0;
    }
}