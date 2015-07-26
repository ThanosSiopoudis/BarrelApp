//
//  BLInstallerScan.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 22/09/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class BLInstallerScan: BLOperation {
    let BLFileScanLastMatch:String = "BLFileScanLastMatch";
    
    var windowsExecutables:NSMutableArray!
    var BarrelConfigurations:NSMutableArray!
    var MacOSApps:NSMutableArray!
    var isAlreadyInstalled:Bool!
    var skipHiddenFiles:Bool!
    var skipSubdirectories:Bool!
    var skipPackageContents:Bool!
    var predicate:NSPredicate?
    var filetypes:NSSet?
    var basePath:String!
    var workspace:NSWorkspace!
    var matchingPaths:NSMutableArray!
    var maxMatches:NSInteger!
    var manager:NSFileManager?
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
        self.BarrelConfigurations = NSMutableArray(capacity: 10);
        self.isAlreadyInstalled = false;
        self.skipHiddenFiles = true;
        self.skipSubdirectories = false;
        self.skipPackageContents = true;
        self.basePath = "";
        self.workspace = NSWorkspace();
        self.matchingPaths = NSMutableArray();
        self.maxMatches = 0;
        self.manager = NSFileManager();
        
        super.init();
    }
    
    class func scanWithBasePath(path:String) -> AnyObject {
        var scan:BLInstallerScan = BLInstallerScan();
        scan.basePath = path;
        
        return scan;
    }
    
    func lastMatch() -> String {
        return self.matchingPaths.lastObject as! String;
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
        if (self.isMatchingPath(relativePath as String)) {
            if (BLImportSession.isIgnoredFileAtPath(relativePath as String)) {
                return true;
            }
            
            var fullPath:String = self.fullPathFromRelativePath(relativePath as String);
            
            // TODO: Check for Barrel Configuration files here to detect if this is a bundle already
            if (self.isAlreadyInstalled == false && BLImportSession.isPlayableGameTelltaleAtPath(relativePath as String)) {
                self.isAlreadyInstalled = true;
            }
            
            var executableTypes:NSSet? = BLFileTypes.executableTypes();
            var macAppTypes:NSSet? = BLFileTypes.macOSAppTypes();
            
            if (self.workspace.file(fullPath, matchesTypes: executableTypes!)) {
                if (self.workspace.isCompatibleExecutableAtPath(fullPath)) {
                    self.addWindowsExecutable(relativePath as String);
                    
                    // Does it look like an installer? Add it to the matches
                    if (BLImportSession.isInstallerAtPath(relativePath as String)) {
                        self.addMatchingPath(relativePath as String);
                        
                        let userInfo:NSDictionary = [self.lastMatch(): BLFileScanLastMatch];
                        self.sendInProgressNotificationWithInfo(userInfo);
                    }
                }
            }
            else if (self.workspace.file(fullPath, matchesTypes: macAppTypes!)) {
                self.addMacOSApp(relativePath as String);
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
            if (self.isOperationCancelled) {
                break;
            }
            
            var fileType:String = enumer.fileAttributes!["NSFileType"] as! String;
            if (fileType == NSFileTypeDirectory) {
                if (self.shouldScanSubPath(relPath) == false) {
                    enumer.skipDescendants();
                }
            }
            
            var keepScanning:Bool = self.matchAgainstPath(relPath);
            if (self.isOperationCancelled == true || keepScanning == false) {
                break;
            }
        }
    }
}
