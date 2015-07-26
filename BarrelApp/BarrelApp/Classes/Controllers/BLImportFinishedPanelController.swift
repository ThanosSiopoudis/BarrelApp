//
//  BLImportFinishedPanelController.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 24/03/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Cocoa

class BLImportFinishedPanelController: NSViewController, NSOpenSavePanelDelegate {
    @IBOutlet weak var titleText:NSTextField?
    @IBOutlet var controller:BLImportWindowController?
    @IBOutlet weak var executableSelector:NSPopUpButton?
    @IBOutlet weak var gameTitle:NSTextField?
    @IBOutlet weak var gameIcon:BLImportIconDropzone?
    dynamic var executablePath:String = "";
    var firstTimeLoaded:Bool = false;
    
    required init?(coder: NSCoder) {
        var nameTransformer:BLDisplayPathTransformer = BLDisplayPathTransformer(joiner: " ▸ ", maxComponents: 0);
        NSValueTransformer.setValueTransformer(nameTransformer, forName: "BLImportExecutableMenuTitle");
        super.init(coder: coder);
    }
    
    override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        var nameTransformer:BLDisplayPathTransformer = BLDisplayPathTransformer(joiner: " ▸ ", maxComponents: 0);
        NSValueTransformer.setValueTransformer(nameTransformer, forName: "BLImportExecutableMenuTitle");
        
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil);
    }
    
    override func awakeFromNib() {
        var title:String = self.titleText!.stringValue;
        
        var textColour:NSColor = NSColor.whiteColor();
        var theFont:NSFont = NSFont(name: "Avenir Next", size: 26.0)!
        var textParagraph:NSMutableParagraphStyle = NSMutableParagraphStyle();
        textParagraph.lineSpacing = 6.0;
        textParagraph.maximumLineHeight = 30.0;
        textParagraph.alignment = NSTextAlignment.CenterTextAlignment;
        
        var attrDict:NSDictionary = NSDictionary(objectsAndKeys: theFont, NSFontAttributeName, textColour, NSForegroundColorAttributeName, textParagraph, NSParagraphStyleAttributeName);
        var attrString:NSAttributedString = NSAttributedString(string: title, attributes: attrDict as [NSObject : AnyObject]);
        self.titleText!.attributedStringValue = attrString;
        
        self.controller?.addObserver(self, forKeyPath: "importer.executableURLs", options: NSKeyValueObservingOptions.allZeros, context: nil);
        self.controller?.addObserver(self, forKeyPath: "importer.detectedGameName", options: NSKeyValueObservingOptions.allZeros, context: nil);
        self.addObserver(self, forKeyPath: "executablePath", options: NSKeyValueObservingOptions.allZeros, context: nil);
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if (keyPath == "importer.executableURLs") {
            self.syncExecutableSelectorItems();
        }
        else if (keyPath == "importer.detectedGameName") {
            self.gameTitle!.stringValue = self.controller!.importer.detectedGameName!;
        }
        else {
            // Update the bundle config for any change made
            self.updateBundleConfiguration();
        }
    }
    
    func updateBundleConfiguration() {
        let appDlg:AppDelegate = NSApplication.sharedApplication().delegate as! AppDelegate;
        let gameBundle:NSBundle = NSBundle(path: self.controller!.importer.temporaryBundlePath!)!
        let bundleConfigPath = gameBundle.pathForResource("BundleConfiguration", ofType: "plist")!;
        var BundleConfiguration:NSMutableDictionary? = NSMutableDictionary(contentsOfFile: bundleConfigPath);
        BundleConfiguration?.setObject(self.executablePath, forKey: "BLExecutablePath");
        BundleConfiguration?.writeToFile(bundleConfigPath, atomically: true);
    }
    
    func syncExecutableSelectorItems() {
        var menu:NSMenu = self.executableSelector!.menu!;
        
        let dividerIndex:NSInteger = menu.indexOfItemWithTag(1);
        assert(dividerIndex > -1, "Menu Divider not found.");
        
        var insertionPoint:NSInteger = 0;
        var removalPoint:NSInteger = dividerIndex - 1;
        
        // Remove all the original options
        while (removalPoint >= insertionPoint) {
            menu.removeItemAtIndex(removalPoint--);
        }
        
        // ... then add all the new ones in their places
        var executableURLs:NSArray = self.controller!.importer.executableURLs;
        if (executableURLs.count > 0) {
            for executableURL in executableURLs {
                var url:NSURL = executableURL as! NSURL;
                var item:NSMenuItem = self.executableSelectorItemForURL(url);
                
                menu.insertItem(item, atIndex: insertionPoint++);
            }
            
            self.executableSelector?.selectItemAtIndex(0);
        }
        
        self.executableSelector?.synchronizeTitleAndSelectedItem();
        
        if (!self.firstTimeLoaded) {
            // First time load
            let selectedURL:NSURL = self.executableSelector?.selectedItem?.representedObject as! NSURL;
            self.executablePath = selectedURL.pathRelativeToURL(self.controller!.importer.sourceURL!.URLByDeletingLastPathComponent!);
            self.firstTimeLoaded = true;
        }
    }
    
    func executableSelectorItemForURL(URL:NSURL) -> NSMenuItem {
        var baseURL:NSURL = self.controller!.importer.sourceURL!;
        
        // Remove the base suorce path to make shorter relative paths for display
        var shortenedPath:String = URL.path!
        if (URL.isBasedInURL(baseURL)) {
            shortenedPath = URL.pathRelativeToURL(baseURL);
        }
        
        // Prettify the shortened path by using display names and converting slashes to arrows
        var nameTransformer:NSValueTransformer = NSValueTransformer(forName: "BLImportExecutableMenuTitle")!;
        var title:NSAttributedString = nameTransformer.transformedValue(shortenedPath) as! NSAttributedString;
        
        var item:NSMenuItem = NSMenuItem();
        item.representedObject = URL;
        item.title = title.string;
        
        return item;
    }
    
    func panel(sender: AnyObject, shouldEnableURL url: NSURL) -> Bool {
        return url.isBasedInURL(self.controller?.importer.sourceURL?.URLByResolvingSymlinksInPath);
    }
    
    @IBAction func showExecutablePicker(sender:AnyObject) {
        var openPanel:NSOpenPanel = NSOpenPanel();
        openPanel.delegate = self;
        openPanel.identifier = "executablePicker";
        
        openPanel.canChooseFiles = true;
        openPanel.allowsMultipleSelection = false;
        openPanel.canChooseDirectories = false;
        openPanel.treatsFilePackagesAsDirectories = true;
        openPanel.message = "Choose the Windows executable program for this game:";
        openPanel.allowedFileTypes = BLFileTypes.executableTypes()?.allObjects;
        openPanel.directoryURL = self.controller?.importer.sourceURL;
        
        openPanel.beginSheetModalForWindow(self.view.window!, completionHandler: {(result:Int) in
            if (result == NSFileHandlingPanelOKButton) {
                self.addExecutableFromURL(openPanel.URL!);
            }
            else if (result == NSFileHandlingPanelCancelButton) {
                // Revert to the first menu item if the user cancelled,
                // to avoid leaving the option that opened the picker selected
                self.executableSelector?.selectItemAtIndex(0);
            }
        });
    }
    
    @IBAction func popupDidLoseFocus(sender:AnyObject) {
        let selectedURL:NSURL = self.executableSelector?.selectedItem?.representedObject as! NSURL;
        self.executablePath = selectedURL.pathRelativeToURL(self.controller!.importer.sourceURL!.URLByDeletingLastPathComponent!);
    }
    
    func addExecutableFromURL(URL:NSURL) {
        var itemIndex:Int = self.executableSelector!.indexOfItemWithRepresentedObject(URL);
        if (itemIndex != -1) {
            // This path already exists in the menu, select it
            self.executableSelector?.selectItemAtIndex(itemIndex);
        }
        else {
            // This executable is not yet in the menu - add a new entry for it and select it
            var item:NSMenuItem = self.executableSelectorItemForURL(URL);
            self.executableSelector?.menu?.insertItem(item, atIndex: 0);
            self.executableSelector?.selectItemAtIndex(0);
        }
    }
    
    @IBAction func finaliseImport(sender:AnyObject) {
        // Move the bundle in the final directory, with the right name
        let finalName:String = self.gameTitle!.stringValue;
        // Move the final bundle in our games folder, and get ready to set the settings
        let appDlg:AppDelegate = NSApplication.sharedApplication().delegate as! AppDelegate;
        
        // Create the AppIcon
        let gameBundle:NSBundle = NSBundle(path: self.controller!.importer.temporaryBundlePath!)!
        let tempFolder:NSURL = appDlg.gamesFolderURL!.URLByAppendingPathComponent(".tmp");
        let tiffFile:NSURL = tempFolder.URLByAppendingPathComponent("TempAppIcon.tiff");
        let tiffData:NSData = self.gameIcon!.image!.TIFFRepresentation!
        let destination:NSURL = tempFolder.URLByAppendingPathComponent("AppIcon.icns");
        
        tiffData.writeToURL(tiffFile, atomically: true);
        ObjC_Helpers.systemCommand("tiff2icns \"\(tiffFile.path!)\" \"\(destination.path!)\"");
        
        // Cleanup
        NSFileManager
            .defaultManager()
            .replaceItemAtURL(gameBundle.URLForResource("AppIcon", withExtension: "icns")!,
                withItemAtURL: tempFolder.URLByAppendingPathComponent("AppIcon.icns"),
                backupItemName: nil,
                options: NSFileManagerItemReplacementOptions.allZeros,
                resultingItemURL: nil,
                error: nil
        );
        
        NSFileManager
            .defaultManager()
            .removeItemAtURL(tempFolder.URLByAppendingPathComponent("TempAppIcon.tiff"), error: nil);
        NSFileManager
            .defaultManager()
            .removeItemAtURL(tempFolder.URLByAppendingPathComponent("AppIcon.icns"), error: nil);
        
        let finalBundleURL:NSURL = NSURL(fileURLWithPath: "\(appDlg.gamesFolderURL!.path!)/\(finalName).app")!;
        NSFileManager
            .defaultManager()
            .moveItemAtPath(self.controller!.importer.temporaryBundlePath!, toPath: finalBundleURL.path!, error: nil);
        
        // Some button-specific stuff
        if let ident:String = sender.identifier {
            // If it's Close, don't do anything.
            if (ident == "importDoneShowInFinder") {
                appDlg.revealURLsInFinder([finalBundleURL]);
            }
            else if (ident == "importDoneLaunch") {
                let finalBundle:NSBundle = NSBundle(path: finalBundleURL.path!)!;
                let launchTask:NSTask = NSTask();
                launchTask.launchPath = finalBundle.executablePath!
                launchTask.launch();
            }
        }
        
        // Close the window
        self.controller?.importer.importStage = BLImporter.BLImportStage.BLImportAllDone;
    }
}

