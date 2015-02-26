//
//  BLFinalizingViewController.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 17/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Cocoa

class BLFinalizingViewController: NSViewController {
    @IBOutlet weak var titleText:NSTextField?
    @IBOutlet var controller:BLImportWindowController?
    
    override func awakeFromNib() {
        var title:String = self.titleText!.stringValue;
        
        var textColour:NSColor = NSColor.whiteColor();
        var theFont:NSFont = NSFont(name: "Avenir Next", size: 32.0)!
        var textParagraph:NSMutableParagraphStyle = NSMutableParagraphStyle();
        textParagraph.lineSpacing = 6.0;
        textParagraph.maximumLineHeight = 38.0;
        textParagraph.alignment = NSTextAlignment.CenterTextAlignment;
        
        var attrDict:NSDictionary = NSDictionary(objectsAndKeys: theFont, NSFontAttributeName, textColour, NSForegroundColorAttributeName, textParagraph, NSParagraphStyleAttributeName);
        var attrString:NSAttributedString = NSAttributedString(string: title, attributes: attrDict);
        self.titleText!.attributedStringValue = attrString;
    }
}
