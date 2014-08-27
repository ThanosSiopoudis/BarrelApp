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
}
