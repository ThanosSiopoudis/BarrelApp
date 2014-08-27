//
//  BLValueTransformers.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 26/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class BLDisplayPathTransformer : NSValueTransformer {
    var joiner:String?
    var ellipsis:String?
    var maxComponents:NSInteger?
    var usesFileSystemDisplayPath:Bool?
    
    override class func transformedValueClass() -> AnyClass! {
        return NSString.self;
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return false;
    }
    
    override init() {
        super.init();
    }
    
    init(joiner:String, ellipsis:String, maxComponents:NSInteger) {
        self.joiner = joiner;
        self.ellipsis = countElements(ellipsis) > 0 ? ellipsis : self.ellipsis;
        self.maxComponents = maxComponents;
        self.usesFileSystemDisplayPath = true;
    }
    
    convenience init(joiner:String, maxComponents:NSInteger) {
        self.init(joiner: joiner, ellipsis: "", maxComponents: maxComponents);
    }
    
    func _componentsForPath(path:String) -> NSArray {
        var components:NSArray? = nil;
        if (self.usesFileSystemDisplayPath!) {
            components = NSFileManager.defaultManager().componentsToDisplayForPath(path);
        }
        
        // If NSFileManager couldn't derive display names for this path
        // or we disabled filesystem display paths, just use ordinary path components
        if (components == nil) {
            var tempArray:NSArray = path.pathComponents;
            components = tempArray.filteredArrayUsingPredicate(NSPredicate(format: "SELF != '/'"));
        }
        
        return components!;
    }
    
    override func transformedValue(value: AnyObject!) -> AnyObject! {
        if (value == nil) {
            return nil;
        }
        
        var components:NSMutableArray = self._componentsForPath(value as String).mutableCopy() as NSMutableArray;
        var count:NSInteger = components.count;
        var shortened:Bool = false;
        
        if (self.maxComponents! > 0 && count > self.maxComponents!) {
            components.removeObjectsInRange(NSMakeRange(0, count - self.maxComponents!));
            shortened = true;
        }
        
        var displayPath:String = components.componentsJoinedByString(self.joiner!);
        if (shortened && self.ellipsis != nil) {
            displayPath = self.ellipsis!.stringByAppendingString(displayPath);
        }
        
        return NSAttributedString(string: displayPath);
    }
}

class BLIconifiedDisplayPathTransformer : BLDisplayPathTransformer {
    var missingFileIcon:NSImage?
    var textAttributes:NSMutableDictionary?
    var iconAttributes:NSMutableDictionary?
    var iconSize:NSSize?
    var hidesSystemRoots:Bool?
    
    override class func transformedValueClass() -> AnyClass! {
        return NSAttributedString.self;
    }
    
    override init(joiner: String, ellipsis: String, maxComponents: NSInteger) {
        self.iconSize = NSMakeSize(16, 16);
        self.textAttributes = NSMutableDictionary(objectsAndKeys: NSFont.systemFontOfSize(0), NSFontAttributeName);
        self.iconAttributes = NSMutableDictionary(objectsAndKeys: NSNumber.numberWithFloat(-3.0), NSBaselineOffsetAttributeName);
        
        super.init(joiner: joiner, ellipsis: ellipsis, maxComponents: maxComponents);
    }
    
    func componentForPath(path:String, defaultIcon:NSImage?) -> NSAttributedString {
        var displayName:String;
        var icon:NSImage;
        
        var manager:NSFileManager = NSFileManager.defaultManager();
        var workspace:NSWorkspace = NSWorkspace.sharedWorkspace();
        
        // Determine the display name and file icon, falling back on sensible defaults if the path doesn't yet exist
        if (manager.fileExistsAtPath(path)) {
            displayName = manager.displayNameAtPath(path);
            icon = workspace.iconForFile(path);
        }
        else {
            displayName = path.lastPathComponent;
            icon = defaultIcon != nil ? defaultIcon : workspace.iconForFile(path);
        }
        
        var iconAttachment:NSTextAttachment = NSTextAttachment();
        var iconCell:NSTextAttachmentCell = iconAttachment.attachmentCell as NSTextAttachmentCell;
        iconCell.image = icon;
        iconCell.image.size = self.iconSize!;
        
        var component:NSMutableAttributedString = NSAttributedString(attachment: iconAttachment).mutableCopy() as NSMutableAttributedString;
        component.addAttributes(self.iconAttributes!, range: NSMakeRange(0, component.length));
        
        var label:NSAttributedString = NSAttributedString(string: " \(displayName)", attributes: self.textAttributes!);
        component.appendAttributedString(label);
        
        return component;
    }
    
    override func transformedValue(value: AnyObject!) -> AnyObject! {
        if (value == nil) {
            return nil;
        }
        
        var path:String = value as String;
        
        var components:NSMutableArray = path.fullPathComponents().mutableCopy() as NSMutableArray;
        if (components.count < 1) {
            return NSAttributedString();
        }
        
        if (self.hidesSystemRoots!) {
            components.removeObject("/");
            components.removeObject("/Users");
            components.removeObject("/Volumes");
        }
        
        var displayPath:NSMutableAttributedString = NSMutableAttributedString();
        var attributesJoiner:NSAttributedString = NSAttributedString(string: self.joiner!, attributes: self.textAttributes!);
        // Truncate the path with ellipses if there are too many components
        var count:NSInteger = components.count;
        if (self.maxComponents! > 0 && count > self.maxComponents!) {
            components.removeObjectsInRange(NSMakeRange(0, count - self.maxComponents!));
            var attributedEllipsis:NSAttributedString = NSAttributedString(string: self.ellipsis!, attributes: self.textAttributes!);
            displayPath.appendAttributedString(attributedEllipsis);
        }
        
        var folderIcon:NSImage = NSImage(named: "NSFolder");
        var i:NSInteger = components.count;
        var numComponents:NSInteger = i;
        for (i = 0; i < numComponents; i++) {
            var subPath:String = components.objectAtIndex(i) as String;
            
            // Use regular folder icon for all missing path components except for the final one
            var defaultIcon:NSImage = (i == numComponents - 1) ? self.missingFileIcon! : folderIcon;
            var componentString:NSAttributedString = self.componentForPath(subPath, defaultIcon: defaultIcon);
            
            if (i > 0) {
                displayPath.appendAttributedString(attributesJoiner);
            }
            displayPath.appendAttributedString(componentString);
        }
        
        return displayPath;
    }
}