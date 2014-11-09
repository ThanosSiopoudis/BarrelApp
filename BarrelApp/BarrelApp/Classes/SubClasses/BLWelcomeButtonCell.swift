//
//  BLWelcomeButton.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 23/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class BLWelcomeButtonCell: NSButtonCell {
    override func drawTitle(title: NSAttributedString, withFrame frame: NSRect, inView controlView: NSView) -> NSRect {
        var titleColor:NSColor = NSColor(calibratedRed: 254.0/255.0, green: 254.0/255.0, blue: 254.0/255.0, alpha: 1.0);
        var newtitle:NSMutableAttributedString = title.mutableCopy() as NSMutableAttributedString;
        newtitle.addAttribute(NSForegroundColorAttributeName, value: titleColor, range: NSMakeRange(0, newtitle.length));
        
        return super.drawTitle(newtitle, withFrame: frame, inView: controlView);
    }
}
