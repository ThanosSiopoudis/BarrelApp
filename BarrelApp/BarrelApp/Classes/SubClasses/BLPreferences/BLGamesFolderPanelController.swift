//
//  BLGamesFolderPanelController.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 26/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

var singleton:BLGamesFolderPanelController? = nil

class BLGamesFolderPanelController : NSViewController, NSOpenSavePanelDelegate {
    @IBOutlet
    var sampleGamesToggle:NSButton!
    
    convenience required init?(coder: NSCoder?) {
        self.init(nibName: "GamesFolderPanelOptions", bundle: nil);
        self.initialization();
    }
    
    func initialization() {
        singleton = self;
    }
    
    class func controller() -> BLGamesFolderPanelController? {
        return singleton;
    }
    
    func showGamesFolderPanelWindow(window:NSWindow!) {
        var openPanel:NSOpenPanel = NSOpenPanel();
        var dlg:AppDelegate = NSApplication.sharedApplication().delegate as! AppDelegate;
        
        var currentFolderURL:NSURL?
        if let gamesURL = dlg.gamesFolderURL {
            currentFolderURL = gamesURL;
        }
        var initialURL:NSURL?
        if let cfURL = currentFolderURL {
            initialURL = cfURL;
        }
        else {
            initialURL = NSURL(fileURLWithPath: NSHomeDirectory());
        }
        
        openPanel.delegate = self;
        openPanel.canCreateDirectories = true;
        openPanel.canChooseDirectories = true;
        openPanel.canChooseFiles = false;
        openPanel.treatsFilePackagesAsDirectories = false;
        openPanel.allowsMultipleSelection = false;
        
        openPanel.accessoryView = self.view;
        openPanel.directoryURL = initialURL;
        
        openPanel.prompt = "Select";
        openPanel.message = "Select a folder in which to keep your Windows games:";
        
        self.sampleGamesToggle.state = 1;
        
        if (window != nil) {
            openPanel.beginSheetModalForWindow(window, completionHandler: {(result) -> Void in
                if (result == NSFileHandlingPanelOKButton) {
                    var folderError:NSError?
                    var assigned:Bool = self.chooseGamesFolderURL(openPanel.URL!, outError: &folderError);
                    
                    if (!assigned && folderError != nil) {
                        if (window != nil) {
                            openPanel.orderOut(self);
                            self.presentError(folderError!, modalForWindow: window, delegate: nil, didPresentSelector: nil, contextInfo: nil);
                        }
                        else {
                            self.presentError(folderError!);
                        }
                    }
                }
            });
        }
    }
    
    func chooseGamesFolderURL(URL:NSURL, inout outError:NSError?) -> Bool {
        var controller:AppDelegate = NSApplication.sharedApplication().delegate as! AppDelegate;
        var addSampleGames:Bool = self.sampleGamesToggle.state == 1 ? true : false;
        
        return controller.assignGamesFolderURL(URL, addSampleGames: addSampleGames, createIfMissing: false, outError: &outError);
    }
}
