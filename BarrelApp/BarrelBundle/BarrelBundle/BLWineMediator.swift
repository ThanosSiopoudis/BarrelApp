//
//  BLWineMediator.swift
//  BarrelBundle
//
//  Created by Thanos Siopoudis on 23/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Foundation
import Darwin

class BLWineMediator {
    class func initWinePrefix() {
        BLWineMediator.makeCustomBundleIDs();
        BLWineMediator.fixWineTempFolder();
        let wineBundleURL:NSURL = NSBundle.mainBundle().privateFrameworksURL!.URLByAppendingPathComponent("blwine.bundle");
        let frameworksURL:NSURL = NSBundle.mainBundle().privateFrameworksURL!
        let resourcesURL:NSURL = NSBundle.mainBundle().resourceURL!
        // Make sure we escape any empty spaces before we export them to the path environment variable
        let wineBundlePath:String = wineBundleURL.path!.stringByReplacingOccurrencesOfString(" ", withString: "\\ ", options: NSStringCompareOptions.LiteralSearch, range: nil);
        let frameworksPath:String = frameworksURL.path!.stringByReplacingOccurrencesOfString(" ", withString: "\\ ", options: NSStringCompareOptions.LiteralSearch, range: nil);
        let resourcesPath:String = resourcesURL.path!.stringByReplacingOccurrencesOfString(" ", withString: "\\ ", options: NSStringCompareOptions.LiteralSearch, range: nil);
        
        
        let dyldFallback:String = "\(frameworksPath):\(frameworksPath)/blwine.bundle/lib:/usr/lib:/usr/libexec:/usr/lib/system:/opt/X11/lib:/opt/local/lib:/usr/X11/lib:/usr/X11R6/lib"
        var script:String = "export PATH=\"\(wineBundlePath)/bin:\(frameworksPath)/bin:$PATH:/opt/local/bin:/opt/local/sbin\";export WINEPREFIX=\"\(resourcesPath)\";DYLD_FALLBACK_LIBRARY_PATH=\"\(dyldFallback)\" wine wineboot > \"/dev/null\" 2>&1";
        
        var commandResult:String = BLWineMediator.runSystemCommand(script, waitForProcess: true);
        BLWineMediator.waitForWineserverToExitForMaximumTime(60);
        
        // Wait for all wine processes to exit gracefully
        NSThread.sleepForTimeInterval(5);
        
        // Now terminate the app
        NSApplication.sharedApplication().terminate(nil);
    }
    
    class func makeCustomBundleIDs() {
        // Create an instance to handle the callbacks
        var instance:BLWineMediator = BLWineMediator();
        
        var makeCustomBundles:Bool = true;
        let randomIntOne:Int = Int(arc4random_uniform(999999));
        let wineBundleName:String = "Barrel\(randomIntOne)Wine";
        let wineserverBundleName:String = "Barrel\(randomIntOne)Wineserver";
        
        let wineBundleURL:NSURL = NSBundle.mainBundle().privateFrameworksURL!.URLByAppendingPathComponent("blwine.bundle");
        // Look for wine binaries
        let engineBinFiles:NSArray = NSFileManager.defaultManager().contentsOfDirectoryAtURL(wineBundleURL.URLByAppendingPathComponent("bin"),
            includingPropertiesForKeys: [ NSURLNameKey ], options: NSDirectoryEnumerationOptions.allZeros, error: nil)!;
        for engineBinFileUnwr in engineBinFiles {
            let engineBinFile:NSURL = engineBinFileUnwr as NSURL;
            if (engineBinFile.path!.hasPrefix("Barrel")) {
                // Set it and bail out, it's already done
                // TODO: Save the binary name in our configuration file
                makeCustomBundles = false;
                continue;
            }
        }
        
