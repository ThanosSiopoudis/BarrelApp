//
//  BLImportWindowController.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 27/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class BLImportWindowController: BLMutliPanelWindowController {
    @IBOutlet
    var dropZonePanel:NSView?
    @IBOutlet
    var loadingPanel:NSView?
    
    enum BLImportStage {
        case WaitingForSource
    };
    
    var importStage:BLImportStage = BLImportStage.WaitingForSource;
    
    override func windowDidLoad() {
        // Default to dropzone panel when we initially load this window
        self.currentPanel = self.dropZonePanel;
        
        // Disable window restoration
        self.window.restorable = false;
        
        // Observe ourselves for changes to the import stage
        self.addObserver(self, forKeyPath: "importStage", options: NSKeyValueObservingOptions.Initial, context: nil);
    }
    
    override func observeValueForKeyPath(keyPath: String!, ofObject object: AnyObject!, change: [NSObject : AnyObject]!, context: UnsafeMutablePointer<Void>) {
        if (keyPath == "importStage") {
            self.syncActivePanel();
        }
    }
    
    func syncActivePanel() {
        switch (self.importStage) {
        case .WaitingForSource:
            self.currentPanel = self.dropZonePanel;
            break;
        }
    }
    
    func windowShouldClose(sender:AnyObject?) -> Bool {
        return self.window.firstResponder != nil || self.window.makeFirstResponder(nil);
    }
}
