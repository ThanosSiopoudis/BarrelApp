//
//  Engine.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 13/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Foundation

class Engine:NSObject {
    var EngineID:UInt = 0
    var Created:NSDate = NSDate()
    var Name:String = ""
    var Path:String = ""
    var isRemote:Bool = true
}