        if (makeCustomBundles) {
            let fm:NSFileManager = NSFileManager.defaultManager();
            fm.moveItemAtURL(wineBundleURL.URLByAppendingPathComponent("bin/wine"),
                toURL: wineBundleURL.URLByAppendingPathComponent("bin/\(wineBundleName)"),
                error: nil);
            fm.moveItemAtURL(wineBundleURL.URLByAppendingPathComponent("bin/wineserver"),
                toURL: wineBundleURL.URLByAppendingPathComponent("bin/\(wineserverBundleName)"),
                error: nil);
            fm.removeItemAtURL(wineBundleURL.URLByAppendingPathComponent("bin/wine"), error: nil);
            fm.removeItemAtURL(wineBundleURL.URLByAppendingPathComponent("bin/wineserver"), error: nil);
            
            let wineBash:String = "#!/bin/bash\n\"$(dirname \"$0\")/\(wineBundleName)\" \"$@\" &";
            let wineserverBash:String = "#!/bin/bash\n\"$(dirname \"$0\")/\(wineserverBundleName)\" \"$@\" &";
            wineBash.writeToURL(wineBundleURL.URLByAppendingPathComponent("bin/wine"), atomically: true, encoding: NSUTF8StringEncoding, error: nil);
            wineserverBash.writeToURL(wineBundleURL.URLByAppendingPathComponent("bin/wineserver"), atomically: true, encoding: NSUTF8StringEncoding, error: nil);
            
            BLWineMediator.runSystemCommand("chmod -R 777 \"\(wineBundleURL.path!)/bin\"", waitForProcess: true);
        }
    }
    
    class func fixWineTempFolder() {
        // Make sure the /tmp/.wine-uid folder and lock files are correct since Wine is buggy about it
        var info:NSDictionary = NSFileManager.defaultManager().attributesOfItemAtPath(NSBundle.mainBundle().resourceURL!.path!, error: nil)!;
        var uid:String = "\(getuid())";
        
        var inode:String = "\(info[NSFileSystemFileNumber]!.longValue)";
        var deviceID:String = "\(info[NSFileSystemNumber]!.longValue)";
        var pathToWineLockFolder:String = "/tmp/.wine-\(uid)/server-\(deviceID)-\(inode)";
        if (NSFileManager.defaultManager().fileExistsAtPath(pathToWineLockFolder)) {
            NSFileManager.defaultManager().removeItemAtPath(pathToWineLockFolder, error: nil);
        }
        NSFileManager.defaultManager().createDirectoryAtPath(pathToWineLockFolder, withIntermediateDirectories: true, attributes: nil, error: nil);
        BLWineMediator.runSystemCommand("chmod -R 700 \"/tmp/.wine-\(uid)\"", waitForProcess: true);
    }
    
    class func bundleWineBinaryNames() -> NSArray {
        var results:NSMutableArray = NSMutableArray()
        
        let wineBundleURL:NSURL = NSBundle.mainBundle().privateFrameworksURL!.URLByAppendingPathComponent("blwine.bundle");
        let engineBinFiles:NSArray = NSFileManager.defaultManager().contentsOfDirectoryAtURL(wineBundleURL.URLByAppendingPathComponent("bin"),
            includingPropertiesForKeys: [ NSURLNameKey ], options: NSDirectoryEnumerationOptions.allZeros, error: nil)!;
        for engineBinFileUnwr in engineBinFiles {
            let engineBinFile:NSURL = engineBinFileUnwr as NSURL;
            if (engineBinFile.path!.hasPrefix("Barrel")) {
                results.addObject(engineBinFile.path!.lastPathComponent);
            }
        }
        
        return results;
    }
    
    class func waitForWineserverToExitForMaximumTime(seconds:Int) {
        // Find out our wine bin names
        let binaryNames:NSArray = BLWineMediator.bundleWineBinaryNames();
        var wineserverName:String = "";
        for binaryname in binaryNames {
            let binary:String = binaryname as String;
            if (NSString(string: binary).hasSuffix("wineserver")) {
                wineserverName = binary;
            }
        }
        
