//
//  NSURL+NSURLExtensions.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 26/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Foundation

extension NSURL {
    func isBasedInURL(baseURL:NSURL?) -> Bool {
        if (baseURL == nil) {
            return false;
        }

        var basePath:String? = baseURL?.URLByStandardizingPath?.path;
        var originalPath:String? = self.URLByStandardizingPath?.path;

        var bPath = basePath!
        var oPath = originalPath!;

        if (oPath == bPath) {
            return true;
        }

        if (bPath.hasSuffix("/") == false) {
            bPath = bPath.stringByAppendingString("/");
        }

        if (oPath.hasSuffix("/") == false) {
            oPath = oPath.stringByAppendingString("/");
        }

        return oPath.hasPrefix(bPath);
    }

    func resourceValueForKey(key:String) -> AnyObject? {
        var value:AnyObject?
        var retrieved:Bool = self.getResourceValue(&value, forKey: key, error: nil);
        if (retrieved) {
            return value
        }
        else {
            return nil;
        }
    }

    func isDirectory() -> Bool? {
        return self.resourceValueForKey(NSURLIsDirectoryKey)?.boolValue;
    }
}