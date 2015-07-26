//
//  BarrelAPI.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 13/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Foundation

class BarrelAPI:NSObject {
    
    class func listOfAllEngines(toBlock completionBlock:((RKObjectRequestOperation!, RKMappingResult!) -> Void)!, failBlock errorBlock:((RKObjectRequestOperation!, NSError!) -> Void)!) {
        var engineMapping:RKObjectMapping = RKObjectMapping(forClass: Engine.self);
        engineMapping.addAttributeMappingsFromDictionary([
            "_id"       : "EngineID",
            "created"   : "Created",
            "name"      : "Name",
            "path"      : "Path"
        ]);
        
        var responseDescriptor:RKResponseDescriptor = RKResponseDescriptor(mapping: engineMapping,
            method: RKRequestMethod.Any, pathPattern: nil, keyPath: nil, statusCodes: RKStatusCodeIndexSetForClass(RKStatusCodeClass.Successful))
        
        let url:NSURL = NSURL(string: "http://localhost:3000/engines")!;
        let urlRequest:NSURLRequest = NSURLRequest(URL: url);
        var objectRequestOperation:RKObjectRequestOperation = RKObjectRequestOperation(request: urlRequest, responseDescriptors: [responseDescriptor]);
        objectRequestOperation.setCompletionBlockWithSuccess(completionBlock, failure: errorBlock);
        
        objectRequestOperation.start();
    }
}