        NSThread.sleepForTimeInterval(10);
        for (var i:Int = 0; i < seconds; i++) {
            var stillRunning:Bool = false;
            let commandResult:String = BLWineMediator.runSystemCommand("ps -eo pcpu,pid,args | grep \"\(wineserverName)\"", waitForProcess: true);
            let resultArray:NSArray = NSString(string: commandResult).componentsSeparatedByString(" ");
            var cleanArray:NSMutableArray = NSMutableArray();
            for item in resultArray {
                let rowItem:String = item as String;
                if (countElements(rowItem) > 0) {
                    cleanArray.addObject(rowItem);
                }
            }
            
            if (cleanArray.count > 0) {
                for (var x:Int = 0; x < cleanArray.count; x++) {
                    let cleanArrayEntry:String = cleanArray.objectAtIndex(x) as String;
                    var test:NSString = NSString(string:cleanArrayEntry);
                    var strRange:NSRange = test.rangeOfString(wineserverName);
                    var stuckRange:NSRange = test.rangeOfString(")");
                    var previousObject:NSString = NSString(string: (cleanArray.objectAtIndex(x - 1) as String));
                    if ((strRange.location != NSNotFound && stuckRange.location != NSNotFound) &&
                        previousObject.isEqualToString("grep")) {
                            stillRunning = true;
                    }
                }
            }
            
            if (!stillRunning) {
                return;
            }
            NSThread.sleepForTimeInterval(1);
        }
        
        // Looks like it's stuck. Kill everything
        BLWineMediator.killAllWineProcesses();
    }
    
    class func killAllWineProcesses() {
        let binaryNames:NSArray = BLWineMediator.bundleWineBinaryNames();
        let wineName:String = binaryNames.objectAtIndex(0) as String;
        let wineserverName:String = binaryNames.objectAtIndex(1) as String;
        
        BLWineMediator.runSystemCommand("killall -9 \"\(wineName)\" > /dev/null 2>&1", waitForProcess: true);
        BLWineMediator.runSystemCommand("killall -9 \"\(wineserverName)\" > /dev/null 2>&1", waitForProcess: true);
    }
    
    func didFinishCommand(notification:NSNotification) {
        NSLog("Finished CHModding");
    }
    
    class func runSystemCommand(command:String, waitForProcess shouldWait:Bool) -> String {
        var returnString:String = "";
        var fp:UnsafeMutablePointer<FILE>;
        let bufsize = 512;
        var buff = UnsafeMutablePointer<Int8>.alloc(bufsize)
        fp = popen(NSString(string: command).cStringUsingEncoding(NSUTF8StringEncoding), "r");
        if (shouldWait) {
            while (fgets(buff, CInt(bufsize), fp) != nil) {
                returnString += NSString(CString: buff, encoding: NSUTF8StringEncoding)!;
            }
            
            pclose(fp);
        }
        
        return returnString;
    }
    
    class func startTaskWithCommand(command:String, arguments args:NSArray, observer:AnyObject) {
        var task:NSTask = NSTask();
        task.launchPath = command;
        task.arguments = args;
        
        let stdout:NSPipe = NSPipe();
        let stderr:NSPipe = NSPipe();
        
        task.standardOutput = stdout;
        task.standardError = stderr;
        
        var fhStdout:NSFileHandle = stdout.fileHandleForReading;
        fhStdout.waitForDataInBackgroundAndNotify();
        NSNotificationCenter.defaultCenter().addObserver(observer, selector: Selector("didReceiveStdoutData:"), name: NSFileHandleDataAvailableNotification, object: fhStdout);
        NSNotificationCenter.defaultCenter().addObserver(observer, selector: Selector("didFinishCommand:"), name: NSFileHandleReadToEndOfFileCompletionNotification, object: fhStdout);
        
        var fhStdErr:NSFileHandle = stderr.fileHandleForReading;
        fhStdErr.waitForDataInBackgroundAndNotify();
        NSNotificationCenter.defaultCenter().addObserver(observer, selector: Selector("didReceiveStderrData:"), name: NSFileHandleDataAvailableNotification, object: fhStdErr);
        
        task.launch();
    }
}