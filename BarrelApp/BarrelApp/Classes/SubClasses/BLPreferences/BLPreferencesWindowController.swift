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
    var gamesFolderSelector:NSPopUpButton!
    @IBOutlet
    var currentGamesFolderItem:NSMenuItem!
    
    override func awakeFromNib() {
        
        var apdlg:AppDelegate = NSApplication.sharedApplication().delegate as AppDelegate;
        self.currentGamesFolderItem.bind("attributedTitle",
                                        toObject: apdlg,
                                        withKeyPath: "gamesFolderURL.path",
                                        options: [
                                            NSValueTransformerNameBindingOption: "BLIconifiedGamesFolderPath"
                                        ]
        );
        
        // Select the tab that the user had open the last time.
        var selectedIndex:NSInteger = NSUserDefaults.standardUserDefaults().integerForKey("initialPreferencesPanelIndex");
        if (selectedIndex >= 0 && selectedIndex < self.tabView.numberOfTabViewItems) {
            self.tabView.selectTabViewItemAtIndex(selectedIndex);
        }
    }
    
    // MARK: - Managing and persisting tab state
    override func tabView(tabView: NSTabView!, didSelectTabViewItem tabViewItem: NSTabViewItem!) {
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
        self.gamesFolderSelector.selectItemAtIndex(0);
    }
}
