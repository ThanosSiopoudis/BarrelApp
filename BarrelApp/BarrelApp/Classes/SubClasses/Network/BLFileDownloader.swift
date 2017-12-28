//
//  BLFileDownloader.swift
//  BarrelBundle
//
//  Created by Thanos Siopoudis on 26/07/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Foundation

class BLFileDownloader: NSObject, NSURLConnectionDataDelegate {
    var currentURL:NSURL?
    var receivedData:NSMutableData;
    var completionBlock:((Int, NSURL) -> Void)?
    var connection:NSURLConnection?
    var totalBytes:Int64 = 0;
    var saveURL:NSURL?
    
    override init() {
        self.receivedData = NSMutableData(length: 0)!;
        
        super.init();
    }
    
    convenience init(saveURL:NSURL?) {
        self.init();
        self.saveURL = saveURL;
    }
    
    func downloadWithNSURLConnectionFromURL(currentURL:NSURL?, completionBlock:((Int, NSURL) -> Void)!) {
        self.currentURL = currentURL;
        let theRequest:NSURLRequest = NSURLRequest(URL: self.currentURL!, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData, timeoutInterval: 60);
        self.completionBlock = completionBlock;
        
        if let connection:NSURLConnection = NSURLConnection(request: theRequest, delegate: self, startImmediately: false) {
            self.connection = connection;
        }
        else {
            let errorAlert:NSAlert = NSAlert();
            errorAlert.addButtonWithTitle("OK");
            errorAlert.messageText = "Connection Error";
            errorAlert.informativeText = "Barrel failed to connect to the server. Please check your connection, or try again later.";
            errorAlert.alertStyle = NSAlertStyle.WarningAlertStyle;
            errorAlert.runModal();
        }
    }
    
    func startDownload() {
        self.connection!.start();
    }
    
    func cancelDownload() {
        self.connection!.cancel();
    }
    
    func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        self.receivedData.length = 0;
        self.totalBytes = response.expectedContentLength;
    }
    
    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        self.receivedData.appendData(data);
    }
    
    func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        let errorAlert:NSAlert = NSAlert(error: error);
        errorAlert.runModal();
    }
    
    func connection(connection: NSURLConnection, willCacheResponse cachedResponse: NSCachedURLResponse) -> NSCachedURLResponse? {
        return nil;
    }
    
    func connectionDidFinishLoading(connection: NSURLConnection) {
        if let sURL = self.saveURL {
            do {
                try NSFileManager.defaultManager().createDirectoryAtURL(sURL,
                    withIntermediateDirectories: true,
                    attributes: nil);
            }
            catch let err as NSError {
                let errorAlert:NSAlert = NSAlert(error: err);
                errorAlert.runModal();
            }
            
            let urlPathWithFilename:NSURL = sURL.URLByAppendingPathComponent(self.currentURL!.lastPathComponent!);
            self.receivedData.writeToURL(urlPathWithFilename, atomically: true);
            if let cBlock = self.completionBlock {
                cBlock(1, urlPathWithFilename);
            }
        }
    }
}
















