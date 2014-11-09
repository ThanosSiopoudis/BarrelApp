//
//  BLInstallerScan.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 22/09/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class BLInstallerScan: NSObject {
    let BLFileScanLastMatch:String = "BLFileScanLastMatch";
    
    var windowsExecutables:NSArray!
    var BarrelConfigurations:NSArray!
    var MacOSApps:NSArray!
    var isAlreadyInstalled:Bool!
    var skipHiddenFiles:Bool!
    var predicate:NSPredicate?
    var filetypes:NSSet?
    var basePath:String!
    var workspace:NSWorkspace!
    var matchingPaths:NSMutableArray!
    var maxMatches:NSInteger!
    
    override init() {
        self.windowsExecutables = NSMutableArray(capacity: 10);
        self.MacOSApps = NSMutableArray(capacity: 10);
        self.BarrelConfigurations = NSMutableArray(capacity: 10);
        self.isAlreadyInstalled = false;
        self.skipHiddenFiles = true;
        self.basePath = "";
        self.workspace = NSWorkspace();
        self.matchingPaths = NSMutableArray();
        self.maxMatches = 0;
        
        super.init();
    }
    
    class func scanWithBasePath(path:String) -> AnyObject {
        var scan:BLInstallerScan = BLInstallerScan();
        scan.basePath = path;
        
        return scan;
    }
    
    func lastMatch() -> String {
        return self.matchingPaths.lastObject as String;
    }
    
    func fullPathFromRelativePath(relativePath:String) -> String {
        return self.basePath.stringByAppendingPathComponent(relativePath);
    }
    
    func isMatchingPath(relativePath:String) -> Bool {
        if (self.skipHiddenFiles == true && relativePath.lastPathComponent.hasPrefix(".") == true) {
            return false;
        }
        
        if let pred = self.predicate {
            if (pred.evaluateWithObject(relativePath) == false) {
                return false;
            }
        }
        else {
            return false;
        }
        
        if let ft = self.filetypes {
            var fullPath:String = self.fullPathFromRelativePath(relativePath);
            if (!workspace.fileMatchesTypes(fullPath, acceptedTypes: self.filetypes!)) {
                return false;
            }
        }
        
        return true;
    }
    
    func matchAgainstPath(relativePath:NSString) -> Bool {
        if (self.isMatchingPath(relativePath)) {
            self.addMatchingPath(relativePath);
            
            var userInfo:NSDictionary = NSDictionary(object: self.lastMatch(), forKey: self.BLFileScanLastMatch);
            
            // TODO: Send progress notification here!?
            
            // Check if we have enough matches
            if (self.maxMatches > 0 && self.matchingPaths.count >= self.maxMatches) {
                return false;
            }
        }
        
        return true;
    }
    
    func addMatchingPath(relativePath:String) {
        self.mutableArrayValueForKey("matchingPaths").addObject(relativePath);
    }
}
