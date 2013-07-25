/*
 Copyright (c) 2013, Barrel Team
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of the Barrel Team nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY Barrel Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL Barrel Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "BLSystemCommand.h"

@implementation BLSystemCommand

+ (NSString *)systemCommand:(NSString *)command shouldWaitForProcess:(BOOL)waitForProcess
{
	FILE *fp;
	char buff[512];
	NSMutableString *returnString = [[NSMutableString alloc] init];
	fp = popen([command cStringUsingEncoding:NSUTF8StringEncoding], "r");
    if (waitForProcess) {
        while (fgets( buff, sizeof buff, fp))
        {
            [returnString appendString:[NSString stringWithCString:buff encoding:NSUTF8StringEncoding]];
        }
        pclose(fp);
        returnString = [NSMutableString stringWithString:[returnString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }
	return [NSString stringWithString:returnString];
}

+ (void)waitForWineserverToExitWithBinaryName:(NSString *)binaryName andCallback:(void (^)(BOOL))callbackBlock {
    [self waitForWineserverToExitWithBinaryName:binaryName andCallback:callbackBlock waitFor:10];
}

+ (void)waitForWineserverToExitWithBinaryName:(NSString *)binaryName andCallback:(void (^)(BOOL))callbackBlock waitFor:(NSInteger)waitTime {
    [NSThread sleepForTimeInterval:waitTime];
    for (;;) {
        BOOL stillRunning = NO;
        NSArray *resultArray = [[self systemCommand:[NSString stringWithFormat:@"ps -eo pcpu,pid,args | grep \"%@\"", binaryName] shouldWaitForProcess:YES] componentsSeparatedByString:@" "];
        NSMutableArray *cleanArray = [[NSMutableArray alloc] init];
        // Go through the resultArray and clear out any empty items
        for (NSString *item in resultArray) {
            if ([item length] > 0) {
                [cleanArray addObject:item];
            }
        }
        
        if ([cleanArray count] > 0 && ![(NSString *)[cleanArray objectAtIndex:12] isEqualToString:@"grep"]) {
            // FIXME: Optimise this check
            stillRunning = YES;
        }
        if (!stillRunning) {
            NSLog(@"Wineserver not running");
            callbackBlock(YES);
            return;
        }
        [NSThread sleepForTimeInterval:1.0f];
    }
}

+ (void)runScript:(NSString*)scriptName withArguments:(NSArray *)arguments shouldWaitForProcess:(BOOL)waitForProcess
{
    NSTask *task;
    task = [[NSTask alloc] init];
    
    NSBundle *barrelAppBundle = [NSBundle bundleWithPath:scriptName];
    NSArray *argumentsArray;
    [task setLaunchPath: [barrelAppBundle executablePath]];
    
    if (arguments) {
        argumentsArray = arguments;
        [task setArguments: argumentsArray];
    }
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [[NSApplication sharedApplication] deactivate]; // Send Barrel to the back
    [task launch];
    
    if (waitForProcess) {
        NSData *data;
        data = [file readDataToEndOfFile];
        
        NSString *string;
        string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    }
}

@end
