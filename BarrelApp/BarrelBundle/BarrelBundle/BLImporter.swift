//
//  BLImporter.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 03/09/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class BLImporter:NSObject, BLOperationDelegate {
    var didMountSourceVolume:Bool = false;
    var sourceURL:NSURL?
    var importWindowController:NSWindowController?
    var scanQueue:NSOperationQueue?
    dynamic var installerURLs:NSArray = NSArray();
    dynamic var enginesList:NSArray = NSArray();
    var test:String = "Uninitialised";
    
    // MARK: Enum Types
    enum BLImportStage:Int {
        case BLImportWaitingForSource = 0
        case BLImportLoadingSource = 1
        case BLImportReadyToFetchEnginesList = 2
        case BLImportWaitingForInstaller = 3
        case BLImportReadyToLaunchInstaller = 4
        case BLImportRunningInstaller = 5
        case BLImportReadyToLookupRecipe = 6
        case BLImportSearchingForRecipe = 7
        case BLImportDownloadingRecipe = 8
        case BLImportReadyToDownloadEngine = 9
        case BLImportDownloadingEngine = 10
        case BLImportReadyToDownloadWinetricks = 11
        case BLImportDownloadingWinetricks = 12
        case BLImportReadyToDownloadSupportingFiles = 13
        case BLImportDownloadingSupportingFiles = 14
        case BLImportCleaningUp = 15
        case BLImportFinished = 16
    }
    
    enum BLSourceFileImportType {
        case BLImportTypeUnknown
        case BLImportTypePreinstalledGame
        case BLImportTypeMountedVolume
        case BLImportTypeDiskImage
        case BLImportTypeExecutable
        case BLImportTypeFolder
    }
    
    dynamic private(set) var BLImportStageStateRaw:Int = 0;
    var importStage:BLImportStage {
        didSet {
            BLImportStageStateRaw = importStage.rawValue
        }
    }
    
    override init() {
        self.scanQueue = NSOperationQueue();
        self.importStage = BLImportStage.BLImportWaitingForSource
        
        super.init();
    }
    
    override class func automaticallyNotifiesObserversForKey(key: String) -> Bool {
        return true;
    }
    
    // MARK: - Class Methods
    class func acceptedSourceTypes() -> NSSet? {
        var types:NSSet? = nil;
        if (types == nil) {
            if let unwrappedTypes = BLFileTypes.OSXMountableVolumeTypes() {
                types = unwrappedTypes.setByAddingObject("public.folder");
            }
        }
        
        return types;
    }
    
    class func preferredSourceURLForURL(URL:NSURL?) -> NSURL? {
        var workspace:NSWorkspace = NSWorkspace.sharedWorkspace();
        
        if (URL != nil) {
            if (workspace.typeOfVolumeAtURL(URL!) == BLAudioCDVolumeType) {
                var dataVolumeURL:NSURL? = workspace.dataVolumeOfAudioCDAtURL(URL!);
                if (dataVolumeURL != nil) {
                    return dataVolumeURL;
                }
            }
        }
        
        return URL;
    }
    
    // MARK: - Instance Methods
    func importFromSourceURL(URL:NSURL) {
        var readError:NSError? = nil;
        var readSucceeded:Bool = self.readFromURL(URL, typeName:"", error: &readError);
        
        if (!readSucceeded) {
            self.sourceURL = nil;
            self.importStage = BLImportStage.BLImportWaitingForSource;
            
            if (readError != nil) {
                var alert:NSAlert = NSAlert(error: readError!);
                alert.beginSheetModalForWindow(self.windowForSheet(), completionHandler: nil);
            }
        }
    }
    
    func readFromURL(absoluteURL:NSURL?, typeName:String, inout error:NSError?) -> Bool {
        assert(absoluteURL != nil, "No URL provided");
        
        self.didMountSourceVolume = false;
        var prefferedURL:NSURL? = BLImporter.preferredSourceURLForURL(absoluteURL);
        if (prefferedURL == nil) {
            return false;
        }
        
        self.sourceURL = prefferedURL;
        var scan:BLInstallerScan = BLInstallerScan.scanWithBasePath(prefferedURL!.path!) as BLInstallerScan;
        scan.delegate = self;
        scan.didFinishSelector = "installerScanDidFinish:";
        scan.didFinishClosure = self.installerScanDidFinish;
        
        self.scanQueue?.addOperation(scan);
        self.importStage = BLImportStage.BLImportLoadingSource;
        
        return true;
    }
    
    func windowForSheet() -> NSWindow {
        var importWindow:NSWindow = self.importWindowController!.window!;
        return importWindow;
    }
    
    func installerScanDidFinish(notification:NSNotification) {
        var scan:BLInstallerScan = notification.object as BLInstallerScan;
        
        if (scan.succeeded) {
            self.sourceURL = NSURL(fileURLWithPath: scan.recommendedSourcePath);
            self.didMountSourceVolume = false;
            
            self.installerURLs = self.sourceURL!.URLsByAppendingPaths(scan.matchingPaths);
            
            if (self.installerURLs.count > 0) {
                // Setup a new operation to fetch the engines list
                var fetchEngines:BLRemoteEngineList = BLRemoteEngineList();
                fetchEngines.delegate = self;
                fetchEngines.didFinishSelector = "fetchEnginesDidFinish:";
                fetchEngines.didFinishClosure = self.fetchEnginesDidFinish;
                
                self.scanQueue?.addOperation(fetchEngines);
                //                self.importStage = BLImportStage.BLImportReadyToFetchEnginesList;
            }
            else {
                // We failed, so show a message and go back to waiting for source
                self.importStage = BLImportStage.BLImportWaitingForSource;
            }
        }
        else {
            // We failed, so show a message and go back to waiting for source
            self.importStage = BLImportStage.BLImportWaitingForSource;
        }
    }
    
    func fetchEnginesDidFinish(notification:NSNotification) {
        var fetchEngines:BLRemoteEngineList = notification.object as BLRemoteEngineList;
        
        if (fetchEngines.succeeded) {
            if let detectedEngines = fetchEngines.engineList {
                self.enginesList = detectedEngines;
                self.importStage = BLImportStage.BLImportWaitingForInstaller;
                NSApp.requestUserAttention(NSRequestUserAttentionType.InformationalRequest);
            }
            else {
                // We failed, so show a message and go back to waiting for source
                self.importStage = BLImportStage.BLImportWaitingForSource;
            }
        }
        else {
            // We failed, so show a message and go back to waiting for source
            self.importStage = BLImportStage.BLImportWaitingForSource;
        }
    }
}