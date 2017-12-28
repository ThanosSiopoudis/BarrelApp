//
//  BLWinetricksPanelController.swift
//  BarrelBundle
//
//  Created by Thanos Siopoudis on 26/07/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Foundation
import AppKit

class BLWinetricksPanelController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    @IBOutlet weak var winetricksOutline:NSOutlineView!
    @IBOutlet weak var progressBar:NSProgressIndicator!
    @IBOutlet weak var progressText:NSTextField!
    @IBOutlet var winetricksOutput: NSTextView!
    
    var winetricksDatasource:NSMutableDictionary?
    var winetricksPlistURL:NSURL?
    var wineIsRunning:Bool = false;
    var winetricksArgs:String = "";
    var winetricksFinalCommand:String = "";
    
    override func viewDidLoad() {
        super.viewDidLoad();
        
        self.progressBar.hidden = false;
        self.progressBar.startAnimation(nil);
        self.progressText.hidden = false;
        self.progressText.stringValue = "Initialising...";
        self.winetricksPlistURL = NSBundle.mainBundle().resourceURL!.URLByAppendingPathComponent("Winetricks.plist");
        
        // Start winetricks initialisation
        // 1. Check for a cached winetricks .plist dataSource
        var shouldUpdateWinetricks:Bool = !NSFileManager.defaultManager().fileExistsAtPath(self.winetricksPlistURL!.path!);
        shouldUpdateWinetricks = shouldUpdateWinetricks || self.isWinetricksOld();
        
        // 1.1 If not found, or older than 1 week, fetch from the internet and parse
        if (shouldUpdateWinetricks) {
            self.progressText.stringValue = "Updating Winetricks...";
            self.doWinetricksUpdateAndParse({(result:Int) in
                self.prepareOutlineViewDataSource();
                self.winetricksOutline.reloadData();
                self.progressText.hidden = true;
                self.progressBar.stopAnimation(nil);
                self.progressBar.hidden = true;
            });
        }
        else {
            self.prepareOutlineViewDataSource();
            self.progressText.hidden = true;
            self.progressBar.stopAnimation(nil);
            self.progressBar.hidden = true;
        }
    }
    
    // MARK: - NSOutlineView DataSource & Delegate
    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        if (item == nil) {
            if let wDataSource = self.winetricksDatasource {
                // Get the key by index
                let keys:NSArray = wDataSource.allKeys as NSArray;
                let theKey:String = keys.objectAtIndex(index) as! String;
                return theKey
            }
        }
        else {
            if let wDataSource = self.winetricksDatasource {
                let items:NSArray? = wDataSource.objectForKey(item!) as? NSArray;
                if let itArray = items {
                    return itArray.objectAtIndex(index);
                }
            }
        }
        
        return "";
    }
    
    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        var cnt:Int = 0;
        if let wDataSource = self.winetricksDatasource {
            if (item == nil) { // root
                cnt = wDataSource.allKeys.count;
            }
            else {
                if let cItem = wDataSource.objectForKey(item!) as? NSMutableArray {
                    cnt = cItem.count;
                }
            }
        }
        
        return cnt;
    }
    
    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        var children:Int = 0;
        if let entry:NSMutableArray = self.winetricksDatasource?.objectForKey(item) as? NSMutableArray {
            children = entry.count;
        }
        
        return children > 1 ? true : false;
    }

    func outlineView(outlineView: NSOutlineView, objectValueForTableColumn tableColumn: NSTableColumn?, byItem item: AnyObject?) -> AnyObject? {
        var cell:NSCell = tableColumn?.dataCell as! NSCell;
        if let wDataSource = self.winetricksDatasource {
            if let it = wDataSource.objectForKey(item!) as? NSArray {
                if (tableColumn?.headerCell.stringValue == "Winetrick") {
                    return item?.capitalizedString;
                }
                else if (tableColumn?.headerCell.stringValue == "Install") {
                    return nil;
                }
                else {
                    return "";
                }
            }
            else {
                if (tableColumn?.identifier == "winetrick") {
                    return item?.objectForKey("winetrick");
                }
                else if (tableColumn?.identifier == "description") {
                    return item?.objectForKey("title");
                }
                else {
                    if let selItem = item?.objectForKey("selected") as? Int {
                        cell.state = selItem;
                    }
                    
                    return cell;
                }
            }
        }
        
        return cell;
    }

    func outlineView(outlineView: NSOutlineView, dataCellForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSCell? {
        var cell:NSCell? = tableColumn?.dataCell as? NSCell;
        if (tableColumn?.headerCell.stringValue == "Install" && item.isKindOfClass(NSString)) {
            cell = NSCell(textCell: "");
        }
        
        return cell;
    }
    
    func outlineView(outlineView: NSOutlineView, setObjectValue object: AnyObject?, forTableColumn tableColumn: NSTableColumn?, byItem item: AnyObject?) {
        if (tableColumn?.identifier == "install") {
            item?.setObject(object, forKey: "selected");
        }
    }
    
    @IBAction func executeWinetricks(sender:AnyObject) {
        // Clean up the output
        self.winetricksOutput.string = "";
        self.winetricksArgs = "";
        
        var winetricksVerbs:String = "winetricks";
        
        if let categories = self.winetricksDatasource?.allKeys {
            for category in categories {
                if let categoryItems:NSMutableArray = self.winetricksDatasource?.objectForKey(category) as? NSMutableArray {
                    for item in categoryItems {
                        let catItem:NSMutableDictionary = item as! NSMutableDictionary;
                        let selected:AnyObject? = catItem.objectForKey("selected");
                        if let sel:NSNumber = selected as? NSNumber {
                            if (sel == 1) {
                                let winetrick:String = catItem.objectForKey("winetrick") as! String;
                                winetricksVerbs = "\(winetricksVerbs) \(winetrick)";
                                self.winetricksArgs += " " + winetrick;
                            }
                        }
                    }
                }
            }
        }
        
        if (winetricksVerbs != "winetricks") {
            self.winetricksFinalCommand = NSBundle.mainBundle().privateFrameworksPath! + "bin/winetricks";
        }
        
        let alert:NSAlert = NSAlert();
        alert.messageText = "Winetricks Ready";
        alert.informativeText = "The following command will be executed:\n\(winetricksVerbs)\nAre you sure you want to proceed?";
        alert.addButtonWithTitle("OK");
        alert.addButtonWithTitle("Cancel");
        let res = alert.runModal();
        if res == NSAlertFirstButtonReturn {
            self.runWinetricksCommand(alert);
        }
    }
    
    @IBAction func runWinetricksCommand(sender:AnyObject) {
        self.progressBar.hidden = false;
        self.progressBar.startAnimation(nil);
        self.progressText.hidden = false;
        self.progressText.stringValue = "Running Winetricks...";
        
        BLWineMediator.runWinetricksWithArgs(self.winetricksArgs, observer: self);
    }
    
    func didFinish(notif: NSNotification) {
        // Run on the main thread
        dispatch_async(dispatch_get_main_queue(), {()
            self.progressBar.hidden = true;
            self.progressBar.stopAnimation(nil);
            self.progressText.hidden = true;
        });
    }
    
    func didReceiveData(notif: NSNotification) {
        // Run on the main thread
        dispatch_async(dispatch_get_main_queue(), {()
            let str:NSString = notif.object as! NSString;
            
            let strOut:String = "\(self.winetricksOutput.string!)\(str)";
            self.winetricksOutput.string = strOut;
            
            // Scroll to Bottom
            self.winetricksOutput.scrollRangeToVisible(NSMakeRange(self.winetricksOutput.string!.characters.count, 0));
        });
    }
    
    // MARK: - Other Methods
    func isWinetricksOld() -> Bool {
        let fileURL:NSURL = NSBundle.mainBundle().privateFrameworksURL!.URLByAppendingPathComponent("bin/winetricks");
        var resource:AnyObject? = nil;
        do {
            try fileURL.getResourceValue(&resource, forKey: NSURLContentModificationDateKey);
            if let fileDate = resource as? NSDate {
                if (fileDate.timeIntervalSinceNow <= -(3600 * 24 * 7)) {
                    // Delete the old winetricks and create a new one
                    try NSFileManager.defaultManager().removeItemAtURL(fileURL);
                    return true;
                }
            }
        }
        catch {
            return false;
        }
        
        return false;
    }
    
    func prepareOutlineViewDataSource() {
        self.winetricksDatasource = NSMutableDictionary();
        if let wTricksPlistURL = self.winetricksPlistURL {
            if let infoPlist:NSMutableDictionary = NSMutableDictionary(contentsOfURL: wTricksPlistURL) {
                // Create a compatible array
                if let items:NSArray = infoPlist.objectForKey("winetricks") as? NSArray {
                    for item in items {
                        if (self.winetricksDatasource!.objectForKey(item.objectForKey("category") as! String) == nil) {
                            let catName:String = item.objectForKey("category") as! String;
                            self.winetricksDatasource!.setObject(NSMutableArray(object: item), forKey: catName);
                        }
                        else {
                            let catName:String = item.objectForKey("category") as! String;
                            if let inArray:NSMutableArray = self.winetricksDatasource!.objectForKey(catName) as? NSMutableArray {
                                item.setObject(NSNumber(bool: false), forKey: "selected");
                                inArray.addObject(item);
                            }
                        }
                    }
                }
            }
        }
    }
    
    func doWinetricksUpdateAndParse(complete:(result:Int) -> Void) {
        let winetricksURL:NSURL? = NSURL(string: "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks");
        let tempDir:NSURL? = NSURL(fileURLWithPath: NSTemporaryDirectory());
        let downloader:BLFileDownloader = BLFileDownloader(saveURL: tempDir);
        downloader.downloadWithNSURLConnectionFromURL(winetricksURL, completionBlock: {(result:Int, resultURL:NSURL) in
            if (result == 1) {
                let winetricksForPlist:NSMutableArray = NSMutableArray();
                
                // Load the file contents in the memory
                if let file = NSFileHandle(forReadingAtPath: resultURL.path!) {
                    let fileData = file.readDataToEndOfFile();
                    if let dataString:NSString = NSString(data: fileData, encoding: NSASCIIStringEncoding) {
                        // Look for the word "w_metadata" in the string
                        let length:Int = dataString.length;
                        var range:NSRange = NSMakeRange(0, length);
                        while (range.location != NSNotFound) {
                            range = dataString.rangeOfString("w_metadata", options: [], range: range);
                            if (range.location != NSNotFound) {
                                let outerRange:NSRange = NSMakeRange(range.location + range.length, length - (range.location + range.length));
                                // Found an occurence. Make sure it's an entry
                                // 1st: Get the two characters before the entry
                                // to make sure they are both newlines
                                let m3:String = dataString.substringWithRange(NSMakeRange(range.location + range.length, 1));
                                let m2:String = dataString.substringWithRange(NSMakeRange(range.location - 2, 1));
                                let m1:String = dataString.substringWithRange(NSMakeRange(range.location - 1, 1));
                                if ((m2 == "\n" || m2 == "\"") && m1 == "\n" && m3 == " ") {
                                    // It's an entry. Parse it
                                    // Get the whole line
                                    var lineRange:NSRange = dataString.rangeOfString("\n", options: [], range: outerRange);
                                    
                                    // Calculate the line range
                                    lineRange = NSMakeRange(range.location, lineRange.location - range.location);
                                    
                                    // Split the space separated string in an array
                                    let winetricksComponents:NSArray = dataString.substringWithRange(lineRange).componentsSeparatedByString(" ");
                                    // Malformatted file workaround
                                    // There seems to be an extra space, so detect it and ignore it
                                    let entry:NSMutableDictionary = NSMutableDictionary();
                                    if (winetricksComponents.count > 0) {
                                        let firstComponent = winetricksComponents.objectAtIndex(1) as! String;
                                        if (firstComponent.characters.count == 0) {
                                            entry.setObject(winetricksComponents.objectAtIndex(2), forKey: "winetrick");
                                            entry.setObject(winetricksComponents.objectAtIndex(3), forKey: "category");
                                        }
                                        else {
                                            entry.setObject(winetricksComponents.objectAtIndex(1), forKey: "winetrick");
                                            entry.setObject(winetricksComponents.objectAtIndex(2), forKey: "category");
                                        }
                                        
                                        winetricksForPlist.addObject(entry);
                                    }
                                    
                                    // Find and parse the winetrick title
                                    let titleRange:NSRange = dataString.rangeOfString("title=\"", options: [], range: outerRange);
                                    let endTitleRange:NSRange = dataString.rangeOfString("\"",
                                        options: [],
                                        range: NSMakeRange(titleRange.location + 7, length - (titleRange.location + 7)));
                                    // Now read the title in the range
                                    let title:String = dataString.substringWithRange(
                                        NSMakeRange(titleRange.location + 7, (endTitleRange.location - (titleRange.location + 7)))
                                    );
                                    entry.setObject(title, forKey: "title");
                                }
                                
                                // Advance the range
                                range = NSMakeRange(range.location + range.length, length - (range.location + range.length));
                            }
                        }
                        
                        // Write the array to the plist file
                        let newDict:NSMutableDictionary = NSMutableDictionary();
                        newDict.setObject(winetricksForPlist, forKey: "winetricks");
                        newDict.writeToURL(NSBundle.mainBundle().resourceURL!.URLByAppendingPathComponent("Winetricks.plist"), atomically: true);
                        
                        
                        let destinationURL:NSURL = NSBundle.mainBundle().privateFrameworksURL!.URLByAppendingPathComponent("bin/winetricks");
                        do {
                            try NSFileManager.defaultManager().moveItemAtURL(resultURL,
                                toURL: destinationURL);
                        }
                        catch {
                            print(error);
                        }
                        
                        // Finally, change the binary rights
                        ObjC_Helpers.systemCommand("chmod 755 \"\(destinationURL.path!)\"");
                    }
                }
            }
            
            complete(result: result);
        });
        downloader.startDownload();
    }
}