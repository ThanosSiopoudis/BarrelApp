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
    var importGameWindow:BLImportWindowController!
    
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
            var win:NSWindow? = sender.window as? NSWindow;
            appdlg.promptForMissingGamesFolderInWindow(win);
        }
    }
    
    @IBAction func showGameImportWindow(sender:AnyObject) {
        // Close the current window first.
        var selfview:NSView = sender as NSView;
        selfview.window!.orderOut(self);
        
        self.importGameWindow = BLImportWindowController(windowNibName: "BLGameImport");
        self.importGameWindow.showWindow(self);
    }
}
