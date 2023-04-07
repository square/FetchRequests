//
//  Logging.swift
//  FetchRequests-iOS
//
//  Created by Adam Lickel on 10/1/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import Foundation

#if canImport(CocoaLumberjack)
import CocoaLumberjack

func CWLogVerbose(
    _ message: @autoclosure () -> String,
    level: DDLogLevel = dynamicLogLevel,
    context: Int = 0,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    tag: Any? = nil,
    asynchronous async: Bool = true,
    ddlog: DDLog = DDLog.sharedInstance
) {
    DDLogVerbose(
        message(),
        level: level,
        context: context,
        file: file,
        function: function,
        line: line,
        tag: tag,
        asynchronous: async,
        ddlog: ddlog
    )
}

func CWLogDebug(
    _ message: @autoclosure () -> String,
    level: DDLogLevel = dynamicLogLevel,
    context: Int = 0,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    tag: Any? = nil,
    asynchronous async: Bool = true,
    ddlog: DDLog = DDLog.sharedInstance
) {
    DDLogDebug(
        message(),
        level: level,
        context: context,
        file: file,
        function: function,
        line: line,
        tag: tag,
        asynchronous: async,
        ddlog: ddlog
    )
}

func CWLogInfo(
    _ message: @autoclosure () -> String,
    level: DDLogLevel = dynamicLogLevel,
    context: Int = 0,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    tag: Any? = nil,
    asynchronous async: Bool = true,
    ddlog: DDLog = DDLog.sharedInstance
) {
    DDLogInfo(
        message(),
        level: level,
        context: context,
        file: file,
        function: function,
        line: line,
        tag: tag,
        asynchronous: async,
        ddlog: ddlog
    )
}

func CWLogWarning(
    _ message: @autoclosure () -> String,
    level: DDLogLevel = dynamicLogLevel,
    context: Int = 0,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    tag: Any? = nil,
    asynchronous async: Bool = true,
    ddlog: DDLog = DDLog.sharedInstance
) {
    DDLogWarn(
        message(),
        level: level,
        context: context,
        file: file,
        function: function,
        line: line,
        tag: tag,
        asynchronous: async,
        ddlog: ddlog
    )
}

func CWLogError(
    _ message: @autoclosure () -> String,
    level: DDLogLevel = dynamicLogLevel,
    context: Int = 0,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    tag: Any? = nil,
    asynchronous async: Bool = false,
    ddlog: DDLog = DDLog.sharedInstance
) {
    DDLogError(
        message(),
        level: level,
        context: context,
        file: file,
        function: function,
        line: line,
        tag: tag,
        asynchronous: async,
        ddlog: ddlog
    )
}
#else
func CWLogDebug(_ message: @autoclosure () -> String) {
#if DEBUG
    NSLog(message())
#endif
}

func CWLogInfo(_ message: @autoclosure () -> String) {
#if DEBUG
    NSLog(message())
#endif
}

func CWLogWarning(_ message: @autoclosure () -> String) {
#if DEBUG
    NSLog(message())
#endif
}

func CWLogVerbose(_ message: @autoclosure () -> String) {
#if DEBUG
    NSLog(message())
#endif
}

func CWLogError(_ message: @autoclosure () -> String) {
#if DEBUG
    NSLog(message())
#endif
}
#endif
