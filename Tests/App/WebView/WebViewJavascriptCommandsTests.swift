//
//  WebViewJavascriptCommandsTests.swift
//  Tests-App
//
//  Created by Bruno Pantaleão on 11/4/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//
@testable import HomeAssistant
import Testing

struct WebViewJavascriptCommandsTests {
    @Test func testWebViewJavascriptCommandsSearchEntities() async throws {
        #expect(WebViewJavascriptCommands.searchEntitiesKeyEvent == """
        var event = new KeyboardEvent('keydown', {
            key: 'e',
            code: 'KeyE',
            keyCode: 69,
            which: 69,
            metaKey: false,
            bubbles: true,
            cancelable: true
        });
        (document.body || document.documentElement || document).dispatchEvent(event);
        """)
    }

    @Test func testWebViewJavascriptCommandsQuickSearch() async throws {
        #expect(WebViewJavascriptCommands.quickSearchKeyEvent == """
        var event = new KeyboardEvent('keydown', {
            key: 'k',
            code: 'KeyK',
            keyCode: 75,
            which: 75,
            metaKey: true,
            bubbles: true,
            cancelable: true
        });
        (document.body || document.documentElement || document).dispatchEvent(event);
        """)
    }

    @Test func testWebViewJavascriptCommandsSearchDevices() async throws {
        #expect(WebViewJavascriptCommands.searchDevicesKeyEvent == """
        var event = new KeyboardEvent('keydown', {
            key: 'd',
            code: 'KeyD',
            keyCode: 68,
            which: 68,
            metaKey: false,
            bubbles: true,
            cancelable: true
        });
        (document.body || document.documentElement || document).dispatchEvent(event);
        """)
    }

    @Test func testWebViewJavascriptCommandsSearchCommands() async throws {
        #expect(WebViewJavascriptCommands.searchCommandsKeyEvent == """
        var event = new KeyboardEvent('keydown', {
            key: 'c',
            code: 'KeyC',
            keyCode: 67,
            which: 67,
            metaKey: false,
            bubbles: true,
            cancelable: true
        });
        (document.body || document.documentElement || document).dispatchEvent(event);
        """)
    }

    @Test func testWebViewJavascriptCommandsAssist() async throws {
        #expect(WebViewJavascriptCommands.assistKeyEvent == """
        var event = new KeyboardEvent('keydown', {
            key: 'a',
            code: 'KeyA',
            keyCode: 65,
            which: 65,
            metaKey: false,
            bubbles: true,
            cancelable: true
        });
        (document.body || document.documentElement || document).dispatchEvent(event);
        """)
    }
}
