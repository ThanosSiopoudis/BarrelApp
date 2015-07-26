//
//  BLWinetricksPanelController.swift
//  BarrelBundle
//
//  Created by Thanos Siopoudis on 26/07/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Foundation

class BLWinetricksPanelController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {

    override func viewDidLoad() {
        super.viewDidLoad();
        
        // Start winetricks initialisation
        // 1. Check for a cached winetricks .plist dataSource
        
        // 1.1 If found, load
        
        // 1.2 If not found, fetch from the internet and parse
        self.doWinetricksUpdateAndParse();
        
        // 2. Render the options in the outline view
        
    }
    
    func doWinetricksUpdateAndParse() {
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
                            range = dataString.rangeOfString("w_metadata", options: NSStringCompareOptions.allZeros, range: range);
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
                                    var lineRange:NSRange = dataString.rangeOfString("\n", options: NSStringCompareOptions.allZeros, range: outerRange);
                                    
                                    // Calculate the line range
                                    lineRange = NSMakeRange(range.location, lineRange.location - range.location);
                                    
                                    // Split the space separated string in an array
                                    let winetricksComponents:NSArray = dataString.substringWithRange(lineRange).componentsSeparatedByString(" ");
                                    // Malformatted file workaround
                                    // There seems to be an extra space, so detect it and ignore it
                                    let entry:NSMutableDictionary = NSMutableDictionary();
                                    if (winetricksComponents.count > 0) {
                                        let firstComponent = winetricksComponents.objectAtIndex(1) as! String;
                                        if (count(firstComponent) == 0) {
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
                                    let titleRange:NSRange = dataString.rangeOfString("title=\"", options: NSStringCompareOptions.allZeros, range: outerRange);
                                    let endTitleRange:NSRange = dataString.rangeOfString("\"",
                                        options: NSStringCompareOptions.allZeros,
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
                        
                    }
                }
            }
        });
        downloader.startDownload();
    }
}