//
//  BLWelcomeViewController.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 23/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class BLWelcomeViewController: NSViewController {
    @IBOutlet
    var installButton:NSButton?
    var preferencesWindow:BLPreferencesWindowController!
    
    override func viewDidLoad() {
        super.viewDidLoad();
    }
    
    @IBAction func showPreferences(sender: AnyObject) {
        self.preferencesWindow = BLPreferencesWindowController(windowNibName: "BLPreferences");
        self.preferencesWindow.showWindow(self);
    }
    
    @IBAction func showGamesFolder(sender:AnyObject) {
        var appdlg:AppDelegate = NSApplication.sharedApplication().delegate as AppDelegate;
        var URL:NSURL? = appdlg.gamesFolderURL;
        var revealed:Bool = false;
        
        if (URL != nil) {
            revealed = appdlg.revealURLsInFinder([URL!]);
        }
        
        if (revealed) {
            // Apply Shelf appearance
        }
        else {
            var window:NSWindow? = sender.window as? NSWindow;
            appdlg.promptForMissingGamesFolderInWindow(window);
        }
    }
}
