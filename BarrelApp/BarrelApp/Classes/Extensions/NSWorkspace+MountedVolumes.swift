//
//  NSWorkspace+MountedVolumes.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 04/09/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

let BLDataCDVolumeType = "cd9660";
let BLAudioCDVolumeType = "cddafs";
let BLFatVolumeType = "msdos";
let BLHFSColumeType = "hfs";

extension NSWorkspace {
    func fileMatchesTypes(filePath:String, acceptedTypes:NSSet) -> Bool {
        var fileType:String? = self.typeOfFile(filePath, error: nil);
        if let ft = fileType {
            for acceptedType in acceptedTypes {
                if (self.type(ft, conformsToType: acceptedType as String) == true) {
                    return true;
                }
            }
        }
        
        var fileExtension:String = filePath.pathExtension;
        if (countElements(fileExtension) > 0) {
            for acceptedType in acceptedTypes {
                if (self.filenameExtension(fileExtension, isValidForType: acceptedType as String)) {
                    return true;
                }
            }
        }
        
        return false;
    }
    
    func typeOfVolumeAtURL(URL:NSURL?) -> NSString? {
        assert(URL != nil, "No URL provided");
        
        var volumeType:NSString? = nil;
        var retrieved:Bool = false;
        
        if let theurl = URL {
            retrieved = self.getFileSystemInfoForPath(theurl.path!, isRemovable: nil, isWritable: nil, isUnmountable: nil, description: nil, type: &volumeType);
        }
        
        return (retrieved) ? volumeType : nil;
    }
    
    func mountedVolumeURLsIncludingHidden(hidden:Bool) -> NSArray {
        var options:NSVolumeEnumerationOptions = (hidden == true) ? NSVolumeEnumerationOptions.allZeros : NSVolumeEnumerationOptions.SkipHiddenVolumes;
        return NSFileManager.defaultManager().mountedVolumeURLsIncludingResourceValuesForKeys(nil, options: options)!;
    }
    
    func mountedVolumeURLSOfType(requiredType:String?, hidden:Bool) -> NSArray {
        assert(requiredType != nil, "A Volume type must be specified");
        
        var volumeURLs:NSArray = self.mountedVolumeURLsIncludingHidden(hidden);
        var matches:NSMutableArray = NSMutableArray(capacity: 5);
        for volumeURL in volumeURLs {
            var volumeType:String = self.typeOfVolumeAtURL(volumeURL as? NSURL)!;
            if (volumeType == requiredType!) {
                matches.addObject(volumeURL);
            }
        }
        
        return matches;
    }
    
    func dataVolumeOfAudioCDAtURL(audioCDURL:NSURL) -> NSURL? {
        var audioDeviceName:String = ObjC_Helpers.BSDDeviceNameForVolumeAtURL(audioCDURL);
        var dataVolumes:NSArray = self.mountedVolumeURLSOfType(BLDataCDVolumeType, hidden: true);
        
        for dataVolumeURL in dataVolumes {
            var dataDeviceName:String = ObjC_Helpers.BSDDeviceNameForVolumeAtURL(dataVolumeURL as NSURL);
            if (dataDeviceName.hasPrefix(audioDeviceName)) {
                return dataVolumeURL as? NSURL;
            }
        }
        
        return nil;
    }
}
