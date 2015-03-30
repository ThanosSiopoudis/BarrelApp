//
//  BLWineMediator.swift
//  BarrelBundle
//
//  Created by Thanos Siopoudis on 23/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Foundation
import Darwin

class BLWineMediator:NSObject {
    let resourcesURL:NSURL = NSBundle.mainBundle().resourceURL!

    var wineBundlePath:String = NSBundle.mainBundle().privateFrameworksPath! + "/blwine.bundle";
    var frameworksPath:String = NSBundle.mainBundle().privateFrameworksPath!
    var winePrefixPath:String = NSBundle.mainBundle().resourcePath!
    var dyldFallbackPath:String;
    
    override init() {
        self.dyldFallbackPath = "\(self.frameworksPath):\(self.frameworksPath)/blwine.bundle/lib:/usr/lib:/usr/libexec:/usr/lib/system:/opt/X11/lib:/opt/local/lib:/usr/X11/lib:/usr/X11R6/lib";
        
        super.init();
    }
    
    class func initWinePrefix() {
        var that:BLWineMediator = BLWineMediator();
        
        BLWineMediator.makeCustomBundleIDs();
        BLWineMediator.fixWineTempFolder();
        
        var script:String = "export WINEDLLOVERRIDES=\"mscoree,mshtml=\";export PATH=\"\(that.wineBundlePath)/bin:\(that.frameworksPath)/bin:$PATH:/opt/local/bin:/opt/local/sbin\";export WINEPREFIX=\"\(that.winePrefixPath)\";DYLD_FALLBACK_LIBRARY_PATH=\"\(that.dyldFallbackPath)\" wine wineboot > /dev/null 2>&1";
        
        // Start on a separate thread, to prevent the main app from killing itself
        let dQueue:dispatch_queue_t = dispatch_queue_create("uk.co.barrelapp.wineserverWatcher", DISPATCH_QUEUE_CONCURRENT);
        dispatch_async(dQueue, {()
            ObjC_Helpers.systemCommand(script);
        });
        BLWineMediator.waitForWineserverToExitForMaximumTime(60);
        
        // Wait for all wine processes to exit gracefully
        NSThread.sleepForTimeInterval(5);
        
        // Create a symlink to the C:\ drive
        NSFileManager.defaultManager().createSymbolicLinkAtPath("\(NSBundle.mainBundle().bundlePath)/drive_c", withDestinationPath: "\(that.winePrefixPath)/drive_c", error: nil);
        
        // Use unique enclosed document folders instead of the global ones by default
        // Remove the symlinks
        NSFileManager.defaultManager().removeItemAtPath("\(that.winePrefixPath)/drive_c/users/\(NSUserName())/My Documents", error: nil);
        NSFileManager.defaultManager().removeItemAtPath("\(that.winePrefixPath)/drive_c/users/\(NSUserName())/My Music", error: nil);
        NSFileManager.defaultManager().removeItemAtPath("\(that.winePrefixPath)/drive_c/users/\(NSUserName())/My Pictures", error: nil);
        NSFileManager.defaultManager().removeItemAtPath("\(that.winePrefixPath)/drive_c/users/\(NSUserName())/My Videos", error: nil);
        
        // ... and create actual directories
        NSFileManager.defaultManager().createDirectoryAtPath("\(that.winePrefixPath)/drive_c/users/\(NSUserName())/My Documents",
            withIntermediateDirectories: false,
            attributes: nil, error: nil);
        NSFileManager.defaultManager().createDirectoryAtPath("\(that.winePrefixPath)/drive_c/users/\(NSUserName())/My Music",
            withIntermediateDirectories: false,
            attributes: nil, error: nil);
        NSFileManager.defaultManager().createDirectoryAtPath("\(that.winePrefixPath)/drive_c/users/\(NSUserName())/My Pictures",
            withIntermediateDirectories: false,
            attributes: nil, error: nil);
        NSFileManager.defaultManager().createDirectoryAtPath("\(that.winePrefixPath)/drive_c/users/\(NSUserName())/My Videos",
            withIntermediateDirectories: false,
            attributes: nil, error: nil);
        
        // Finally, make sure access rights are a-ok
        ObjC_Helpers.systemCommand("chmod -R 777 \(NSBundle.mainBundle().bundlePath)/Contents/*");
        
        // Now terminate the app
        NSApplication.sharedApplication().terminate(nil);
    }
    
    class func executeBinary(path:String, withStart useStart:Bool, waitForExit:Bool) {
        BLWineMediator.fixWineTempFolder();
        var that:BLWineMediator = BLWineMediator();
        
