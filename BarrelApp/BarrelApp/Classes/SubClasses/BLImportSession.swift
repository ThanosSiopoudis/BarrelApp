//
//  BLImportSession.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 04/02/2015.
//  Copyright (c) 2015 AppCake Limited. All rights reserved.
//

import Foundation

class BLImportSession: NSObject, BLOperationDelegate {
    
    class var ignoredFilePatterns:NSArray {
        get {
            let patterns:[String] = [
                "(^|/)directx",             // DirectX redistributables
                "(^|/)acrodos",             // Adobe Acrobat reader (DOS)
                "(^|/)acroread\\.exe$",     // Adobe Acrobat reader (Windows)
                "(^|/)uvconfig\\.exe$",     // UniVBE detection program
                "(^|/)univbe",              // UniVBE program/redistributable folder
                
                "(^|/)unins000\\.",                 // GOG uninstaller files
                "(^|/)Graphic mode setup\\.exe$",   // GOG Configiration programs
                "(^|/)gogwrap\\.exe$",              // GOG only knows what this one does

                "(^|/)autorun",             // Windows CD-autorun stubs
                "(^|/)bootdisk\\.",         // Bootdisk makers
                "(^|/)readme\\.",           // Readme viewers
                
                "(^|/)foo\\.bat",           // Backup script included by mistake
                                            // on some Mac X-Wing CDROM editions

                "(^|/)vinstall\\.bat",      // ??
                
                "(^|/)pkunzip\\.",          // Archivers
                "(^|/)pkunzjr\\.",
                "(^|/)arj\\.",
                "(^|/)lha\\."
            ];
            
            return patterns;
        }
    }
    
    class var playableGameTelltaleExtensions:NSArray {
        get {
            let extensions:[String] = [
                "bundle",               // Could be a blwine.bundle file
                "drive_c",              // The filesystem for Wine
                "dosdevices",           // Likewise
                "reg"                   // Wine registry files
            ];
            
            return extensions;
        }
    }
    
    class var playableGameTelltalePatterns:NSArray {
        get {
            let patterns:[String] = [
                "^gfw_high\\.ico$"      // Indicates a GOG game
            ];
            
            return patterns;
        }
    }
    
    class var installerPatterns:NSArray {
        get {
            let patterns:[String] = [
                "inst",
                "setup",
                "config"
            ];
            
            return patterns;
        }
    }
    
    class var preferredInstallerPatterns:NSArray {
        get {
            let patterns:[String] = [
                "^setup\\.",
                "^install\\.",
                "^dosinst",
                "^hdinstal\\."
            ];
            
            return patterns;
        }
    }
    
    class func isPlayableGameTelltaleAtPath(path:String) -> Bool {
        var filename:String = path.lastPathComponent.lowercaseString;
        
        // Do a quick test first using just the extension
        if (self.playableGameTelltaleExtensions.containsObject(filename.pathExtension)) {
            return true;
        }
        
        // Next, test against our filename patterns
        for pattern in self.playableGameTelltalePatterns {
            let pat:String = pattern as String;
            if (Regex(pat).test(filename)) {
                return true;
            }
        }
        
        return false;
    }
    
    class func isIgnoredFileAtPath(path:String) -> Bool {
        for pattern in self.ignoredFilePatterns {
            let pat:String = pattern as String;
            if (Regex(pat).test(path)) {
                return true;
            }
        }
        
        return false;
    }
    
    class func isInstallerAtPath(path:String) -> Bool {
        var fileName:String = path.lastPathComponent.lowercaseString;
        
        for pattern in self.installerPatterns {
            let pat:String = pattern as String;
            if (Regex(pat).test(fileName)) {
                return true;
            }
        }
        
        return false;
    }
}