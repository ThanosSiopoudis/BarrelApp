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

#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import "BarrelWineLauncher.h"

@implementation BarrelWineLauncher

-(id) initWithArguments:(NSMutableArray *)arguments {
    
    //[NSThread sleepForTimeInterval:10.0f]; // Wait for debugger
    
    if (self = [super init]) {
        [self setArguments:arguments];
        [self setExecutablePath:[[NSBundle mainBundle] executablePath]];
        [self setFrameworksPath:[NSString stringWithFormat:@"%@/Contents/Frameworks", [[NSBundle mainBundle] bundlePath]]];
        [self setWineBundlePath:[NSString stringWithFormat:@"%@/blwine.bundle", [self frameworksPath]]];
        [self setWinePrefixPath:[[NSBundle mainBundle] resourcePath]];
        
        dispatchQueue = dispatch_queue_create("com.appcake.blwinelauncher", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_t priority = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
        dispatch_set_target_queue(dispatchQueue, priority);
    }
    
    return self;
}

-(void) runWine {
    if ([(NSString *)[[self arguments] objectAtIndex:1]isEqualToString:@"initPrefix"]) {
        [self initWinePrefix];
    }
    else {
        [self runWineWithWindowsBinary:(NSString *)[[self arguments] objectAtIndex:1]];
    }
}

-(void) runWineWithWindowsBinary:(NSString *)binaryPath {
    NSString *script = [NSString stringWithFormat:@"export PATH=\"%@/bin:%@/bin:$PATH:/opt/local/bin:/opt/local/sbin\";export WINEPREFIX=\"%@\";DYLD_FALLBACK_LIBRARY_PATH=\"%@\" wine %@ > \"/dev/null\" 2>&1", [self wineBundlePath], [self frameworksPath], [self winePrefixPath], [self frameworksPath], binaryPath];
    [self setScriptPath:@""];
    [self systemCommand:script shouldWaitForProcess:YES];
    [[NSApplication sharedApplication] terminate:nil];
}

-(void) initWinePrefix {
    NSString *script = [NSString stringWithFormat:@"export WINEDLLOVERRIDES=\"mscoree,mshtml=\";export PATH=\"%@/bin:%@/bin:$PATH:/opt/local/bin:/opt/local/sbin\";export WINEPREFIX=\"%@\";DYLD_FALLBACK_LIBRARY_PATH=\"%@\" wineboot --init > \"/dev/null\" 2>&1", [self wineBundlePath], [self frameworksPath], [self winePrefixPath], [self frameworksPath]];
    [self setScriptPath:@""];
    
    // Start a new thread with the wine monitor
    dispatch_async(dispatchQueue, ^{
        [self monitorWineProcessForPrefixBuild];
    });
    
    [self systemCommand:script shouldWaitForProcess:YES];
    [[NSApplication sharedApplication] terminate:nil];
}

- (void)monitorWineProcessForPrefixBuild {
    // ----------- WINE BUG WORKAROUND ----------- //
    /* Wait 5 seconds for normal wineprefix build operation.
     * If we still have wine processes running after 5 seconds
     * this means that wine is stuck at 99% CPU
     * so find the stuck process and terminate it to give the
     * wineboot command a chance to finish */
    NSLog(@"Monitoring Wine processes");
    [NSThread sleepForTimeInterval:5.0f];
    BOOL foundStuckProcess = NO;
    for (NSInteger i=0; i<5; i++) {
        if (!foundStuckProcess) {
            // Look for wine and wineserver processes
            NSMutableArray *wineProcesses = [[NSMutableArray alloc] init];
            ProcessSerialNumber psn = {0, kNoProcess};
            while (!GetNextProcess(&psn)) {
                NSDictionary *application = (__bridge NSDictionary *)ProcessInformationCopyDictionary(&psn, kProcessDictionaryIncludeAllInformationMask);
                NSString *bundleName = (NSString *)[application objectForKey:@"CFBundleName"];
                if ([bundleName isEqualToString:@"wine"]) {
                    [wineProcesses addObject:[NSNumber numberWithInt:[[application objectForKey:@"pid"] intValue]]];
                }
            }
    
            // Scan for a maximum of five times for the stuck process
            [NSThread sleepForTimeInterval:5.0f];
            for (NSNumber *pid in wineProcesses) {
                NSNumber *cpuUsage = [self get_process_cpu_usage:[pid intValue]];
                if ([cpuUsage isGreaterThan:[NSNumber numberWithFloat:90.0f]]) {
                    NSLog(@"Found stuck process! It is %i, Cpu at %i", [pid intValue], [cpuUsage intValue]);
                    foundStuckProcess = YES;
                    [[NSRunningApplication runningApplicationWithProcessIdentifier:[pid intValue]] forceTerminate];
                }
            }
        }
    }
}

- (NSNumber *)get_process_cpu_usage:(int)pid {
    NSNumber *retval = [NSNumber numberWithInt:0];
    char ps_cmd[256];
    sprintf(ps_cmd, "ps -O %%cpu -p %d", pid); // see man page for ps
    FILE *fp = popen(ps_cmd, "r");
    if (fp) {
        char line[4096];
        while (line == fgets(line, 4096, fp)) {
            if (atoi(line) == pid) {
                char dummy[256];
                char cpu[256];
                char time[256];
                
                //   PID  %CPU   TT  STAT      TIME COMMAND
                // 32324   0,0 s001  S+     0:00.00 bc
                
                sscanf(line, "%s %s %s %s %s", dummy, cpu, dummy, dummy, time);
                
                pclose(fp);
                retval = [NSNumber numberWithFloat:[[NSString stringWithUTF8String:cpu] floatValue]];
                
                return retval;
            }
        }
        pclose(fp);
    }
    
    return retval;
}

- (NSString *)systemCommand:(NSString *)command shouldWaitForProcess:(BOOL)waitForProcess
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
        //cut out trailing new line
        if ([returnString hasSuffix:@"\n"])
        {
            [returnString deleteCharactersInRange:NSMakeRange([returnString length]-1,1)];
        }
    }
	return [NSString stringWithString:returnString];
}

@end
