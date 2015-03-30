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

+ (NSString *)systemCommand:(NSString *)command {
    return [ObjC_Helpers systemCommand:command shouldWaitForProcess:YES redirectOutput:NO logOutputToFilePath:nil];
}

+ (NSString *)systemCommand:(NSString *)command shouldWaitForProcess:(BOOL)waitForProcess redirectOutput:(BOOL)redirect logOutputToFilePath:(NSString *)logFilePath
{
    FILE *fp;
    char buff[512];
    NSMutableString *returnString = [[NSMutableString alloc] init];
    fp = popen([command cStringUsingEncoding:NSUTF8StringEncoding], "r");
    if (waitForProcess) {
        while (fgets( buff, sizeof buff, fp))
        {
            [returnString appendString:[NSString stringWithCString:buff encoding:NSUTF8StringEncoding]];
            if (redirect) {
                // NSLog(@"%@", [NSString stringWithCString:buff encoding:NSUTF8StringEncoding]);
                printf("%s", buff);
            }
            else if ([logFilePath length] > 0) {
                NSFileHandle *aFileHandle;
                NSString *aFile;
                
                aFile = [NSString stringWithString:logFilePath];
                aFileHandle = [NSFileHandle fileHandleForWritingAtPath:aFile];
                [aFileHandle truncateFileAtOffset:[aFileHandle seekToEndOfFile]];
                [aFileHandle writeData: [[NSString stringWithCString:buff encoding:NSUTF8StringEncoding] dataUsingEncoding:NSUTF8StringEncoding]];
            }
        }
        pclose(fp);
        returnString = [NSMutableString stringWithString:[returnString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }
    return [NSString stringWithString:returnString];
}

@end
