//
//  BLImportInstallerPanelController.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 14/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Foundation

class BLImportInstallerPanelController: NSViewController, NSOpenSavePanelDelegate {
    
    @IBOutlet weak var titleText:NSTextField?
    @IBOutlet var controller:BLImportWindowController?
    @IBOutlet weak var installerSelector:NSPopUpButton?
    @IBOutlet weak var engineSelector:NSPopUpButton?

    required init?(coder: NSCoder) {
        super.init(coder: coder);
    }
    
    override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        var nameTransformer:BLDisplayPathTransformer = BLDisplayPathTransformer(joiner: " ▸ ", maxComponents: 0);
        NSValueTransformer.setValueTransformer(nameTransformer, forName: "BLImportInstallerMenuTitle");
        
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil);
    }
    
    override func awakeFromNib() {
        var title:String = self.titleText!.stringValue;
        
        var textColour:NSColor = NSColor.whiteColor();
        var theFont:NSFont = NSFont(name: "Avenir Next", size: 32.0)!
        var textParagraph:NSMutableParagraphStyle = NSMutableParagraphStyle();
        textParagraph.lineSpacing = 6.0;
        textParagraph.maximumLineHeight = 38.0;
        textParagraph.alignment = NSTextAlignment.CenterTextAlignment;
        
        var attrDict:NSDictionary = NSDictionary(objectsAndKeys: theFont, NSFontAttributeName, textColour, NSForegroundColorAttributeName, textParagraph, NSParagraphStyleAttributeName);
        var attrString:NSAttributedString = NSAttributedString(string: title, attributes: attrDict as [NSObject : AnyObject]);
        self.titleText!.attributedStringValue = attrString;
        
        
        
        self.controller?.addObserver(self, forKeyPath: "importer.installerURLs", options: NSKeyValueObservingOptions.allZeros, context: nil);
        self.controller?.addObserver(self, forKeyPath: "importer.enginesList", options: NSKeyValueObservingOptions.allZeros, context: nil);
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if (keyPath == "importer.installerURLs") {
            self.syncInstallerSelectorItems();
        }
        else if (keyPath == "importer.enginesList") {
            self.syncEngineSelectorItems();
        }
    }
    
    func syncInstallerSelectorItems() {
        var menu:NSMenu = self.installerSelector!.menu!;
        
        let dividerIndex:NSInteger = menu.indexOfItemWithTag(1);
        assert(dividerIndex > -1, "Menu Divider not found.");
        
        var insertionPoint:NSInteger = 0;
        var removalPoint:NSInteger = dividerIndex - 1;
        
        // Remove all the original options
        while (removalPoint >= insertionPoint) {
            menu.removeItemAtIndex(removalPoint--);
        }
        
        // ... then add all the new ones in their places
        var installerURLs:NSArray = self.controller!.importer.installerURLs;
        if (installerURLs.count > 0) {
            for installerURL in installerURLs {
                var url:NSURL = installerURL as! NSURL;
                var item:NSMenuItem = self.installerSelectorItemForURL(url);
                
                menu.insertItem(item, atIndex: insertionPoint++);
            }
            
            self.installerSelector?.selectItemAtIndex(0);
        }
        
        self.installerSelector?.synchronizeTitleAndSelectedItem();
    }
    
    func installerSelectorItemForURL(URL:NSURL) -> NSMenuItem {
        var baseURL:NSURL = self.controller!.importer.sourceURL!;
        
        // Remove the base suorce path to make shorter relative paths for display
        var shortenedPath:String = URL.path!
        if (URL.isBasedInURL(baseURL)) {
            shortenedPath = URL.pathRelativeToURL(baseURL);
        }
        
        // Prettify the shortened path by using display names and converting slashes to arrows
        var nameTransformer:NSValueTransformer = NSValueTransformer(forName: "BLImportInstallerMenuTitle")!;
        var title:NSAttributedString = nameTransformer.transformedValue(shortenedPath) as! NSAttributedString;
        
        var item:NSMenuItem = NSMenuItem();
        item.representedObject = URL;
        item.title = title.string;
        
        return item;
    }
    
    func syncEngineSelectorItems() {
        var menu:NSMenu = self.engineSelector!.menu!;
        
        let dividerIndex:NSInteger = menu.indexOfItemWithTag(1);
        assert(dividerIndex > -1, "Menu Divider not found.");
        
        var insertionPoint:NSInteger = 0;
        var removalPoint:NSInteger = dividerIndex - 1;
        
        // Remove all the original options
        while (removalPoint >= insertionPoint) {
            menu.removeItemAtIndex(removalPoint--);
        }
        
        // ... then add all the new ones in their places
        var enginesList:NSArray = self.controller!.importer.enginesList;
        if (enginesList.count > 0) {
            for abstractEngine in enginesList {
                var engine:Engine = abstractEngine as! Engine;
                var item:NSMenuItem = NSMenuItem();
                item.representedObject = engine;
                item.title = engine.Name;
                
                menu.insertItem(item, atIndex: insertionPoint++);
            }
            
            self.engineSelector?.selectItemAtIndex(0);
        }
        
        self.engineSelector?.synchronizeTitleAndSelectedItem();
    }
    
    func panel(sender: AnyObject, shouldEnableURL url: NSURL) -> Bool {
        return url.isBasedInURL(self.controller?.importer.sourceURL) || sender.identifier == "enginePicker";
    }
    
    @IBAction func showEnginePicker(sender:AnyObject) {
        var openPanel:NSOpenPanel = NSOpenPanel();
        openPanel.delegate = self;
        openPanel.identifier = "enginePicker";
        
        openPanel.canChooseFiles = true;
        openPanel.allowsMultipleSelection = false;
        openPanel.canChooseDirectories = false;
        openPanel.treatsFilePackagesAsDirectories = false;
        openPanel.message = "Choose the custom or local Wine engine for this game:";
        openPanel.allowedFileTypes = ["zip"]; // Maybe add more archive types in the future
        
        openPanel.beginSheetModalForWindow(self.view.window!, completionHandler: {(result:Int) in
            if (result == NSFileHandlingPanelOKButton) {
                self.addEngineFromURL(openPanel.URL!);
            }
            else {
                self.engineSelector?.selectItemAtIndex(0);
            }
        });
    }
    
    @IBAction func launchInstaller(sender:AnyObject) {
        let installerURL:NSURL = self.installerSelector?.selectedItem?.representedObject as! NSURL;
        let engine:Engine = self.engineSelector?.selectedItem?.representedObject as! Engine;
        self.controller?.importer.launchInstallerAtURL(installerURL, withEngine: engine);
    }
    
    @IBAction func showInstallerPicker(sender:AnyObject) {
        var openPanel:NSOpenPanel = NSOpenPanel();
        openPanel.delegate = self;
        openPanel.identifier = "installerPicker";
        
        openPanel.canChooseFiles = true;
        openPanel.allowsMultipleSelection = false;
        openPanel.canChooseDirectories = false;
        openPanel.treatsFilePackagesAsDirectories = false;
        openPanel.message = "Choose the Windows installer program for this game:";
        openPanel.allowedFileTypes = BLFileTypes.executableTypes()?.allObjects;
        openPanel.directoryURL = self.controller?.importer.sourceURL;
        
        openPanel.beginSheetModalForWindow(self.view.window!, completionHandler: {(result:Int) in
            if (result == NSFileHandlingPanelOKButton) {
                self.addInstallerFromURL(openPanel.URL!);
            }
            else if (result == NSFileHandlingPanelCancelButton) {
                // Revert to the first menu item if the user cancelled,
                // to avoid leaving the option that opened the picker selected
                self.installerSelector?.selectItemAtIndex(0);
            }
        });
    }
    
    func addEngineFromURL(URL:NSURL) {
        // Create a new Engine Object
        var localEngine:Engine = Engine();
        var lastPathComponent:String! = URL.lastPathComponent;
        localEngine.Name = lastPathComponent.stringByDeletingPathExtension;
        localEngine.Path = URL.path!;
        localEngine.isRemote = false;
        
        var itemIndex:Int = self.engineSelector!.indexOfItemWithRepresentedObject(URL);
        if (itemIndex != -1) {
            // This path already exists in the menu, select it
            self.engineSelector?.selectItemAtIndex(itemIndex);
        }
        else {
            var item:NSMenuItem = NSMenuItem();
            item.representedObject = localEngine;
            item.title = localEngine.Name;
        
            // This engine is not yet in the menu 0 add a new entry for it and select it
            self.engineSelector?.menu?.insertItem(item, atIndex: 0);
            self.engineSelector?.selectItemAtIndex(0);
        }
    }
    
    func addInstallerFromURL(URL:NSURL) {
        var itemIndex:Int = self.installerSelector!.indexOfItemWithRepresentedObject(URL);
        if (itemIndex != -1) {
            // This path already exists in the menu, select it
            self.installerSelector?.selectItemAtIndex(itemIndex);
        }
        else {
            // This installer is not yet in the menu - add a new entry for it and select it
            var item:NSMenuItem = self.installerSelectorItemForURL(URL);
            self.installerSelector?.menu?.insertItem(item, atIndex: 0);
            self.installerSelector?.selectItemAtIndex(0);
        }
    }
}