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
    @IBOutlet weak var progressText:NSTextField?
    
    // MARK: - Superclass Overrides
    override func awakeFromNib() {
        self.view.registerForDraggedTypes([NSFilenamesPboardType]);
        if let loader = self.spinner {
            // loader.usesThreadedAnimation = true;
            loader.startAnimation(self);
        }
        
        var title:String = self.progressText!.stringValue;
        var textColour:NSColor = NSColor.whiteColor();
        var theFont:NSFont = NSFont(name: "Avenir Next", size: 32.0)!
        var textParagraph:NSMutableParagraphStyle = NSMutableParagraphStyle();
        textParagraph.lineSpacing = 6.0;
        textParagraph.maximumLineHeight = 38.0;
        textParagraph.alignment = NSTextAlignment.CenterTextAlignment;
        
        var attrDict:NSDictionary = NSDictionary(objectsAndKeys: theFont, NSFontAttributeName, textColour, NSForegroundColorAttributeName, textParagraph, NSParagraphStyleAttributeName);
        var attrString:NSAttributedString = NSAttributedString(string: title, attributes: attrDict as [NSObject : AnyObject]);
        self.progressText?.attributedStringValue = attrString;
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
                
                self.controller?.importer.importFromSourceURL(openPanel.URL!);
            }
        });
    }
    
    // MARK: - Class Methods (Delegated Class)
    func draggingEntered(sender: NSDraggingInfo!) -> NSDragOperation {
        var pboard:NSPasteboard = sender.draggingPasteboard();
        var dragClasses:NSArray = [NSURL.self];
        var dragOptions:NSDictionary = [NSPasteboardURLReadingFileURLsOnlyKey : true];
        if (pboard.canReadObjectForClasses(dragClasses as [AnyObject], options: dragOptions as [NSObject : AnyObject])) {
            var droppedURLs:NSArray = pboard.readObjectsForClasses(dragClasses as [AnyObject], options: dragOptions as [NSObject : AnyObject])!;
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
