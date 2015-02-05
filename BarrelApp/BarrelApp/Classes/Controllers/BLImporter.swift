//
//  BLImporter.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 03/09/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class BLImporter:NSObject, BLOperationDelegate {
    var importStage:BLImportStage = BLImportStage.BLImportWaitingForSource;
    var didMountSourceVolume:Bool = false;
    var sourceURL:NSURL?
    var importWindowController:BLImportWindowController?
    var scanQueue:NSOperationQueue?
    
    // MARK: Enum Types
    enum BLImportStage:Int {
        case BLImportWaitingForSource = 0
        case BLImportLoadingSource = 1
        case BLImportWaitingForInstaller = 2
        case BLImportReadyToLaunchInstaller = 3
        case BLImportRunningInstaller = 4
        case BLImportReadyToLookupRecipe = 5
        case BLImportSearchingForRecipe = 6
        case BLImportDownloadingRecipe = 7
        case BLImportReadyToDownloadEngine = 8
        case BLImportDownloadingEngine = 9
        case BLImportReadyToDownloadWinetricks = 10
        case BLImportDownloadingWinetricks = 11
        case BLImportReadyToDownloadSupportingFiles = 12
        case BLImportDownloadingSupportingFiles = 13
        case BLImportCleaningUp = 14
        case BLImportFinished = 15
    }
    
    enum BLSourceFileImportType {
        case BLImportTypeUnknown
        case BLImportTypePreinstalledGame
        case BLImportTypeMountedVolume
        case BLImportTypeDiskImage
        case BLImportTypeExecutable
        case BLImportTypeFolder
    }
    
    override init() {
        self.scanQueue = NSOperationQueue();
        
        super.init();
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
    }
}