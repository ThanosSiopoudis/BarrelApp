//
//  BLFileHandle.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 04/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Cocoa

struct BLHandleOptions:RawOptionSetType {
    typealias RawValue = UInt
    private var value:UInt = 0
    init(_ value:UInt) { self.value = value }
    init(rawValue value:UInt) { self.value = value }
    init(nilLiteral: ()) { self.value = 0 }
    static var allZeros:BLHandleOptions { return self(0) }
    static func fromMask(raw:UInt) -> BLHandleOptions { return self(raw) }
    var rawValue:UInt { return self.value }
    
    static var None:BLHandleOptions { return self(0) }
    static var BLOpenForReading:BLHandleOptions { return BLHandleOptions(1 << 0) }
    static var BLOpenForWriting:BLHandleOptions { return BLHandleOptions(1 << 1) }
    
    // Mutually exclusive
    static var BLCreateIfMissing:BLHandleOptions { return BLHandleOptions(1 << 2) }
    static var BLCreateAlways:BLHandleOptions { return BLHandleOptions(1 << 3) }
    
    // Mutually exclusive
    static var BLTruncate:BLHandleOptions { return BLHandleOptions(1 << 4) }
    static var BLAppend:BLHandleOptions { return BLHandleOptions(1 << 5) }
    
    // Equivalents to fopen() access modes
    static var BLPOSIXModeR:BLHandleOptions { return BLHandleOptions.BLOpenForReading }
    static var BLPOSIXModeRPlus:BLHandleOptions { return (BLHandleOptions.BLPOSIXModeR | BLHandleOptions.BLOpenForWriting) }
    
    static var BLPOSIXModeW:BLHandleOptions { return (BLHandleOptions.BLOpenForWriting | BLHandleOptions.BLTruncate | BLHandleOptions.BLCreateIfMissing) }
    static var BLPOSIXModeWPlus:BLHandleOptions { return (BLHandleOptions.BLPOSIXModeW | BLHandleOptions.BLOpenForReading) }
    
    static var BLPOSIXModeA:BLHandleOptions { return (BLHandleOptions.BLOpenForWriting | BLHandleOptions.BLAppend | BLHandleOptions.BLCreateIfMissing) }
    static var BLPOSIXModeAPlus:BLHandleOptions { return (BLHandleOptions.BLPOSIXModeA | BLHandleOptions.BLOpenForReading) }
    
    static var BLPOSIXModeWX:BLHandleOptions { return (BLHandleOptions.BLOpenForWriting | BLHandleOptions.BLTruncate | BLHandleOptions.BLCreateAlways) }
    static var BLPOSIXModeWPlusX:BLHandleOptions { return (BLHandleOptions.BLPOSIXModeWX | BLHandleOptions.BLOpenForReading) }
    
    static var BLPOSIXModeAX:BLHandleOptions { return (BLHandleOptions.BLOpenForWriting | BLHandleOptions.BLAppend | BLHandleOptions.BLCreateAlways) }
    static var BLPOSIXModeAPlusX:BLHandleOptions { return (BLHandleOptions.BLPOSIXModeAX | BLHandleOptions.BLOpenForReading) }
}

class BLFileHandle:NSObject {
    
    var handle:UnsafeMutablePointer<FILE>?
    var closeOnDealloc:Bool?
    
    required override init() {
        super.init();
    }
    
    convenience init(handleForURL URL:NSURL?, options:BLHandleOptions, error outError:NSErrorPointer) {
        self.init(URL: URL, options: options, error: outError);
    }
    
    init(handle:UnsafeMutablePointer<FILE>, closeOnDealloc:Bool) {
        self.handle = handle;
        self.closeOnDealloc = closeOnDealloc;
    }
    
    convenience init(URL:NSURL?, options:BLHandleOptions, error outError:NSErrorPointer) {
        var mode:String? = BLFileHandle.self.POSIXAccessModeForOptions(options);
        self.init(URL: URL, mode: &mode!, error: outError);
    }
    
    convenience init(URL:NSURL?, inout mode:String, error outError:NSErrorPointer) {
        assert(URL != nil, "A URL must be provided");
        
        if let fileURL = URL {
            if let path = fileURL.path {
                var ObjCPath:NSString = path as NSString;
                var ObjCMode:NSString = mode as NSString;
                var handle:UnsafeMutablePointer<FILE> = fopen(ObjCPath.UTF8String, ObjCMode.UTF8String);
                
                if (handle != nil) {
                    self.init(handle: handle, closeOnDealloc: true);
                    return
                }
                else {
                    if (outError != nil) {
                        let iErrNo:Int = Int(errno);
                        outError.memory = NSError(domain: NSPOSIXErrorDomain, code: iErrNo, userInfo: [NSURLErrorKey: fileURL]);
                    }
                }
            }
        }
        
        self.init();
    }
    
    class func POSIXAccessModeForOptions(options:BLHandleOptions) -> String? {
        // Complain about required and mutually exclusive options
        assert(((options.rawValue & (BLHandleOptions.BLOpenForReading.rawValue | BLHandleOptions.BLOpenForWriting.rawValue)) > 0),
            "At least one of BLOpenForReading and BLOpenForWriting must be specified");
        
        assert((options.rawValue & BLHandleOptions.BLTruncate.rawValue) == 0 || (options.rawValue & BLHandleOptions.BLAppend.rawValue) == 0,
            "BLTruncate and BLAppend cannot be specified together");
        
        assert((options.rawValue & BLHandleOptions.BLCreateIfMissing.rawValue) == 0 || (options.rawValue & BLHandleOptions.BLCreateAlways.rawValue) == 0,
            "BLCreateIfMissing and BLCreateAlways cannot be specified together");
        
        //Known POSIX access modes arranged in descending order of specificity.
        //This lets us do a best fit for options that may not exactly match one of our known modes.
        let optionMasks:[BLHandleOptions] = [
            BLHandleOptions.BLPOSIXModeAPlusX,
            BLHandleOptions.BLPOSIXModeAX,
            BLHandleOptions.BLPOSIXModeAPlus,
            BLHandleOptions.BLPOSIXModeA,
            BLHandleOptions.BLPOSIXModeWPlusX,
            BLHandleOptions.BLPOSIXModeWX,
            BLHandleOptions.BLPOSIXModeWPlus,
            BLHandleOptions.BLPOSIXModeRPlus,
            BLHandleOptions.BLPOSIXModeW,
            BLHandleOptions.BLPOSIXModeR
        ];
        
        let modes:[String] = [
            "a+x",
            "ax",
            "a+",
            "a",
            "w+x",
            "wx",
            "w+",
            "r+",
            "w",
            "r"
        ];
        
        var i:Int, numModes:Int = 10;
        for (i = 0; i < numModes; i++) {
            var mask:BLHandleOptions = optionMasks[i];
            if ((options.rawValue & mask.rawValue) == mask.rawValue) {
                return modes[i];
            }
        }
        
        // If we got this far, no mode would fit: a programming error if we ever saw one
        assert(false, "No POSIX access mode is suitable for the specified options.");
        
        return nil;
    }
}
