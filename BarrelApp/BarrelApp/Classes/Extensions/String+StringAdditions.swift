//
//  String+StringAdditions.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 26/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Foundation

extension String {
    func fullPathComponents() -> NSArray {
        if (count(self) < 1) {
            return NSArray();
        }

        var path:String = self.stringByStandardizingPath;
        var rootPath:String = "/";

        var paths:NSMutableArray = NSMutableArray(capacity: 10);
        do {
            paths.addObject(path);
            path = path.stringByDeletingLastPathComponent;
        }
        while (count(path) > 0 && path != rootPath);

        // Reverse the array to put the components back in their original order
        var reverse:NSArray = paths.reverseObjectEnumerator().allObjects;
        return reverse;
    }
}