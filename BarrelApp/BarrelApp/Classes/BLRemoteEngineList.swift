//
//  BLRemoteEngineList.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 14/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Cocoa

class BLRemoteEngineList: BLOperation {
    
    var engineList:NSArray?
    
    override func main() {
        self.manuallyHandleFinish = true;
        
        BarrelAPI.listOfAllEngines(toBlock: {(operation:RKObjectRequestOperation!, mappingResult:RKMappingResult!) in
            if (mappingResult.count > 0) {
                self.engineList = mappingResult.array();
                self.sendDidFinishNotificationWithInfo(nil);
            }
        }, failBlock: {(operation:RKObjectRequestOperation!, error:NSError!) in
            self.error = error;
            self.sendDidFinishNotificationWithInfo(nil);
        });
    }
}