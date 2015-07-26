//
//  BLOperation.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 23/09/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

let BLOperationWillStart:String         = "BLOperationWillStart";
let BLOperationDidFinish:String         = "BLOperationDidFinish";
let BLOperationInProgress:String        = "BLOperationInProgress";
let BLOperationWasCancelled:String      = "BLOperationWasCancelled";

let BLOperationContextInfoKey:String	= "BLOperationContextInfoKey";
let BLOperationSuccessKey:String		= "BLOperationSuccessKey";
let BLOperationErrorKey:String          = "BLOperationErrorKey";
let BLOperationProgressKey:String		= "BLOperationProgressKey";
let BLOperationIndeterminateKey:String	= "BLOperationIndeterminateKey";

typealias BLOperationProgress = Float;

class BLOperation: NSOperation {
    
    typealias ExecClosure = ((notification:NSNotification) -> ());
    
    var contextInfo:AnyObject?
    var notifiesOnMainThread:Bool!
    var isOperationCancelled:Bool = false;
    var delegate:BLOperationDelegate?
    var manuallyHandleFinish:Bool = false;
    
    // Selectors for the NotificationCenter
    var willStartSelector:String?
    var inProgressSelector:String?
    var wasCancelledSelector:String?
    var didFinishSelector:String?
    
    // Closures to invoke on completion
    var willStartClosure:ExecClosure?
    var didFinishClosure:ExecClosure?
    var inProgressClosure:ExecClosure?
    var wasCancelledClosure:ExecClosure?
    
    var currentProgress:BLOperationProgress?
    var isIndeterminate:Bool = true;
    var error:NSError?
    var succeeded:Bool {
        get {
            return self.error == nil;
        }
    }
    
    override init() {
        self.notifiesOnMainThread = true;
        self.willStartSelector = "operationWillStart:";
        self.inProgressSelector = "operationInProgress:";
        self.wasCancelledSelector = "operationWasCancelled:";
        self.didFinishSelector = "operationDidFinish:";
        self.currentProgress = 0.0;
        
        super.init();
    }
    
    override func start() {
        self.sendWillStartNotificationWithInfo(nil);
        super.start();
        if (manuallyHandleFinish == false) {
            self.sendDidFinishNotificationWithInfo(nil);
        }
    }
    
    func sendWillStartNotificationWithInfo(info:NSDictionary?) {
        if (self.isOperationCancelled) { return; }
        
        self.postNotificationWithName(BLOperationWillStart, delegateSelector: self.willStartSelector!, eClosure: self.willStartClosure, userInfo: info);
    }
    
    func sendWasCancelledNotificationWithInfo(info:NSDictionary?) {
        self.postNotificationWithName(BLOperationWasCancelled, delegateSelector: self.wasCancelledSelector!, eClosure: self.wasCancelledClosure, userInfo: info);
    }
    
    func sendDidFinishNotificationWithInfo(info:NSDictionary?) {
        var errValue = self.error;
        if (self.error == nil) {
            errValue = NSError();
        }
        
        var finishInfo:NSMutableDictionary = NSMutableDictionary(objectsAndKeys:
                                                                    self.succeeded, BLOperationSuccessKey,
                                                                    errValue!, BLOperationErrorKey);
        if let uInfo = info {
            finishInfo.addEntriesFromDictionary(uInfo as [NSObject : AnyObject]);
        }
        
        self.postNotificationWithName(BLOperationDidFinish, delegateSelector: self.didFinishSelector!, eClosure: self.didFinishClosure, userInfo: finishInfo);
    }
    
    func sendInProgressNotificationWithInfo(info:NSDictionary?) {
        if (self.isOperationCancelled) {
            return;
        }
        
        var progressInfo:NSMutableDictionary = NSMutableDictionary(objectsAndKeys:
                                                                    self.currentProgress!, BLOperationProgressKey,
                                                                    self.isIndeterminate, BLOperationIndeterminateKey);
        if let passedInfo = info {
            progressInfo.addEntriesFromDictionary(passedInfo as [NSObject : AnyObject]);
        }
        
        self.postNotificationWithName(BLOperationInProgress, delegateSelector: self.inProgressSelector!, eClosure: self.inProgressClosure, userInfo: info);
    }
    
    func postNotificationWithName(name:String, delegateSelector:String, eClosure:ExecClosure?, var userInfo:NSDictionary?) {
        
        if let cInfo:AnyObject = self.contextInfo {
            var contextDict:NSMutableDictionary = NSMutableDictionary(object: cInfo, forKey: BLOperationContextInfoKey);
            
            if let uInfo = userInfo {
                contextDict.addEntriesFromDictionary(uInfo as [NSObject : AnyObject]);
            }
            userInfo = contextDict;
        }
        
        var notificationCenter:NSNotificationCenter = NSNotificationCenter.defaultCenter();
        var notification = NSNotification(name: name, object: self, userInfo: userInfo as? [NSObject: AnyObject]);
        
        if let delegateClosure = eClosure {
            if (self.notifiesOnMainThread == true) {
                dispatch_async(dispatch_get_main_queue(), {
                    delegateClosure(notification:notification);
                });
            }
            else {
                delegateClosure(notification:notification);
            }
        }
        
        if (self.notifiesOnMainThread == true) {
            dispatch_async(dispatch_get_main_queue(), {
                notificationCenter.postNotification(notification);
            });
        }
        else {
            notificationCenter.postNotification(notification);
        }
    }
}
