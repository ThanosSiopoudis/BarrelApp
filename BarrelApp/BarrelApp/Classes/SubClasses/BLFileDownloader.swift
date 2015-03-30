//
//  BLFileDownloader.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 22/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Cocoa

class BLFileDownloader:NSObject, NSURLConnectionDelegate, NSURLConnectionDataDelegate {
    
    typealias execClosure = ((resultCode:Int, downloadedFileURL:NSURL) -> ());
    dynamic var totalBytes:Int64 = 0;
    dynamic var currentBytes:Int64 = 0;
    var receivedData:NSMutableData?
    var connection:NSURLConnection?
    var sourceURL:NSURL?
    var targetURL:NSURL?
    var didFinishCallback:execClosure?
    
    convenience init(fromURL URL:NSURL?, toURL:NSURL?) {
        self.init();
        
        var request:NSURLRequest
        self.sourceURL = URL;
        self.targetURL = toURL;
        if let srcURL = self.sourceURL {
            request = NSURLRequest(URL: srcURL, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData, timeoutInterval: 60);
            self.receivedData = NSMutableData(length: 0);
            
            var connection:NSURLConnection? = NSURLConnection(request: request, delegate: self, startImmediately: false);
            if let conn = connection {
                self.connection = conn;
            }
            else {
                // Throw some error
            }
        }
        else {
            // Throw some error
        }
    }
    
    func startDownoad() {
        self.connection?.start();
    }
    
    func cancelDownload() {
        self.connection?.cancel();
    }
    
    func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        self.receivedData?.length = 0;
        self.totalBytes = response.expectedContentLength;
    }
    
    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        self.receivedData?.appendData(data);
        self.currentBytes = Int64(self.receivedData!.length);
    }
    
    func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        // Throw some kind of error
        return;
    }
    
    func connection(connection: NSURLConnection, willCacheResponse cachedResponse: NSCachedURLResponse) -> NSCachedURLResponse? {
        return nil;
    }
    
    func connectionDidFinishLoading(connection: NSURLConnection) {
        var error:NSError?
        NSFileManager.defaultManager().createDirectoryAtURL(self.targetURL!, withIntermediateDirectories: true, attributes: nil, error: &error);
        var fname:String? = self.sourceURL!.lastPathComponent;
        if let filename = fname {
            var finalPathWithFile:NSURL = self.targetURL!.URLByAppendingPathComponent(filename);
            self.receivedData?.writeToURL(finalPathWithFile, atomically: true);
            if let closure = self.didFinishCallback {
                closure(resultCode:1, downloadedFileURL:finalPathWithFile);
            }
        }
    }
}