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
        // Insert code here to initialize your application
        if (!shouldDisplayMainWindow) {
            self.window.orderOut(self);
        }
        
        // Was this launched with any arguments?
        var args:NSArray = NSProcessInfo.processInfo().arguments as NSArray;
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

