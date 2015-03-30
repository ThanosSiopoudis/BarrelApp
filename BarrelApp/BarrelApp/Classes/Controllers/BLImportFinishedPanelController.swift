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
    
    override init() {
        var nameTransformer:BLDisplayPathTransformer = BLDisplayPathTransformer(joiner: " ▸ ", maxComponents: 0);
        NSValueTransformer.setValueTransformer(nameTransformer, forName: "BLImportExecutableMenuTitle");
        
        super.init();
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder);
    }
    
    override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
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
        var attrString:NSAttributedString = NSAttributedString(string: title, attributes: attrDict);
        self.titleText!.attributedStringValue = attrString;
        
        self.controller?.addObserver(self, forKeyPath: "importer.executableURLs", options: NSKeyValueObservingOptions.allZeros, context: nil);
        self.controller?.addObserver(self, forKeyPath: "importer.detectedGameName", options: NSKeyValueObservingOptions.allZeros, context: nil);
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if (keyPath == "importer.executableURLs") {
            self.syncExecutableSelectorItems();
        }
        else if (keyPath == "importer.detectedGameName") {
            self.gameTitle!.stringValue = self.controller!.importer.detectedGameName!;
        }
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
                var url:NSURL = executableURL as NSURL;
                var item:NSMenuItem = self.executableSelectorItemForURL(url);
                
                menu.insertItem(item, atIndex: insertionPoint++);
            }
            
            self.executableSelector?.selectItemAtIndex(0);
        }
        
        self.executableSelector?.synchronizeTitleAndSelectedItem();
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
        var title:NSAttributedString = nameTransformer.transformedValue(shortenedPath) as NSAttributedString;
        
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
}
    