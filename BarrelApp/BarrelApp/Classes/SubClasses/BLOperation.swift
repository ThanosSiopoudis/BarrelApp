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

class BLOperation: NSOperation {
    
    var contextInfo:AnyObject?
    var notifiesOnMainThread:Bool!
    var isCancelled:Bool = false;
    var delegate:BLOperationDelegate?
    var willStartSelector:String?
    var inProgressSelector:String?
    var wasCancelledSelector:String?
    var didFinishSelector:String?
    
    override init() {
        self.notifiesOnMainThread = true;
        self.willStartSelector = "operationWillStart:";
        self.inProgressSelector = "operationInProgress:";
        self.wasCancelledSelector = "operationWasCancelled:";
        self.didFinishSelector = "operationDidFinish:";
        
        super.init();
    }
    
    func sendWillStartNotificationWithInfo(info:NSDictionary) {
        if (self.isCancelled) { return; }
        
        self.postNotificationWithName(BLOperationWillStart, delegateSelector: self.willStartSelector!, userInfo: info);
    }
    
    func sendWasCancelledNotificationWithInfo(info:NSDictionary) {
        self.postNotificationWithName(BLOperationWasCancelled, delegateSelector: self.wasCancelledSelector!, userInfo: info);
    }
    
    func sendDidFinishNotificationWithInfo(info:NSDictionary) {
        // let finishInfo:NSMutableDictionary = NSMutableDictionary(objectsAndKeys:
    }
    
    func postNotificationWithName(name:String, delegateSelector:String, var userInfo:NSDictionary?) {
        
        if let cInfo:AnyObject = self.contextInfo {
            var contextDict:NSMutableDictionary = NSMutableDictionary(object: cInfo, forKey: BLOperationContextInfoKey);
            
            if let uInfo = userInfo {
                contextDict.addEntriesFromDictionary(uInfo);
                userInfo = contextDict;
            }
            
            var notificationCenter:NSNotificationCenter = NSNotificationCenter.defaultCenter();
            var notification = NSNotification(name: name, object: self, userInfo: userInfo!);
            
            if (self.delegate!.respondsToSelector(Selector(delegateSelector))) {
                if (self.notifiesOnMainThread == true) {
                    dispatch_async(dispatch_get_main_queue(), {
                        // We should be probably using closures here but this will do for now
                        let timer = NSTimer.scheduledTimerWithTimeInterval(0.01,
                            target: self.delegate!, selector: Selector(delegateSelector), userInfo: notification, repeats: false);
                    });
                }
                else {
                    // We should be probably using closures here but this will do for now
                    let timer = NSTimer.scheduledTimerWithTimeInterval(0.01,
                        target: self.delegate!, selector: Selector(delegateSelector), userInfo: notification, repeats: false);
                }
            }
            
            if (self.notifiesOnMainThread == true) {
                dispatch_async(dispatch_get_main_queue(), {
                    let timer = NSTimer.scheduledTimerWithTimeInterval(0.01,
                        target: notificationCenter, selector: Selector("postNotification:"), userInfo: notification, repeats: false);
                });
            }
            else {
                let timer = NSTimer.scheduledTimerWithTimeInterval(0.01,
                    target: notificationCenter, selector: Selector("postNotification:"), userInfo: notification, repeats: false);
            }
        }
    }
}
