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
    var importer:BLImporter!
    
    override func windowDidLoad() {
        // Default to dropzone panel when we initially load this window
        self.currentPanel = self.dropZonePanel;
        
        // Disable window restoration
        self.window!.restorable = false;
        
        self.importer = BLImporter();
        self.importer.importWindowController = self;
        
        // Observe ourselves for changes to the import stage
        self.addObserver(self, forKeyPath: "importer.BLImportStageStateRaw", options: NSKeyValueObservingOptions.Initial, context: nil);
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if (keyPath == "importer.BLImportStageStateRaw") {
            self.syncActivePanel();
        }
        else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context);
        }
    }
    
    func syncActivePanel() {
        switch (self.importer.importStage) {
        case .BLImportWaitingForSource:
            self.currentPanel = self.dropZonePanel;
            break;
        case .BLImportLoadingSource:
            self.currentPanel = self.loadingPanel;
            break;
        default:
            break;
        }
    }
    
    func windowShouldClose(sender:AnyObject?) -> Bool {
        return self.window != nil || self.window!.makeFirstResponder(nil);
    }
}
