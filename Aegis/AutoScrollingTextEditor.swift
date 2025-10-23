//  AutoScrollingTextEditor.swift
//  Aegis
//  Created by Khalid Alkhaldi on 10/21/25.

import SwiftUI
import AppKit

struct AutoScrollingTextEditor: NSViewRepresentable {
    enum AutoScrollMode { case smartFollow, none }

    @Binding var text: String
    var isEditable: Bool = true
    var font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    var autoScroll: AutoScrollMode = .smartFollow

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false

        let tv = NSTextView()
        tv.isEditable = isEditable
        tv.isSelectable = true
        tv.isRichText = false
        tv.importsGraphics = false
        tv.usesFindBar = true
        tv.allowsUndo = true

        tv.isHorizontallyResizable = false
        tv.isVerticallyResizable = true
        tv.autoresizingMask = [.width]

        tv.drawsBackground = true
        tv.backgroundColor = .textBackgroundColor
        tv.textColor = .textColor
        tv.font = font
        tv.textContainerInset = NSSize(width: 6, height: 6)

        if let tc = tv.textContainer {
            tc.widthTracksTextView = true
            tc.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        }

        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        tv.string = text

        // Delegate wiring
        tv.delegate = context.coordinator
        context.coordinator.textView = tv
        context.coordinator.lastLength = text.utf16.count

        scroll.documentView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? NSTextView else { return }

        // Keep container width in sync with scroll view width.
        if let tc = tv.textContainer {
            let newWidth = scroll.contentSize.width
            if tc.containerSize.width != newWidth {
                tc.containerSize = NSSize(width: newWidth, height: CGFloat.greatestFiniteMagnitude)
            }
        }

        if tv.isEditable != isEditable { tv.isEditable = isEditable }
        if tv.font != font { tv.font = font }

        // Avoid caret jump: only set when actually changed
        if tv.string != text {
            let oldLen = tv.string.utf16.count
            tv.string = text
            context.coordinator.lastLength = text.utf16.count

            if autoScroll == .smartFollow, text.utf16.count > oldLen {
                scrollToEnd(tv)
            }
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AutoScrollingTextEditor
        weak var textView: NSTextView?
        var lastLength: Int = 0

        init(_ parent: AutoScrollingTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.text = tv.string

            guard parent.autoScroll == .smartFollow else { return }

            // If user was at end or content grew, keep end visible
            let selEnd = tv.selectedRange().upperBound
            let wasAtEnd = (selEnd >= lastLength)
            let grew = tv.string.utf16.count >= lastLength
            if wasAtEnd || grew {
                parent.scrollToEnd(tv)
            }
            lastLength = tv.string.utf16.count
        }
    }

    // MARK: - Helpers

    private func scrollToEnd(_ tv: NSTextView) {
        let end = NSRange(location: tv.string.utf16.count, length: 0)
        tv.scrollRangeToVisible(end)
        if isEditable { tv.setSelectedRange(end) }
    }
}
