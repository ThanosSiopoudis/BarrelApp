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

#import "BLFileDownloader.h"
#import "OEHUDAlert+DefaultAlertsAdditions.h"

@implementation BLFileDownloader

- (id)init {
    self = [super init];
    return self;
}

- (id)initWithProgressBar:(OEHUDProgressbar *)progressBar saveToPath:(NSString *)path {
    self = [super init];
    
    if (self) {
        [self setProgress:progressBar];
        [self setSavePath:path];
    }
    
    return self;
}

- (void)downloadWithNSURLConnectionFromURL:(NSString *)currentURL withCompletionBlock:(void (^)(int, NSString *))completionBlock {
    [self setCurrentURL:currentURL];
    NSURL *url = [NSURL URLWithString:currentURL];
    NSURLRequest *theRequest = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60];
    
    [self setReceivedData:[[NSMutableData alloc] initWithLength:0]];
    [self setCompletionBlock:[completionBlock copy]];
    
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self startImmediately:NO];
    if (connection) {
        [self setConnection:connection];
    }
    else {
        OEHUDAlert *alert = [OEHUDAlert alertWithMessageText:@"Error connecting to server!" defaultButton:@"OK" alternateButton:@""];
        [alert runModal];
    }
}

- (void)startDownload {
    [[self connection] start];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [[self receivedData] setLength:0];
    [self setTotalBytes:[response expectedContentLength]];
    [[self progress] setMaxValue:(float)[self totalBytes]];
    [[self progress] setMinValue:0.0f];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [[self receivedData] appendData:data];
    float progressive = (float)[[self receivedData] length];
    [[self progress] setValue:progressive];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    OEHUDAlert *alert = [OEHUDAlert alertWithError:error];
    [alert runModal];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse: (NSCachedURLResponse *)cachedResponse {
    return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSLog(@"Succeeded! Received %ld bytes of data",(unsigned long)[[self receivedData] length]);
    NSError * error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:[self savePath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    if (error != nil) {
        NSLog(@"error creating directory: %@", error);
    }
    
    NSString *pathWithFilename = [NSString stringWithFormat:@"%@/%@", [self savePath], [[self currentURL] lastPathComponent]];
    [[self receivedData] writeToFile:pathWithFilename atomically:YES];
    NSLog(@"File written to path: %@", pathWithFilename);
    [self completionBlock](1, pathWithFilename);
}

@end
