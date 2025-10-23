//  AppPaths.swift
//  Aegis
//  Created by Khalid Alkhaldi on 10/20/25.
//

import Foundation
import AppKit

struct AppPaths {
    static let appName = "Aegis"

    static var appSupportDir: URL = {
        let fm = FileManager.default
        let base = try! fm.url(for: .applicationSupportDirectory,
                               in: .userDomainMask,
                               appropriateFor: nil,
                               create: true)
        let dir = base.appendingPathComponent(appName, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    static var logFile: URL {
        appSupportDir.appendingPathComponent("Aegis_error.log")
    }

    static func log(_ s: String) {
        let line = s + "\n"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: logFile.path) {
            if let h = try? FileHandle(forWritingTo: logFile) {
                do { try h.seekToEnd(); try h.write(contentsOf: data); try h.close() } catch { }
            }
        } else {
            try? data.write(to: logFile)
        }
    }

    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
