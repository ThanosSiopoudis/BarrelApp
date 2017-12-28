//
//  RegexSwift.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 04/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Foundation

class Regex {
    let internalExpression:NSRegularExpression?
    let pattern:String
    
    init(_ pattern:String) {
        self.pattern = pattern;
        do {
            try self.internalExpression = NSRegularExpression(pattern: pattern, options: NSRegularExpressionOptions.CaseInsensitive);
        }
        catch {
            self.internalExpression = nil;
            print(error);
        }
    }
    
    func test(input:String) -> Bool {
        let matches = self.internalExpression!.matchesInString(input, options: [], range: NSMakeRange(0, input.characters.count));
        return matches.count > 0;
    }
}