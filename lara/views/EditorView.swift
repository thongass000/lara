//
//  FontPicker.swift
//  lara
//
//  Created by ruter on 27.03.26.
//

import SwiftUI

public struct EditorView: View {
    public init(
        sysplistpath: String = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
    ) {
        self.sysplistpath = sysplistpath
    }

    private let sysplistpath: String

    @State private var text: String = ""
    @State private var status: String = ""
    @State private var busy: Bool = false
    @State private var lastsavedtext: String = ""

    @State private var findquery: String = ""
    @State private var findindex: String.Index? = nil

    @State private var keyquery: String = ""
    @State private var keyresult: String = ""

    public var body: some View {
        NavigationStack {
            List {
                Button("Save") {
                    savetosys()
                }
                .disabled(busy || text.isEmpty)
                
                Button("Validate") {
                    validate()
                }
                .disabled(busy || text.isEmpty)
                
                Button("Format XML") {
                    format()
                }
                .disabled(busy || text.isEmpty)
                
                Spacer()
                
                Text(hasunsavedchanges ? "Unsaved" : "Saved")
                    .font(.caption)
                    .foregroundColor(hasunsavedchanges ? .orange : .secondary)
                
                HStack(spacing: 8) {
                    TextField("Find", text: $findquery)
                    Button("Find Next") { findnext() }
                        .disabled(findquery.isEmpty || text.isEmpty)
                }
                
                HStack(spacing: 8) {
                    TextField("Key Lookup", text: $keyquery)
                    Button("Lookup") { lookupkey() }
                        .disabled(keyquery.isEmpty || text.isEmpty)
                    Text(keyresult)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if !status.isEmpty {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        loadfromsys()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(busy)
                }
            }
            .onAppear { loadfromsys() }
        }
    }

    private var hasunsavedchanges: Bool { text != lastsavedtext }

    private func loadfromsys() {
        busy = true; defer { busy = false }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: sysplistpath))
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            let xml = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            text = String(data: xml, encoding: .utf8) ?? ""
            lastsavedtext = text
            status = "Loaded from system."
        } catch { status = "Load failed: \(error.localizedDescription)" }
    }

    private func savetosys() {
        busy = true; defer { busy = false }
        do {
            guard let data = text.data(using: .utf8) else { status = "Save failed: bad text"; return }
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            let xml = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try xml.write(to: URL(fileURLWithPath: sysplistpath), options: .atomic)
            text = String(data: xml, encoding: .utf8) ?? text
            lastsavedtext = text
            status = "Saved to system."
        } catch { status = "Save failed: \(error.localizedDescription)" }
    }

    private func validate() {
        do {
            guard let data = text.data(using: .utf8) else { status = "Validate failed: bad text"; return }
            _ = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            status = "Plist is valid."
        } catch { status = "Plist invalid: \(error.localizedDescription)" }
    }

    private func format() {
        do {
            guard let data = text.data(using: .utf8) else { status = "Format failed: bad text"; return }
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            let xml = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            text = String(data: xml, encoding: .utf8) ?? text
            status = "Formatted as XML."
        } catch { status = "Format failed: \(error.localizedDescription)" }
    }

    private func findnext() {
        guard !findquery.isEmpty else { return }
        let start = findindex ?? text.startIndex
        if let range = text.range(of: findquery, range: start..<text.endIndex) ??
            text.range(of: findquery, range: text.startIndex..<start) {
            findindex = range.upperBound
            let lc = lineandcolumn(at: range.lowerBound, in: text)
            status = "Found at line \(lc.line), col \(lc.col)."
        } else {
            status = "Not found."
        }
    }

    private func lookupkey() {
        do {
            guard let data = text.data(using: .utf8) else { keyresult = "bad text"; return }
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            if let value = findkey(in: plist, key: keyquery) {
                keyresult = "\(value)"
            } else {
                keyresult = "not found"
            }
        } catch { keyresult = "invalid plist" }
    }

    private func findkey(in obj: Any, key: String) -> Any? {
        if let dict = obj as? [String: Any] {
            if let v = dict[key] { return v }
            for (_, v) in dict {
                if let found = findkey(in: v, key: key) { return found }
            }
        } else if let arr = obj as? [Any] {
            for v in arr {
                if let found = findkey(in: v, key: key) { return found }
            }
        }
        return nil
    }

    private func lineandcolumn(at idx: String.Index, in s: String) -> (line: Int, col: Int) {
        var line = 1, col = 1
        var i = s.startIndex
        while i < idx {
            if s[i] == "\n" { line += 1; col = 1 } else { col += 1 }
            i = s.index(after: i)
        }
        return (line, col)
    }
}

