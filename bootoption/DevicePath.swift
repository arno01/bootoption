/*
 * File: DevicePath.swift
 *
 * bootoption © vulgo 2017-2018 - A program to create / save an EFI boot
 * option - so that it might be added to the firmware menu later
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import Foundation

struct HardDriveMediaDevicePath {
        
        var data: Data {
                get {
                        var data = Data.init()
                        data.append(type)
                        data.append(subType)
                        data.append(length)
                        data.append(partitionNumber)
                        data.append(partitionStart)
                        data.append(partitionSize)
                        data.append(partitionSignature)
                        data.append(partitionFormat)
                        data.append(signatureType)
                        return data
                }
        }
        
        let mountPoint: String
        let type = Data.init(bytes: [4])
        let subType = Data.init(bytes: [1])
        let length = Data.init(bytes: [42, 0])
        var partitionNumber = Data.init()
        var partitionStart = Data.init()
        var partitionSize = Data.init()
        var partitionSignature = Data.init()
        let partitionFormat = Data.init(bytes: [2])
        let signatureType = Data.init(bytes: [2])
        
        init(forFile path: String) {
                let fileManager: FileManager = FileManager()
                
                guard fileManager.fileExists(atPath: path) else {
                        Log.error("Loader not found at specified path")
                        Log.logExit(EX_IOERR)
                }
                
                guard let session:DASession = DASessionCreate(kCFAllocatorDefault) else {
                        Log.error("Failed to create DASession")
                        Log.logExit(EX_UNAVAILABLE)
                }
                
                guard var volumes:[URL] = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: nil) else {
                        Log.error("Failed to get mounted volume URLs")
                        Log.logExit(EX_UNAVAILABLE)
                }
                volumes = volumes.filter { $0.isFileURL }

                /*  Find a mounted volume path from our loader path */

                var longestMatch: Int = 0
                var mountedVolumePath: String = ""
                let prefix: String = "file://"

                for volume in volumes {
                        let unprefixedVolumeString: String = volume.absoluteString.replacingOccurrences(of: prefix, with: "")
                        let stringLength: Int = unprefixedVolumeString.characters.count
                        let start: String.Index = unprefixedVolumeString.index(unprefixedVolumeString.startIndex, offsetBy: 0)
                        let end: String.Index = unprefixedVolumeString.index(unprefixedVolumeString.startIndex, offsetBy: stringLength)
                        let test: String = String(path[start..<end])
                        
                        /*
                         *  Check if unprefixedVolumeString is the start of our loader path string,
                         *  and also the longest mounted volume path that is also a string match
                         */
                        
                        if test.uppercased() == unprefixedVolumeString.uppercased() && stringLength > longestMatch {
                                mountedVolumePath = unprefixedVolumeString
                                longestMatch = stringLength
                        }
                }
                
                mountPoint = mountedVolumePath

                /*  Find DAMedia registry path */

                let cfMountPoint: CFString = mountPoint as CFString
                
                guard let url: CFURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, cfMountPoint, CFURLPathStyle(rawValue: 0)!, true) else {
                        Log.error("Failed to create CFURL for mount point")
                        Log.logExit(EX_UNAVAILABLE)
                }
                guard let disk: DADisk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url) else {
                        Log.error("Failed to create DADisk from volume URL")
                        Log.logExit(EX_UNAVAILABLE)
                }
                guard let cfDescription: CFDictionary = DADiskCopyDescription(disk) else {
                        Log.error("Failed to get volume description CFDictionary")
                        Log.logExit(EX_UNAVAILABLE)
                }
                guard let description: [String: Any] = cfDescription as? Dictionary else {
                        Log.error("Failed to get volume description as Dictionary")
                        Log.logExit(EX_UNAVAILABLE)
                }
                guard let daMediaPath = description["DAMediaPath"] as? String else {
                        Log.error("Failed to get DAMediaPath as String")
                        Log.logExit(EX_UNAVAILABLE)
                }

                /* Get the registry object for our partition */

                let partitionProperties: RegistryEntry = RegistryEntry.init(fromPath: daMediaPath)
                
                /* To do - Check disk is GPT */
                
                let ioPreferredBlockSize: Int? = partitionProperties.getIntValue(forProperty: "Preferred Block Size")
                let ioPartitionID: Int? = partitionProperties.getIntValue(forProperty: "Partition ID")
                let ioBase: Int? = partitionProperties.getIntValue(forProperty: "Base")
                let ioSize: Int? = partitionProperties.getIntValue(forProperty: "Size")
                let ioUUID: String? = partitionProperties.getStringValue(forProperty: "UUID")
                
                if (ioPreferredBlockSize == nil || ioPartitionID == nil || ioBase == nil || ioSize == nil || ioUUID == nil) {
                        Log.error("Failed to get registry values")
                        Log.logExit(EX_UNAVAILABLE)
                }
                
                let blockSize: Int = ioPreferredBlockSize!
                let uuid: String = ioUUID!
                var idValue = UInt32(ioPartitionID!)
                partitionNumber.append(UnsafeBufferPointer(start: &idValue, count: 1))
                var startValue = UInt64(ioBase! / blockSize)
                partitionStart.append(UnsafeBufferPointer(start: &startValue, count: 1))
                var sizeValue = UInt64(ioSize! / blockSize)
                partitionSize.append(UnsafeBufferPointer(start: &sizeValue, count: 1))

                /*  EFI Signature from volume GUID string */

                var part: [String] = uuid.components(separatedBy: "-")
                partitionSignature.append(part[0].hexToData(swap: true)!)
                partitionSignature.append(part[1].hexToData(swap: true)!)
                partitionSignature.append(part[2].hexToData(swap: true)!)
                partitionSignature.append(part[3].hexToData()!)
                partitionSignature.append(part[4].hexToData()!)
        }
}

struct FilePathMediaDevicePath {
        
        var data: Data {
                get {
                        var data = Data.init()
                        data.append(type)
                        data.append(subType)
                        data.append(length)
                        data.append(path)
                        return data
                }
        }
        
        let type = Data.init(bytes: [4])
        let subType = Data.init(bytes: [4])
        var path = Data.init()
        var length = Data.init()
        
        init(path localPath: String, mountPoint: String) {
                
                /* Path */
                
                let c: Int = mountPoint.characters.count
                let i: String.Index = localPath.index(localPath.startIndex, offsetBy: c)
                var efiPath: String = "/" + localPath[i...]
                efiPath = efiPath.uppercased().replacingOccurrences(of: "/", with: "\\")
                if efiPath.containsOutlawedCharacters() {
                        Log.error("Forbidden character(s) found in path")
                        Log.logExit(EX_DATAERR)
                }
                var pathData: Data = efiPath.data(using: String.Encoding.utf16)!
                pathData.removeFirst()
                pathData.removeFirst()
                pathData.append(contentsOf: [0, 0])
                path = pathData
                
                /* Length */
                
                var lengthValue = UInt16(pathData.count + 4)
                length.append(UnsafeBufferPointer(start: &lengthValue, count: 1))
        }   
}

struct EndDevicePath {
        let data = Data.init(bytes: [127, 255, 4, 0])
}

