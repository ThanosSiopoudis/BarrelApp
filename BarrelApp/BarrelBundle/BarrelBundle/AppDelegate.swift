//
//  AppDelegate.swift
//  BarrelBundle
//
//  Created by Thanos Siopoudis on 17/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    var shouldDisplayMainWindow:Bool = false;
    var _gamesFolder:NSURL?
    var gamesFolderURL:NSURL?

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
            var lsuiElement:Bool = infoDictionaryMutable.valueForKey("LSUIElement") as Bool;
            
            if (lsuiElement) {
                infoDictionaryMutable.setValue(false, forKey: "LSUIElement");
                var writePath:String = NSBundle.mainBundle().bundlePath + "/Contents/Info.plist";
                let success:Bool = infoDictionaryMutable.writeToFile(writePath, atomically: true);
                
                var task = NSTask()
                
                var args:NSMutableArray = NSMutableArray();
                args.addObject("-c")
                args.addObject("sleep 0.2; open \"\(NSBundle.mainBundle().bundlePath)\"")
                
                task.launchPath = "/bin/sh";
                task.arguments = args;
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
            let argString:String = arg as String;
            if (argString == "--initPrefix") {
                BLWineMediator.initWinePrefix();
            }
            else if (argString == "--runSetup") {
                // We would expect the next argument to be the executable path
                var executablePath:String = args.objectAtIndex(counter + 1) as String;
                BLWineMediator.executeBinary(executablePath, withStart: false, waitForExit: true);
            }
            counter++;
        }
        
        // If no args were passed, start the default executable
        var BundleConfiguration:NSMutableDictionary? = NSMutableDictionary(contentsOfFile: NSBundle.mainBundle().pathForResource("BundleConfiguration", ofType: "plist")!);
        if let BLConfiguration = BundleConfiguration {
            let executablePath = BLConfiguration.objectForKey("BLExecutablePath");
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
    }
    
    func assignGamesFolderURL(URL:NSURL?, addSampleGames:Bool, createIfMissing:Bool, inout outError:NSError?) -> Bool {
        return true;
    }
}

