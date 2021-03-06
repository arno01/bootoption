/*
 * Log.swift
 * Copyright (c) 2014 Ben Gollmer.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import os.log

struct Log {
        
        static func logExit(_ status: Int32, _ errorMessage: String? = nil) -> Never {
                let logMessage: StaticString = "* exit status %{public}d"
                if status == 0 || status == 64 {
                        Log.info(logMessage,status)
                        exit(status)
                }
                var description = String()
                if let string: String = errorMessage {
                         description = "\(string) "
                } else {
                        switch status {
                        case EX_SOFTWARE:
                                description = "Error: Internal "
                        case EX_NOPERM:
                                description = "Error: Permission denied "
                        case EX_NOINPUT:
                                description = "Error: No input "
                        case EX_CANTCREAT:
                                description = "Error: Can't create "
                        case EX_UNAVAILABLE:
                                description = "Error: Service unavailable "
                        case EX_IOERR:
                                description = "Error: I/O "
                        default:
                                description = ""
                        }
                }
                print("\(description)(\(status))", to: &standardError)
                Log.log(logMessage,status)
                exit(status)
        }
        
        static func debug(_ message: StaticString, _ arg: CVarArg = "") {
                if #available(OSX 10.12, *) {
                        os_log(message, log: .default, type: .debug, arg)
                } else {
                        //
                }
        }
        
        static func info(_ message: StaticString, _ arg: CVarArg = "") {
                if #available(OSX 10.12, *) {
                        os_log(message, log: .default, type: .info, arg)
                } else {
                        //
                }
        }
        
        static func log(_ message: StaticString, _ arg: CVarArg = "") {
                if #available(OSX 10.12, *) {
                        os_log(message, log: .default, type: .default, arg)
                } else {
                        //
                }
        }
        
        static func error(_ message: StaticString, _ arg: CVarArg = "") {
                if #available(OSX 10.12, *) {
                        os_log(message, log: .default, type: .error, arg)
                } else {
                        //
                }
        }
}
