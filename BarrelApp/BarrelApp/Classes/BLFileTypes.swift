//
//  BLFileTypes.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 03/09/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

let BLBarrelFilesystemFolderType = "uk.co.appcake.barrel-harddisk-folder";
let BLBarrelEXEProgramType = "com.microsoft.windows-executable";
let BLBarrelCOMProgramType = "com.microsoft.msdos-executable";
let BLBarrelBATProgramType = "com.microsoft.batch-file";

let BLCuesheetImageType    = "com.goldenhawk.cdrwin-cuesheet";
let BLISOImageType         = "public.iso-image";
let BLCDRImageType         = "com.apple.disk-image-cdr";
let BLVirtualPCImageType   = "com.microsoft.virtualpc-disk-image";
let BLRawFloppyImageType   = "com.winimage.raw-disk-image";
let BLNDIFImageType        = "com.apple.disk-image-ndif";

enum BLExecutableType:Int {
    case BLExecutableTypeUnknown = 0
    case BLExecutableTypeDOS = 1
    case BLExecutableTypeWindows = 2
    case BLExecutableTypeOS2 = 3
};

class BLFileTypes:NSObject {
    class func filesystemVolumeType() -> NSSet? {
        var types:NSSet? = nil;
        var onceToken:dispatch_once_t = 0;
        dispatch_once(&onceToken, {
            types = NSSet(objects: BLBarrelFilesystemFolderType);
        });
        
        return types;
    }
    
    class func macOSAppTypes() -> NSSet? {
        var types:NSSet? = nil;
        var onceToken:dispatch_once_t = 0;
        dispatch_once(&onceToken, {
            types = NSSet(objects: kUTTypeApplicationFile as String, kUTTypeApplicationBundle as String);
        });
        
        return types;
    }
    
    class func executableTypes() -> NSSet? {
        var types:NSSet? = nil;
        var onceToken:dispatch_once_t = 0;
        dispatch_once(&onceToken, {
            types = NSSet(objects: BLBarrelEXEProgramType, BLBarrelCOMProgramType, BLBarrelBATProgramType);
        });
        
        return types;
    }
    
    class func mountableVolumeTypes() -> NSSet? {
        var types:NSSet? = nil;
        var onceToken:dispatch_once_t = 0;
        dispatch_once(&onceToken, {
            types = NSSet(objects: BLCuesheetImageType, BLCDRImageType, BLISOImageType, BLRawFloppyImageType, BLVirtualPCImageType, BLNDIFImageType);
        });
        
        return types;
    }
    
    class func OSXMountableVolumeTypes() -> NSSet? {
        var types:NSSet? = nil;
        var onceToken:dispatch_once_t = 0;
        dispatch_once(&onceToken, {
            types = NSSet(objects: BLISOImageType, BLCDRImageType, BLRawFloppyImageType, BLVirtualPCImageType, BLNDIFImageType);
        });
        
        return types;
    }
    
    class func typeOfExecutableAtURL(URL:NSURL?) -> BLExecutableType {
        assert(URL != nil, "No URL specified!");
        
        // Contrast to Boxer, we don't need to distinguish between DOS and Windows Executables. We can run either! (how successfully is a different story)
        if let pathURL = URL {
            var pathExtension = pathURL.pathExtension!.lowercaseString
 
            if (pathExtension == "exe" || pathExtension == "com" || pathExtension == "bat" || pathExtension == "msi") {
                return BLExecutableType.BLExecutableTypeWindows
            }
        }
        
        
        return BLExecutableType.BLExecutableTypeUnknown;
    }
    
    class func typeOfExecutableAtPath(path:String?) -> BLExecutableType {
        assert(path != nil, "No Path specified!");
        
        // Contrast to Boxer, we don't need to distinguish between DOS and Windows Executables. We can run either! (how successfully is a different story)
        if let unwrPath = path {
            var pathExtension = unwrPath.pathExtension.lowercaseString
            
            if (pathExtension == "exe" || pathExtension == "msi") {
                return BLExecutableType.BLExecutableTypeWindows;
            }
            else if (pathExtension == "com" || pathExtension == "bat") {
                return BLExecutableType.BLExecutableTypeDOS;
            }
        }
        
        
        return BLExecutableType.BLExecutableTypeUnknown;
    }
    
    class func isCompatibleExecutable(URL:NSURL?) -> Bool {
        if (BLFileTypes.typeOfExecutableAtURL(URL) == BLExecutableType.BLExecutableTypeWindows ||
            BLFileTypes.typeOfExecutableAtURL(URL) == BLExecutableType.BLExecutableTypeDOS) {
            return true;
        }
        
        return false;
    }
}
