//
//  NSWorkspace+BLFileTypes.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 04/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Cocoa

extension NSWorkspace {
    
    func fileAtURL(URL:NSURL, matchesTypes acceptedTypes:NSSet) -> Bool {
        return self.file(URL.path!, matchesTypes: acceptedTypes);
    }
    
    func file(filePath:String, matchesTypes acceptedTypes:NSSet) -> Bool {
        var fileType:String? = nil;
        do {
            fileType = try self.typeOfFile(filePath);
        }
        catch {
            print(error);
        }
        
        if let ft = fileType {
            for at in acceptedTypes {
                let acceptedType:String = at as! String;
                if (self.type(ft, conformsToType: acceptedType) == true) {
                    return true;
                }
            }
        }
        
        // If no filetype match was found, check whether the file extension alone matches any of the specified types.
        // (This allows us to judge filetypes based on filename alone, e.g. for nonexistent/inaccessible files;
        // and works around an NSWorkspace typeOfFile: limitation whereby it may return an overly generic UTI
        // for a file or folder instead of a proper specific UTI.
        let fileExtension:String = filePath.pathExtension;
        if (fileExtension.characters.count > 0) {
            for at in acceptedTypes {
                let acceptedType:String = at as! String;
                if (self.filenameExtension(fileExtension, isValidForType: acceptedType) == true) {
                    return true;
                }
            }
        }
        
        return false;
    }
}