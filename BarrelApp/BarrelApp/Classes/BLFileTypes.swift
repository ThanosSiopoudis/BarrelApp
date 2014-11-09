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

class BLFileTypes:NSObject {
    class func filesystemVolumeType() -> NSSet? {
        var types:NSSet? = nil;
        var onceToken:dispatch_once_t = 0;
        dispatch_once(&onceToken, {
            types = NSSet(objects: BLBarrelFilesystemFolderType);
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
}