class BLImportIconDropzone: NSImageView {
    var isDragTarget:Bool = false;
    override var highlighted:Bool {
        get {
            return isDragTarget || self.window?.firstResponder == self;
        }
        set {
            super.highlighted = newValue;
        }
    }
    
    override func mouseDown(theEvent: NSEvent) {
        super.mouseUp(theEvent);
    }
    
    override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
        var result:NSDragOperation = super.draggingEntered(sender);
        if (result != NSDragOperation.None) {
            isDragTarget = true;
            self.needsDisplay = true;
        }
        
        return result;
    }
    
    override func draggingExited(sender: NSDraggingInfo?) {
        isDragTarget = false;
        self.needsDisplay = true;
        super.draggingExited(sender);
    }
    
    override func performDragOperation(sender: NSDraggingInfo) -> Bool {
        isDragTarget = false;
        self.needsDisplay = true;
        return super.performDragOperation(sender);
    }
    
    override func resignFirstResponder() -> Bool {
        if (super.resignFirstResponder()) {
            self.needsDisplay = true;
            return true;
        }
        return false;
    }
    
    override func drawRect(dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState();
        if (self.highlighted) {
            let borderRadius:CGFloat = 8.0;
            let background:NSBezierPath = NSBezierPath(roundedRect: self.bounds, xRadius: borderRadius, yRadius: borderRadius);
            let fillColour:NSColor = NSColor(calibratedRed: 0.67, green: 0.86, blue: 0.93, alpha: 0.33);
            
            fillColour.setFill();
            background.fill();
        }
        
        self.image?.drawInRect(self.bounds, fromRect: NSZeroRect, operation: NSCompositingOperation.CompositeSourceOver, fraction: 1.0);
        
        NSGraphicsContext.restoreGraphicsState();
    }
}
    