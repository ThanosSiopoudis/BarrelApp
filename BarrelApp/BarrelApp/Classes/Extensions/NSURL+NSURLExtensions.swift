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
        do {
            try self.getResourceValue(&value, forKey: key);
            return value;
        }
        catch {
            return nil;
        }
    }

    func isDirectory() -> Bool? {
        return self.resourceValueForKey(NSURLIsDirectoryKey)?.boolValue;
    }
    
    func URLsByAppendingPaths(paths:NSArray) -> NSArray {
        var URLs:NSMutableArray = NSMutableArray(capacity: paths.count);
        
        for pathComponent in paths {
            if let pComponent:String = pathComponent as? String {
                var URL:NSURL = self.URLByAppendingPathComponent(pComponent);
                URLs.addObject(URL);
            }
        }
        
        return URLs;
    }
    
    func pathRelativeToURL(baseURL:NSURL) -> String {
        let newBaseURL  = baseURL.URLByStandardizingPath;
        let originalURL = self.URLByStandardizingPath;
        
        if (originalURL!.isBasedInURL(baseURL)) {
            var prefixLength = baseURL.path!.characters.count;
            var originalPath:NSString = originalURL!.path! as NSString;
            var relativePath:NSString = originalPath.substringFromIndex(prefixLength);
            
            if (relativePath.hasPrefix("/")) {
                relativePath = relativePath.substringFromIndex(1);
                
                return relativePath as String;
            }
        }
        else {
            var components:NSArray!     = originalURL!.pathComponents
            var baseComponents:NSArray! = baseURL.pathComponents
            var numInOriginal:Int       = components.count;
            var numInBase:Int           = baseComponents.count;
            var from:Int, upTo:Int      = min(numInBase, numInOriginal);
            
            // Skip over any common prefixes
            for (from = 0; from < upTo; from++) {
                if ((components.objectAtIndex(from) as! String) != (baseComponents.objectAtIndex(from) as! String)) {
                    break;
                }
            }
            
            var i:Int, stepsBack:Int = (numInBase - from);
            var relativeComponents:NSMutableArray = NSMutableArray(capacity: (stepsBack + numInOriginal - from));
            // First, add the steps to get back from the first common directory
            for (i = 0; i < stepsBack; i++) {
                relativeComponents.addObject("..");
            }
            
            // Then, add the steps from there to the original path
            relativeComponents.addObjectsFromArray(components.subarrayWithRange(NSMakeRange(from, numInOriginal - from)));
            
            return NSString.pathWithComponents(relativeComponents as NSArray as! [String]) as String;
        }
        
        // Apparently, swift is not smart enough to understand that all code paths above DO return a value.
        return "";
    }
}