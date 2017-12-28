//
//  ObjC-Helpers.h
//  BarrelApp
//
//  Created by Thanos Siopoudis on 12/09/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ObjC_Helpers : NSObject

+ (NSString *) BSDDeviceNameForVolumeAtURL: (NSURL *)volumeURL;
+ (void)systemCommand:(NSString *)command withObserver:(id)observer;
+ (NSString *)systemCommand:(NSString *)command;
+ (NSString *)systemCommand:(NSString *)command shouldWaitForProcess:(BOOL)waitForProcess redirectOutput:(BOOL)redirect logOutputToFilePath:(NSString *)logFilePath;

@end
