//
//  NSArray+NSArrayExtensions.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 25/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

extension Array {
    var lastObject: T {
        return self[endIndex - 1];
    }
}
