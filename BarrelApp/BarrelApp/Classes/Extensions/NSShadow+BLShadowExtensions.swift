//
//  NSShadow+BLShadowExtensions.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 09/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Cocoa

extension NSShadow {
    convenience init(blurRadius:CGFloat, offset:NSSize, color:NSColor?) {
        self.init();
        
        self.shadowBlurRadius = blurRadius;
        self.shadowOffset = offset;
        self.shadowColor = color;
    }
}
