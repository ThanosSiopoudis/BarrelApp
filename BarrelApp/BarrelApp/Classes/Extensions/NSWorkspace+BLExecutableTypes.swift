//
//  NSWorkspace+BLExecutableTypes.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 04/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Cocoa

extension NSWorkspace {
    func executableTypeAtPath(path:String?) -> BLExecutableType {
        return BLFileTypes.typeOfExecutableAtPath(path);
    }
    
    func isCompatibleExecutableAtPath(path:String?) -> Bool {
        if let filePath = path {
            return BLFileTypes.isCompatibleExecutable(NSURL(fileURLWithPath: filePath));
        }
        
        return false;
    }
}
