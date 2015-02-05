//
//  NSWorkspace+BLExecutableTypes.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 04/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Cocoa

extension NSWorkspace {
    func executableTypeAtPath(path:String, error outError:NSErrorPointer) -> BLExecutableType {
        return BLExecutableType.BLExecutableTypeDOS;
    }
}
