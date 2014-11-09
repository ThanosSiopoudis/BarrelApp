//
//  BLImportDropzonePanelController.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 28/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class BLImportDropzonePanelController : NSViewController, NSOpenSavePanelDelegate {
    // MARK: Class Variables
    @IBOutlet weak var dropzone:BLImportDropzone!
    @IBOutlet weak var spinner:BLBlueprintProgressIndicator?
    @IBOutlet weak var controller:BLImportWindowController?
    
    // MARK: - Superclass Overrides
    override func awakeFromNib() {
        self.view.registerForDraggedTypes([NSFilenamesPboardType]);
        if let loader = self.spinner {
            loader.usesThreadedAnimation = true;
            loader.startAnimation(self);
        }
    }
    
    // MARK: - Class Methods
    @IBAction func showImportPathPicker(sender:AnyObject) {
        var openPanel:NSOpenPanel = NSOpenPanel();
        openPanel.delegate = self;
        openPanel.canChooseFiles = true;
        openPanel.canChooseDirectories = true;
        openPanel.treatsFilePackagesAsDirectories = false;
        openPanel.message = "Choose a Windows game folder, Disk Drive, Executable or image to import:";
        openPanel.prompt = "Import";
        openPanel.allowedFileTypes = BLImporter.acceptedSourceTypes()?.allObjects;
        
        openPanel.beginSheetModalForWindow(self.view.window!, completionHandler: {(result:Int) in
            if (result == NSFileHandlingPanelOKButton) {
                openPanel.orderOut(self);
                
                self.controller?.importer
            }
        });
    }
    
    // MARK: - Class Methods (Delegated Class)
    func draggingEntered(sender: NSDraggingInfo!) -> NSDragOperation {
        var pboard:NSPasteboard = sender.draggingPasteboard();
        var dragClasses:NSArray = [NSURL.self];
        var dragOptions:NSDictionary = [NSPasteboardURLReadingFileURLsOnlyKey : true];
        if (pboard.canReadObjectForClasses(dragClasses, options: dragOptions)) {
            var droppedURLs:NSArray = pboard.readObjectsForClasses(dragClasses, options: dragOptions)!;
            for URL in droppedURLs {
                // check if the importer cannot import from source URL
                // return NSDragOperation.None;
            }
            
            self.dropzone.highlighted = true;
            return NSDragOperation.Copy;
        }
        else {
            return NSDragOperation.None;
        }
    }
    
    func draggingExited(sender: NSDraggingInfo!) {
        self.dropzone.highlighted = false;
    }
}
