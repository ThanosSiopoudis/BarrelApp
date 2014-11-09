//
//  ObjC-Helpers.m
//  BarrelApp
//
//  Created by Thanos Siopoudis on 12/09/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

#import <sys/mount.h>
#import "ObjC-Helpers.h"

@implementation ObjC_Helpers

+ (NSString *) BSDDeviceNameForVolumeAtURL: (NSURL *)volumeURL
{
    NSString *deviceName = nil;
    struct statfs fs;
    
    if (statfs(volumeURL.fileSystemRepresentation, &fs) == ERR_SUCCESS)
    {
        NSFileManager *manager = [NSFileManager defaultManager];
        deviceName = [manager stringWithFileSystemRepresentation: fs.f_mntfromname
                                                          length: strlen(fs.f_mntfromname)];
    }
    return deviceName;
}

@end
