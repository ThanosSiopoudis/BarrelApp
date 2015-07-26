//
//  File.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 24/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class BLPreferencesWindowController: BLTabbedWindowController, NSOpenSavePanelDelegate {
    @IBOutlet
    var gamesFolderSelector:NSPopUpButton?
    @IBOutlet
    var currentExecutableSelector:NSPopUpButton?
    @IBOutlet
    var currentGamesFolderItem:NSMenuItem?
    @IBOutlet
    var currentExecutablePath:NSMenuItem?
    @IBOutlet
    var currentUseStart:NSButton?
    @IBOutlet
    var currentDebugFlags:NSTextField?
    
    dynamic var executablePath:String = "";
    dynamic var useStart:Bool = false;
    dynamic var debugFlags:String = "";
    
    override func awakeFromNib() {
        
        var apdlg:AppDelegate = NSApplication.sharedApplication().delegate as! AppDelegate;
        if let cGamesFolderItem = self.currentGamesFolderItem {
            cGamesFolderItem.bind("attributedTitle",
                                            toObject: apdlg,
                                            withKeyPath: "gamesFolderURL.path",
                                            options: [
                                                NSValueTransformerNameBindingOption: "BLIconifiedGamesFolderPath"
                                            ]
            );
        }
        
        // Read the settings
        if let bConfigPath = NSBundle.mainBundle().URLForResource("BundleConfiguration", withExtension: "plist") {
            let settings:NSMutableDictionary? = NSMutableDictionary(contentsOfURL: bConfigPath);
            if let unwSettings = settings {
                self.executablePath = unwSettings.objectForKey("BLExecutablePath") as! String;
                self.useStart = unwSettings.objectForKey("BLUseStart") as! Bool;
            }
        }
        
        if let cExecPath = self.currentExecutablePath {
            cExecPath.bind("attributedTitle",
                toObject: self,
                withKeyPath: "executablePath",
                options: [
                    NSValueTransformerNameBindingOption: "BLIconifiedGamesFolderPath"
                ]
            );
        }
        
        if let cUseStart = self.currentUseStart {
            cUseStart.bind("state", toObject: self, withKeyPath: "useStart", options: nil);
            self.addObserver(self, forKeyPath: "useStart", options: NSKeyValueObservingOptions.New, context: nil);
        }
        
        // Select the tab that the user had open the last time.
        var selectedIndex:NSInteger = NSUserDefaults.standardUserDefaults().integerForKey("initialPreferencesPanelIndex");
        if (selectedIndex >= 0 && selectedIndex < self.tabView.numberOfTabViewItems) {
            self.tabView.selectTabViewItemAtIndex(selectedIndex);
        }
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if (keyPath == "useStart") {
            if let bConfigPath = NSBundle.mainBundle().URLForResource("BundleConfiguration", withExtension: "plist") {
                let settings:NSMutableDictionary? = NSMutableDictionary(contentsOfURL: bConfigPath);
                if let unwSettings = settings {
                    unwSettings.setObject(useStart, forKey: "BLUseStart");
                    unwSettings.writeToURL(bConfigPath, atomically: true);
                }
            }
        }
    }
    
    // MARK: - Managing and persisting tab state
    override func tabView(tabView: NSTabView, didSelectTabViewItem tabViewItem: NSTabViewItem!) {
        super.tabView(tabView, didSelectTabViewItem: tabViewItem);
        
        // Record the user's choice of tab and synchronise the selected segment
        var selectedIndex:NSInteger = tabView.indexOfTabViewItem(tabViewItem);
        if (selectedIndex != NSNotFound) {
            NSUserDefaults.standardUserDefaults().setInteger(selectedIndex, forKey: "initialPreferencesPanelIndex");
        }
    }
    
    override func shouldSyncWindowTitleToTabLabel(label: String) -> Bool {
        return true;
    }
    
    @IBAction func showGamesFolderChooser(sender:AnyObject) {
        var chooser:BLGamesFolderPanelController = BLGamesFolderPanelController(coder: nil)!;
        chooser.showGamesFolderPanelWindow(self.window);
        if let cGamesFolderSelector = self.gamesFolderSelector {
            cGamesFolderSelector.selectItemAtIndex(0);
        }
    }
    
    @IBAction func showExecutableFolderChooser(sender:AnyObject) {
        let openPanel:NSOpenPanel = NSOpenPanel();
        var currentFolderPath:String!
        
        if (self.executablePath != "" && self.executablePath != "no.exe") {
            currentFolderPath = "\(NSBundle.mainBundle().resourcePath!)/\(self.executablePath)";
            currentFolderPath = NSURL(fileURLWithPath: currentFolderPath)?.URLByDeletingLastPathComponent!.path!
        }
        else {
            currentFolderPath = NSBundle.mainBundle().resourceURL?.URLByAppendingPathComponent("drive_c").path!;
        }
        
        openPanel.delegate = self;
        openPanel.canCreateDirectories = false;
        openPanel.canChooseDirectories = false;
        openPanel.canChooseFiles = true;
        openPanel.treatsFilePackagesAsDirectories = true;
        openPanel.allowsMultipleSelection = false;
        openPanel.directoryURL = NSURL(fileURLWithPath: currentFolderPath);
        
        openPanel.prompt = "Choose Executable";
        openPanel.message = "Please choose your game's main executable (.exe)";
        
        if (window != nil) {
            openPanel.beginSheetModalForWindow(window!, completionHandler: {(result) -> Void in
                if (result == NSFileHandlingPanelOKButton) {
                    // Write the new path to the config file
                    if let bConfigPath = NSBundle.mainBundle().URLForResource("BundleConfiguration", withExtension: "plist") {
                        let settings:NSMutableDictionary? = NSMutableDictionary(contentsOfURL: bConfigPath);
                        if let unwSettings = settings {
                            let relativePath:String = openPanel.URL!.pathRelativeToURL(NSBundle.mainBundle().resourceURL!);
                            unwSettings.setObject(relativePath, forKey: "BLExecutablePath");
                            self.executablePath = relativePath;
                            
                            unwSettings.writeToURL(bConfigPath, atomically: true);
                        }
                    }
                }
            });
        }
        
        if let cExecutableSelector = self.currentExecutableSelector {
            cExecutableSelector.selectItemAtIndex(0);
        }
    }
}