        let binaryPath:String = path.stringByDeletingLastPathComponent;
        let binaryName:String = path.lastPathComponent;
        var script:String = "export PATH=\"\(that.wineBundlePath)/bin:\(that.frameworksPath)/bin:$PATH:/opt/local/bin:/opt/local/sbin\";export WINEPREFIX=\"\(that.winePrefixPath)\";cd \"\(binaryPath)\";DYLD_FALLBACK_LIBRARY_PATH=\"\(that.dyldFallbackPath)\" wine \"\(binaryName)\" > \"/dev/null\" 2>&1";
        if (useStart) {
            script = "export PATH=\"\(that.wineBundlePath)/bin:\(that.frameworksPath)/bin:$PATH:/opt/local/bin:/opt/local/sbin\";export WINEPREFIX=\"\(that.winePrefixPath)\";cd \"\(binaryPath)\";DYLD_FALLBACK_LIBRARY_PATH=\"\(that.dyldFallbackPath)\" wine start /unix \"\(binaryName)\" > \"/dev/null\" 2>&1";
        }
        
        // Start on a separate thread, to prevent the main app from killing itself
        let dQueue:dispatch_queue_t = dispatch_queue_create("uk.co.barrelapp.wineserverWatcher", DISPATCH_QUEUE_CONCURRENT);
        dispatch_async(dQueue, {()
            ObjC_Helpers.systemCommand(script);
        });
        
        if (waitForExit) {
            BLWineMediator.waitForWineserverToExitForMaximumTime(0);
            
            // Wait for all wine processes to exit gracefully
            NSThread.sleepForTimeInterval(5);
        }
        
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
            
            ObjC_Helpers.systemCommand("chmod -R 777 \"\(wineBundleURL.path!)/bin\"");
        }
    }
    
    class func fixWineTempFolder() {
        // Make sure the /tmp/.wine-uid folder and lock files are correct since Wine complains about it
        var info:NSDictionary = NSFileManager.defaultManager().attributesOfItemAtPath(NSBundle.mainBundle().resourceURL!.path!, error: nil)!;
        var uid:String = "\(getuid())";
        
        var inode:String = String(format: "%lx", info[NSFileSystemFileNumber]!.longValue);
        var deviceID:String = String(format: "%lx", info[NSFileSystemNumber]!.longValue);
        var pathToWineLockFolder:String = "/tmp/.wine-\(uid)/server-\(deviceID)-\(inode)";
        if (NSFileManager.defaultManager().fileExistsAtPath(pathToWineLockFolder)) {
            NSFileManager.defaultManager().removeItemAtPath(pathToWineLockFolder, error: nil);
        }
        NSFileManager.defaultManager().createDirectoryAtPath(pathToWineLockFolder, withIntermediateDirectories: true, attributes: nil, error: nil);
        ObjC_Helpers.systemCommand("chmod -R 700 \"/tmp/.wine-\(uid)\"");
    }
    
    class func bundleWineBinaryNames() -> NSArray {
        var results:NSMutableArray = NSMutableArray()
        
        let wineBundleURL:NSURL = NSBundle.mainBundle().privateFrameworksURL!.URLByAppendingPathComponent("blwine.bundle");
        let engineBinFiles:NSArray = NSFileManager.defaultManager().contentsOfDirectoryAtURL(wineBundleURL.URLByAppendingPathComponent("bin"),
            includingPropertiesForKeys: [ NSURLNameKey ], options: NSDirectoryEnumerationOptions.allZeros, error: nil)!;
        for engineBinFileUnwr in engineBinFiles {
            let engineBinFile:NSURL = engineBinFileUnwr as NSURL;
            if (engineBinFile.path!.lastPathComponent.hasPrefix("Barrel")) {
                results.addObject(engineBinFile.path!.lastPathComponent);
            }
        }
        
        return results;
    }
    
    class func isWineserverRunning(wineserverProcess:String) -> Bool {
        let running:NSString = ObjC_Helpers.systemCommand("killall -0 \"\(wineserverProcess)\" 2>&1");
        return running.length < 1;
    }
    
    class func waitForWineserverToExitForMaximumTime(var seconds:Int) {
        // Find out our wine bin names
        let binaryNames:NSArray = BLWineMediator.bundleWineBinaryNames();
        var wineserverName:String = "";
        for binaryname in binaryNames {
            let binary:String = binaryname as String;
            if (NSString(string: binary).hasSuffix("Wineserver")) {
                wineserverName = binary;
            }
        }
        
        NSThread.sleepForTimeInterval(10);
        if (seconds == 0) {
            seconds = 31536000; // Wait for one year. Should be enough.
        }
        
        for (var i:Int = 0; i < seconds; i++) {
            var stillRunning:Bool = BLWineMediator.isWineserverRunning(wineserverName);
            if (!stillRunning) {
                NSLog("Wineserver exited.");
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
        
        ObjC_Helpers.systemCommand("killall -9 \"\(wineName)\" > /dev/null 2>&1");
        ObjC_Helpers.systemCommand("killall -9 \"\(wineserverName)\" > /dev/null 2>&1");
    }
    
    func didFinishCommand(notification:NSNotification) {
        NSLog("Finished CHModding");
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