//
//  String+StringAdditions.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 26/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Foundation

extension String {
    var ns: NSString {
        return self as NSString
    }
    var pathExtension: String {
        return ns.pathExtension
    }
    var lastPathComponent: String {
        return ns.lastPathComponent
    }
    var pathComponents: NSArray {
        return ns.pathComponents;
    }
    func stringByAppendingPathComponent(str: String) -> String {
        return ns.stringByAppendingPathComponent(str);
    }
    func fullPathComponents() -> NSArray {
        if (self.characters.count < 1) {
            return NSArray();
        }

        var path:String = NSURL(fileURLWithPath: self).URLByStandardizingPath!.path!;
        var rootPath:String = "/";

        var paths:NSMutableArray = NSMutableArray(capacity: 10);
        repeat {
            paths.addObject(path);
            path = NSURL(fileURLWithPath: path).URLByDeletingLastPathComponent!.path!;
        }
        while (path.characters.count > 0 && path != rootPath);

        // Reverse the array to put the components back in their original order
        var reverse:NSArray = paths.reverseObjectEnumerator().allObjects;
        return reverse;
    }
}