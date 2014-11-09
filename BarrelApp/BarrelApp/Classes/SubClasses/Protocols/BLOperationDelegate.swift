//
//  BLOperationDelegate.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 24/09/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

@objc protocol BLOperationDelegate : NSObjectProtocol {
    optional func operationWillStart(notification:NSNotification)
    optional func operationInProgress(notification:NSNotification);
    optional func operationWasCancelled(notification:NSNotification)
    optional func operationDidFinish(notification:NSNotification);
}

class BLOperationDelegateClass : NSObject, BLOperationDelegate {
    var none:NSNumber? = nil;
}