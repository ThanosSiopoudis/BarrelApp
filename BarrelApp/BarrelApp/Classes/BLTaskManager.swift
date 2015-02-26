//
//  BLTaskManager.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 24/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Foundation

class BLTaskManager:NSObject {
    var didReceiveStdoutDataSelector:String = "didReceiveStdoutData:";
    var didReceiveStderrDataSelector:String = "didReceiveStderrData:";
    var didFinishCommandSelector:String     = "didFinishCommang:";
    
    func startTaskWithCommand(command:String, arguments args:NSArray, observer:AnyObject) {
        var task:NSTask = NSTask();
        task.launchPath = command;
        task.arguments = args;
        
        // Is the command an .app bundle?
        if (command.pathExtension == "app") {
            let cBundle:NSBundle = NSBundle(path: command)!;
            task.launchPath = cBundle.executablePath!
        }
        
        let stdout:NSPipe = NSPipe();
        let stderr:NSPipe = NSPipe();
        
        task.standardOutput = stdout;
        task.standardError = stderr;
        
        var fhStdout:NSFileHandle = stdout.fileHandleForReading;
        fhStdout.waitForDataInBackgroundAndNotify();
        if (observer.respondsToSelector(Selector(didReceiveStdoutDataSelector))) {
            NSNotificationCenter.defaultCenter().addObserver(observer, selector: Selector(didReceiveStdoutDataSelector), name: NSFileHandleDataAvailableNotification, object: fhStdout);
        }
        if (observer.respondsToSelector(Selector(didFinishCommandSelector))) {
            NSNotificationCenter.defaultCenter().addObserver(observer, selector: Selector(didFinishCommandSelector), name: NSFileHandleReadToEndOfFileCompletionNotification, object: fhStdout);
        }
        
        var fhStdErr:NSFileHandle = stderr.fileHandleForReading;
        fhStdErr.waitForDataInBackgroundAndNotify();
        if (observer.respondsToSelector(Selector(didReceiveStderrDataSelector))) {
            NSNotificationCenter.defaultCenter().addObserver(observer, selector: Selector(didReceiveStderrDataSelector), name: NSFileHandleDataAvailableNotification, object: fhStdErr);
        }
        
        task.launch();
    }
    
    func runSystemCommand(command:String, waitForProcess shouldWait:Bool) {
        var fp:UnsafeMutablePointer<FILE>;
        var buff:Array<CChar> = Array(count: 512, repeatedValue: 0);
        fp = popen(NSString(string: command).cStringUsingEncoding(NSUTF8StringEncoding), "r");
        if (shouldWait) {
            while (fgets(&buff, CInt(512), fp).memory > 0) {
                NSLog("\(buff)");
            }
            
            pclose(fp);
        }
    }
}