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
    var delegate:BLOperationDelegateClass?
    
    override init() {
        self.notifiesOnMainThread = true;
        
        super.init();
    }
    
    func sendWillStartNotificationWithInfo(info:NSDictionary) {
        if (self.isCancelled) { return; }
        
        
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

            }
        }
    }
}
