//
//  AppDelegate.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 23/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    enum BLErrorCodes:Int {
        case BLGamesFolderURLInvalid
    };
    
    @IBOutlet weak var window: NSWindow!
    var _gamesFolder:NSURL?
    var gamesFolderURL:NSURL? {
        get {
            if (self._gamesFolder == nil) {
                var returnVal:NSURL?
                var userDefaults:NSUserDefaults = NSUserDefaults.standardUserDefaults();
                var bookmarkData:NSData? = userDefaults.dataForKey("gamesFolderURLBookmark");
                if (bookmarkData != nil) {
                    var dataIsStale:ObjCBool = false;
                    var resolutionError:NSError? = nil;
                    var folderURL:NSURL? = NSURL.URLByResolvingBookmarkData(bookmarkData,
                        options: NSURLBookmarkResolutionOptions.WithoutUI,
                        relativeToURL: nil,
                        bookmarkDataIsStale: &dataIsStale,
                        error: &resolutionError);
                    
                    if (folderURL != nil) {
                        returnVal = folderURL?.fileReferenceURL()?.copy() as? NSURL;
                        
                        if (dataIsStale) {
                            var updatedBookmarkData:NSData? = folderURL?.bookmarkDataWithOptions(NSURLBookmarkCreationOptions.allZeros,
                                includingResourceValuesForKeys: nil,
                                relativeToURL: nil,
                                error: nil
                            );
                            if (updatedBookmarkData != nil) {
                                userDefaults.setObject(updatedBookmarkData!, forKey: "gamesFolderURLBookmark");
                            }
                        }
                    }
                }
                self._gamesFolder = returnVal;
            }
            
            return self._gamesFolder;
        }
        set {
            var newURL:NSURL? = newValue?.fileReferenceURL();
            if (newURL != self._gamesFolder) {
                self.willChangeValueForKey("gamesFolderURL");
                self._gamesFolder = newURL?.fileReferenceURL();
                self.didChangeValueForKey("gamesFolderURL");
                
                // Store the value in NSUserDefaults
                if (newURL != nil) {
                    var bookmarkData:NSData? = newURL?.bookmarkDataWithOptions(NSURLBookmarkCreationOptions.allZeros,
                        includingResourceValuesForKeys: nil,
                        relativeToURL: nil,
                        error: nil
                    );
                    
                    if (bookmarkData != nil) {
                        NSUserDefaults.standardUserDefaults().setObject(bookmarkData!, forKey: "gamesFolderURLBookmark");
                    }
                }
            }
        }
    }
    
    override class func initialize() {
        AppDelegate.prepareValueTransformers();
    }
    
    override init() {
        super.init();
    }
    
    func applicationWillFinishLaunching(notification: NSNotification!) {
        if (self.gamesFolderURL == nil && self.gamesFolderChosen() == false) {
            var defaultURL:NSURL = AppDelegate.preferredGamesFolderURL();
            var nilError:NSError? = nil;
            self.assignGamesFolderURL(defaultURL, addSampleGames: true, createIfMissing: true, outError: &nilError);
        }
    }

    class func prepareValueTransformers() {
        let pathTransformer:BLIconifiedDisplayPathTransformer = BLIconifiedDisplayPathTransformer(joiner: " ▸ ", ellipsis: "",  maxComponents: 0);
        pathTransformer.missingFileIcon = NSImage(named: "gamefolder");
        pathTransformer.hidesSystemRoots = true;
        
        var pathStyle:NSMutableParagraphStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as NSMutableParagraphStyle;
        pathStyle.lineBreakMode = NSLineBreakMode.ByTruncatingMiddle;
        pathTransformer.textAttributes?.setObject(pathStyle, forKey: NSParagraphStyleAttributeName);
        NSValueTransformer.setValueTransformer(pathTransformer, forName: "BLIconifiedGamesFolderPath");
    }
    
    // MARK: - Type Methods
    class func preferredGamesFolderURL() -> NSURL {
        return self.commonGamesFolderURLs()[0] as NSURL;
    }
    
    class func commonGamesFolderURLs() -> NSArray {
        var URLs:NSArray? = nil;
        var onceToken:dispatch_once_t = 0
        dispatch_once(&onceToken, {
            var defaultName:NSString = "Windows Games";
            var manager:NSFileManager = NSFileManager.defaultManager();
            
            var homeURL:NSURL = NSURL(fileURLWithPath: NSHomeDirectory());
            var docsURL:NSURL = manager.URLsForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask)[0] as NSURL;
            var userAppURL:NSURL = manager.URLsForDirectory(NSSearchPathDirectory.ApplicationDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask)[0] as NSURL;
            var appURL:NSURL = manager.URLsForDirectory(NSSearchPathDirectory.ApplicationDirectory, inDomains: NSSearchPathDomainMask.LocalDomainMask)[0] as NSURL;
            
            URLs = [
                homeURL.URLByAppendingPathComponent(defaultName),
                docsURL.URLByAppendingPathComponent(defaultName),
                userAppURL.URLByAppendingPathComponent(defaultName),
                appURL.URLByAppendingPathComponent(defaultName)
            ];
        });
        
        return URLs!;
    }
    
    class func reservedURLs() -> NSSet {
        var reservedURLs:NSMutableSet? = nil;
        var onceToken:dispatch_once_t = 0;
        dispatch_once(&onceToken, {
            var manager:NSFileManager = NSFileManager.defaultManager();
            if let homeURLs = NSURL.fileURLWithPath(NSHomeDirectory()) {
                reservedURLs = NSMutableSet(objects: homeURLs);
            }
            
            let NUM_DIRS = 7;
            let reservedDirs:[NSSearchPathDirectory] = [
                NSSearchPathDirectory.DocumentDirectory,
                NSSearchPathDirectory.AllApplicationsDirectory,
                NSSearchPathDirectory.AllLibrariesDirectory,
                NSSearchPathDirectory.DesktopDirectory,
                NSSearchPathDirectory.DownloadsDirectory,
                NSSearchPathDirectory.UserDirectory,
                NSSearchPathDirectory.SharedPublicDirectory
            ];
            
            for var i = 0; i < NUM_DIRS; i++ {
                var searchURLs:NSArray = manager.URLsForDirectory(reservedDirs[i], inDomains: NSSearchPathDomainMask.AllDomainsMask);
                reservedURLs?.addObjectsFromArray(searchURLs);
            }
        });
        
        return reservedURLs!;
    }
    
    private class func _isReservedURL(URL:NSURL) -> Bool {
        // Reject reserved paths
        if (AppDelegate.reservedURLs().containsObject(URL)) {
            return true;
        }
        
        var manager:NSFileManager = NSFileManager.defaultManager();
        
        // Reject paths located inside system library folders (though we allow them within the user's own Library folder)
        var libraryURLs:NSArray = manager.URLsForDirectory(NSSearchPathDirectory.AllLibrariesDirectory,
                                                            inDomains: NSSearchPathDomainMask.LocalDomainMask | NSSearchPathDomainMask.SystemDomainMask);
        for libraryURL in libraryURLs {
            if (URL.isBasedInURL(libraryURL as? NSURL)) {
                return true;
            }
        }
        
        // Reject base home folder paths (though accept any folder withing them, of course)
        var userDirectoryURLs = manager.URLsForDirectory(NSSearchPathDirectory.UserDirectory, inDomains: NSSearchPathDomainMask.AllDomainsMask);
        var parentURL = URL.URLByDeletingLastPathComponent!;
        for userDirectoryURL in userDirectoryURLs {
            if (parentURL.isEqual(userDirectoryURL)) {
                return true;
            }
        }
        
        return false;
    }
    
    class func keyPathsForValuesAffectingGamesFolderIcon() -> NSSet! {
        return NSSet(objects: "gamesFolderURL");
    }
    
    override class func automaticallyNotifiesObserversForKey(key: String!) -> Bool {
        return true;
    }
    
    func gamesFolderChosen() -> Bool {
        var defaults:NSUserDefaults = NSUserDefaults.standardUserDefaults();
        if (defaults.dataForKey("gamesFolderURLBookmark") != nil) {
            return true;
        }
        
        if (defaults.dataForKey("gamesFolder") != nil) {
            return true;
        }
        
        return false;
    }

    func assignGamesFolderURL(URL:NSURL?, addSampleGames:Bool, createIfMissing:Bool, inout outError:NSError?) -> Bool {
        assert(URL != nil, "nil URL provided to assignGamesFolderURL:addSampleGames:createIfMissing:error:");
        
        var theURL = URL!;
        
        var reachabilityError:NSError? = nil;
        if (!theURL.checkResourceIsReachableAndReturnError(&reachabilityError)) {
            if (createIfMissing) {
                var created:Bool = NSFileManager.defaultManager().createDirectoryAtURL(theURL, withIntermediateDirectories: true, attributes: nil, error: &outError);
                if (!created) {
                    return false;
                }
            }
            else {
                if (outError != nil) {
                    outError = reachabilityError;
                }
                return false;
            }
        }
        
        var isValid:Bool = self.validateGamesFolderURL(&theURL, outError: &outError);
        if (!isValid) {
            return false;
        }
        
        // If we got this far, we can go ahead and assign this as our games folder path.
        // Apply the requested options now
        if (addSampleGames) {
            // Add the sample games here
        }
        
        self.gamesFolderURL = URL;
        return true;
    }
    
    func promptForMissingGamesFolderInWindow(window:NSWindow?) {
        var alert:NSAlert = NSAlert();
        alert.messageText = "Barrel can no longer find your games folder."
        alert.informativeText = "Make sure the disk containing your games folder is connected";
        alert.addButtonWithTitle("Locate folder…");
        
        var cancelButton:NSButton = alert.addButtonWithTitle("Cancel");
        cancelButton.keyEquivalent = "\\e";
        
        if (window != nil) {
            alert.beginSheetModalForWindow(window, completionHandler: {(returnCode:NSModalResponse) -> Void in
                if (returnCode == NSAlertFirstButtonReturn) {
                    alert.window.orderOut(self);
                    BLGamesFolderPanelController.controller()?.showGamesFolderPanelWindow(window);
                }
            });
        }
    }
    
    func revealURLsInFinder(URLs:NSArray) -> Bool {
        var revealedAnyFiles:Bool = false;
        var ws:NSWorkspace = NSWorkspace.sharedWorkspace();
        
        var safeURLs:NSMutableArray = NSMutableArray(capacity: URLs.count);
        for val in URLs {
            let URL:NSURL = val as NSURL;
            if (URL.checkResourceIsReachableAndReturnError(nil)) {
                var parentURL:NSURL? = URL.URLByDeletingLastPathComponent!;
                var parentIsPackage:Bool? = parentURL?.resourceValueForKey(NSURLIsPackageKey)?.boolValue!
                if (parentIsPackage!) {
                    if (URL.isDirectory()!) {
                        var options:NSDirectoryEnumerationOptions = NSDirectoryEnumerationOptions.SkipsHiddenFiles | NSDirectoryEnumerationOptions.SkipsSubdirectoryDescendants;
                        var enumerator:NSDirectoryEnumerator = NSFileManager.defaultManager().enumeratorAtURL(URL,
                            includingPropertiesForKeys: nil,
                            options: options,
                            errorHandler: nil
                        );
                        
                        var childURL:NSURL? = enumerator.nextObject() as? NSURL;
                        if (childURL != nil) {
                            safeURLs.addObject(childURL!);
                            continue;
                        }
                    }
                    
                    revealedAnyFiles = ws.selectFile(URL.path!, inFileViewerRootedAtPath: parentURL?.path!) || revealedAnyFiles;
                }
                else {
                    safeURLs.addObject(URL);
                    revealedAnyFiles = true;
                }
            }
        }
        
        if (safeURLs.count > 0) {
            ws.activateFileViewerSelectingURLs(safeURLs);
        }
        
        return revealedAnyFiles;
    }
    
    func validateGamesFolderURL(inout ioValue:NSURL, inout outError:NSError?) -> Bool {
        var URL:NSURL? = ioValue;
        
        // Accept nil paths, since these will clear the preference
        if (URL == nil) {
            return true;
        }
        
        URL = URL?.URLByStandardizingPath;
        
        if (AppDelegate._isReservedURL(URL!)) {
            if (outError != nil) {
                var displayName:AnyObject?
                
                URL?.getResourceValue(&displayName, forKey: NSURLLocalizedNameKey, error: nil);
                if (displayName == nil) {
                    displayName = URL?.lastPathComponent;
                }
                
                var description:String = "\(displayName) is a special OS X folder and not suitable for storing your Windows games.";
                var userInfo:NSDictionary = [
                    NSLocalizedDescriptionKey: description,
                    NSLocalizedRecoverySuggestionErrorKey: "Please create a subfolder, or choose a different folder your have created yourself",
                    NSURLErrorKey: URL!
                ];
                
                outError = NSError.errorWithDomain("BLGamesFolderErrorDomain", code: BLErrorCodes.BLGamesFolderURLInvalid.toRaw(), userInfo: userInfo);
            }
            
            return false;
        }
        
        // Warn if we do not currently have write permission to access that URL
        var writeableFlag:AnyObject?
        URL?.getResourceValue(&writeableFlag, forKey: NSURLIsWritableKey, error: nil);
        
        if (!writeableFlag!.boolValue) {
            if (outError != nil) {
                var displayName:AnyObject?
                
                URL?.getResourceValue(&displayName, forKey: NSURLLocalizedNameKey, error: nil);
                if (displayName == nil) {
                    displayName = URL?.lastPathComponent;
                }
                
                var description:String = "Barrel cannot write to the \(displayName)folder.";
                var userInfo:NSDictionary = [
                    NSLocalizedDescriptionKey: description,
                    NSLocalizedRecoverySuggestionErrorKey: "Please check the file permissions, or choose a different folder.",
                    NSURLErrorKey: URL!
                ];
                
                outError = NSError.errorWithDomain(NSCocoaErrorDomain, code: NSFileWriteNoPermissionError, userInfo: userInfo);
            }
            
            return false;
        }
        
        // If we got this far, the URL is OK
        return true;
    }
}

