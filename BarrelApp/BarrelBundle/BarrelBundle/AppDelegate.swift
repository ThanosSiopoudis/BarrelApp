//
//  AppDelegate.swift
//  BarrelBundle
//
//  Created by Thanos Siopoudis on 17/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSOpenSavePanelDelegate {

    @IBOutlet weak var window: NSWindow!
    var shouldDisplayMainWindow:Bool = false;
    var _gamesFolder:NSURL?
    var gamesFolderURL:NSURL?
    var shouldRunWithDebugLogging:Bool = false;
    var preferencesWindow:BLPreferencesWindowController!
    
    @IBAction func runWineboot(sender:AnyObject) {
        BLWineMediator.initWinePrefix();
    }
    
    @IBAction func startRegistryEditor(sender:AnyObject) {
        BLWineMediator.executeBinary(NSBundle.mainBundle().resourcePath! + "/drive_c/windows/regedit.exe", withStart: false, waitForExit: false);
    }
    
    @IBAction func showPreferences(sender:AnyObject) {
        self.preferencesWindow = BLPreferencesWindowController(windowNibName: "BLPreferences");
        self.preferencesWindow.showWindow(self);
    }
    
    @IBAction func startWineConfig(sender:AnyObject) {
        BLWineMediator.startWineConfig();
    }
    
    @IBAction func showInstallerPicker(sender:AnyObject) {
        let openPanel:NSOpenPanel = NSOpenPanel();
        
        openPanel.delegate = self;
        openPanel.canCreateDirectories = false;
        openPanel.canChooseDirectories = false;
        openPanel.canChooseFiles = true;
        openPanel.treatsFilePackagesAsDirectories = true;
        openPanel.allowsMultipleSelection = false;
        
        openPanel.prompt = "Launch";
        openPanel.message = "Please select an installer executable to run (.exe)";
        
        if (window != nil) {
            openPanel.beginSheetModalForWindow(window!, completionHandler: {(result) -> Void in
                if (result == NSFileHandlingPanelOKButton) {
                    // Launch the executable
                    BLWineMediator.executeBinary(openPanel.URL!.path!,
                        withStart: false,
                        waitForExit: false,
                        debugLogging: false,
                        debugSwitches: nil,
                        terminateWhenDone: false);
                }
            });
        }
    }
    
    @IBAction func didSelectShowCDrive(sender:AnyObject) {
        var cdrive:NSURL = NSBundle.mainBundle().bundleURL.URLByAppendingPathComponent("drive_c");
        self.revealURLInFinder(cdrive);
    }
    
    @IBAction func didSelectExit(sender:AnyObject) {
        NSApplication.sharedApplication().terminate(self);
    }
    
    override class func initialize() {
        AppDelegate.prepareValueTransformers();
    }
    
    class func prepareValueTransformers() {
        let pathTransformer:BLIconifiedDisplayPathTransformer = BLIconifiedDisplayPathTransformer(joiner: " ▸ ", ellipsis: "",  maxComponents: 0);
        pathTransformer.missingFileIcon = NSImage(named: "noIcon");
        pathTransformer.hidesSystemRoots = true;
        
        var pathStyle:NSMutableParagraphStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle;
        pathStyle.lineBreakMode = NSLineBreakMode.ByTruncatingMiddle;
        pathTransformer.textAttributes?.setObject(pathStyle, forKey: NSParagraphStyleAttributeName);
        NSValueTransformer.setValueTransformer(pathTransformer, forName: "BLIconifiedGamesFolderPath");
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        #if DEBUG
            // Delay the launch so we have time to attach a debugger when testing
            // from BarrelApp
            // NSThread.sleepForTimeInterval(10);
        #endif
        
        // Insert code here to initialize your application
        if (!shouldDisplayMainWindow) {
            self.window.orderOut(self);
        }
        else {
            // We need to quickly set a property to show the icon in the dock
            // and then relaunch Barrel
            var infoDictionaryMutable:NSMutableDictionary = NSMutableDictionary(contentsOfFile: NSBundle.mainBundle().bundlePath + "/Contents/Info.plist")!
            var lsuiElement:Bool = infoDictionaryMutable.valueForKey("LSUIElement") as! Bool;
            
            if (lsuiElement) {
                infoDictionaryMutable.setValue(false, forKey: "LSUIElement");
                var writePath:String = NSBundle.mainBundle().bundlePath + "/Contents/Info.plist";
                let success:Bool = infoDictionaryMutable.writeToFile(writePath, atomically: true);
                
                var task = NSTask()
                
                var args:NSMutableArray = NSMutableArray();
                args.addObject("-c")
                args.addObject("sleep 0.2; open \"\(NSBundle.mainBundle().bundlePath)\"")
                
                task.launchPath = "/bin/sh";
                task.arguments = args as [AnyObject];
                task.launch()
                NSApplication.sharedApplication().terminate(nil)
            }
            else {
                infoDictionaryMutable.setValue(true, forKey: "LSUIElement");
                var writePath:String = NSBundle.mainBundle().bundlePath + "/Contents/Info.plist";
                let success:Bool = infoDictionaryMutable.writeToFile(writePath, atomically: true);
                self.window.makeKeyAndOrderFront(self);
            }
            
            // Whatever happens, don't continue execution
            return;
        }
        
        // Was this launched with any arguments?
        var args:NSArray = NSProcessInfo.processInfo().arguments as NSArray;
        // Let's decide on what to do in order of importance
        var counter:Int = 0;
        for arg in args {
            let argString:String = arg as! String;
            if (argString == "--initPrefix") {
                BLWineMediator.initWinePrefix();
            }
            else if (argString == "--runSetup") {
                // We would expect the next argument to be the executable path
                var executablePath:String = args.objectAtIndex(counter + 1) as! String;
                BLWineMediator.executeBinary(executablePath, withStart: false, waitForExit: true);
            }
            counter++;
        }
        
        var BundleConfiguration:NSMutableDictionary? = NSMutableDictionary(contentsOfFile: NSBundle.mainBundle().pathForResource("BundleConfiguration", ofType: "plist")!);
        if let BLConfiguration = BundleConfiguration {
            let configPath:String = BLConfiguration.objectForKey("BLExecutablePath") as! String;
            let useStart:Bool = BLConfiguration.objectForKey("BLUseStart") as! Bool;
            let executablePath:String = "\(NSBundle.mainBundle().resourcePath!)/\(configPath)";
            
            if (self.shouldRunWithDebugLogging) {
                BLWineMediator.executeBinary(executablePath, withStart: useStart, waitForExit: true, debugLogging: true, debugSwitches: "error+all, fixme+all");
            }
            else {
                BLWineMediator.executeBinary(executablePath, withStart: useStart, waitForExit: true);
            }
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    func applicationWillFinishLaunching(notification: NSNotification) {
        // If a game is not installed, always launch the config window
        
        // If the Fn key is pressed down, show the config window.
        var event:CGEventRef = CGEventCreate(nil).takeRetainedValue();
        var modifiers:CGEventFlags = CGEventGetFlags(event);
        if ((Int(modifiers) & kCGEventFlagMaskAlternate) == kCGEventFlagMaskAlternate || (Int(modifiers) & kCGEventFlagMaskSecondaryFn) == kCGEventFlagMaskSecondaryFn)
        {
            self.shouldDisplayMainWindow = true;
        }
        else if ((Int(modifiers) & kCGEventFlagMaskCommand) == kCGEventFlagMaskCommand)
        {
            self.shouldRunWithDebugLogging = true;
        }
    }
    
    func assignGamesFolderURL(URL:NSURL?, addSampleGames:Bool, createIfMissing:Bool, inout outError:NSError?) -> Bool {
        return true;
    }
    
    func revealURLInFinder(URL:NSURL) -> Bool {
        return self.revealURLsInFinder([ URL ]);
    }
    
    func revealURLsInFinder(URLs:NSArray) -> Bool {
        var revealedAnyFiles:Bool = false;
        var ws:NSWorkspace = NSWorkspace.sharedWorkspace();
        
        var safeURLs:NSMutableArray = NSMutableArray(capacity: URLs.count);
        for val in URLs {
            let URL:NSURL = val as! NSURL;
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
                            )!;
                        
                        var childURL:NSURL? = enumerator.nextObject() as? NSURL;
                        if (childURL != nil) {
                            safeURLs.addObject(childURL!);
                            continue;
                        }
                    }
                    
                    revealedAnyFiles = ws.selectFile(URL.path!, inFileViewerRootedAtPath: parentURL!.path!) || revealedAnyFiles;
                }
                else {
                    safeURLs.addObject(URL);
                    revealedAnyFiles = true;
                }
            }
        }
        
        if (safeURLs.count > 0) {
            ws.activateFileViewerSelectingURLs(safeURLs as [AnyObject]);
        }
        
        return revealedAnyFiles;
    }
}

