//
//  BLExecutableScan.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 13/03/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Cocoa

class BLExecutableScan: BLOperation {
    let BLExecutableScanLastMatch:String = "BLExecutableScanLastMatch";
    
    var windowsExecutables:NSMutableArray!
    var MacOSApps:NSMutableArray!
    var skipHiddenFiles:Bool!
    var skipSubdirectories:Bool!
    var skipPackageContents:Bool!
    var matchingPaths:NSMutableArray!
    var basePath:String!
    var manager:NSFileManager?
    var predicate:NSPredicate?
    var filetypes:NSSet?
    var workspace:NSWorkspace!
    var previousExecutablesArray:NSArray?
    var enumerator:NSDirectoryEnumerator? {
        get {
            return self.manager?.enumeratorAtPath(self.basePath);
        }
    }
    var recommendedSourcePath:String {
        get {
            // Just return the base path for now
            // Will need to return the mounter image volume in the future
            // when we implement image mounting support
            return self.basePath;
        }
    }
    
    override init() {
        self.windowsExecutables = NSMutableArray(capacity: 10);
        self.MacOSApps = NSMutableArray(capacity: 10);
        self.skipHiddenFiles = true;
        self.skipSubdirectories = false;
        self.skipPackageContents = true;
        self.matchingPaths = NSMutableArray();
        self.manager = NSFileManager();
        self.workspace = NSWorkspace();
        
        super.init();
    }
    
    class func scanWithBasePath(path:String) -> AnyObject {
        var scan:BLExecutableScan = BLExecutableScan();
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
            if (BLImportSession.isIgnoredFileAtPath(relativePath)) {
                return true;
            }
        
            var fullPath:String = self.fullPathFromRelativePath(relativePath);
            var executableTypes:NSSet? = BLFileTypes.executableTypes();
            
            if (self.workspace.file(fullPath, matchesTypes: executableTypes!)) {
                if (self.workspace.isCompatibleExecutableAtPath(fullPath)) {
                    // Make sure this isn't in the old executables list
                    if let oldsArray = self.previousExecutablesArray {
                        for oldPathVar in oldsArray {
                            let oldPath = oldPathVar as String;
                            if (relativePath.lastPathComponent != oldPath.lastPathComponent) {
                                self.addWindowsExecutable(relativePath);
                                self.addMatchingPath(relativePath);
                                
                                let userInfo:NSDictionary = [self.lastMatch(): BLExecutableScanLastMatch];
                                self.sendInProgressNotificationWithInfo(userInfo);
                            }
                        }
                    }
                    else {
                        self.addWindowsExecutable(relativePath);
                        self.addMatchingPath(relativePath);
                        
                        let userInfo:NSDictionary = [self.lastMatch(): BLExecutableScanLastMatch];
                        self.sendInProgressNotificationWithInfo(userInfo);
                    }
                }
            }
        }
        
        return true;
    }
    
    func addMatchingPath(relativePath:String) {
        self.mutableArrayValueForKey("matchingPaths").addObject(relativePath);
    }
    
    func addWindowsExecutable(relativePath:String) {
        self.mutableArrayValueForKey("windowsExecutables").addObject(relativePath);
    }
    
    func addMacOSApp(relativePath:String) {
        self.mutableArrayValueForKey("MacOSApps").addObject(relativePath);
    }
    
    func shouldScanSubPath(relativePath:String) -> Bool {
        if (self.skipSubdirectories == true) {
            return false;
        }
        
        if (self.skipPackageContents == true) {
            let fullPath:String = self.fullPathFromRelativePath(relativePath);
            if (self.workspace.isFilePackageAtPath(fullPath) == true) {
                return false;
            }
        }
        
        return true;
    }
    
    override func main() {
        assert(self.basePath != nil, "No base path provided for file scan operation");
        if (self.basePath == nil) {
            return;
        }
        
        self.matchingPaths.removeAllObjects();
        
        var enumer:NSDirectoryEnumerator = self.enumerator!;
        while let relativePath = enumer.nextObject() as? String {
            let relPath:String = relativePath as String;
            if (self.isCancelled) {
                break;
            }
            
            var fileType:String = enumer.fileAttributes!["NSFileType"] as String;
            if (fileType == NSFileTypeDirectory) {
                if (self.shouldScanSubPath(relPath) == false) {
                    enumer.skipDescendants();
                }
            }
            
            var keepScanning:Bool = self.matchAgainstPath(relPath);
            if (self.isCancelled == true || keepScanning == false) {
                break;
            }
        }
    }
}
