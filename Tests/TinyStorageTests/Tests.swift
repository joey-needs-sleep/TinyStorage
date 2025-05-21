//
//  Tests.swift
//  TinyStorage
//
//  Created by Joseph Hassell on 4/11/25.
//

import XCTest
import Foundation
import SwiftUI
@testable import TinyStorage


struct TestObject: Codable, Equatable {
    let value: Int
}



class TinyStorageTests: XCTestCase {
    
    var storage: TinyStorage!
    var tempDirectoryURL: URL!
    var resetAfterTest = true;
    
    override func setUp() {
        super.setUp()
        // Create a unique temporary directory for each test run.
        tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        // Initialize TinyStorage with the temp directory and a test-specific name.
        storage = TinyStorage(insideDirectory: tempDirectoryURL, name: "testTinyStorage")
    }
    
    override func tearDown() {
        // Reset TinyStorage to try to remove the file on disk.
        if resetAfterTest {
            storage.reset()
        }
        // Clean up the temporary directory.
        try? FileManager.default.removeItem(at: tempDirectoryURL)
        storage = nil
        tempDirectoryURL = nil
        super.tearDown()
    }
    
    /// Test storing and retrieving a simple Codable object.
    func testStoreAndRetrieveCodable() {
        let key: String = "testObject"
        let original = TestObject(value: 42)
        
        storage.store(original, forKey: key)
        
        guard let retrieved: TestObject = storage.retrieve(type: TestObject.self, forKey: key) else {
            XCTFail("Failed to retrieve the stored object")
            return
        }
        XCTAssertEqual(original, retrieved, "The retrieved object should match the stored object")
    }
    
    func testStoreAndRetrieveData() {
        let key: String = "testData"
        let original = Data([0x01, 0x02, 0x03])
        
        storage.store(original, forKey: key)
        
        guard let retrieved: Data = storage.retrieve(type: Data.self, forKey: key) else {
            XCTFail("Failed to retrieve the stored object")
            return
        }
        XCTAssertEqual(original, retrieved, "The retrieved object should match the stored object")
    }
    
    /// Test that storing nil removes the value.
    func testStoreNilRemovesValue() {
        let key: String = "nilTest"
        
        storage.store("non-nil", forKey: key)
        XCTAssertNotNil(storage.retrieve(type: String.self, forKey: key))
        
        storage.store(nil, forKey: key)
        XCTAssertNil(storage.retrieve(type: String.self, forKey: key), "Storing nil should remove the value for the key")
    }
    
    /// Test that helper functions for booleans and integers return proper default values and stored values.
    func testBoolAndIntegerHelpers() {
        let boolKey: String = "boolTest"
        let intKey: String = "intTest"
        
        // Defaults when nothing is stored
        XCTAssertFalse(storage.bool(forKey: boolKey), "Default bool value should be false")
        XCTAssertEqual(storage.integer(forKey: intKey), 0, "Default integer value should be 0")
        
        // After storing a value
        storage.store(true, forKey: boolKey)
        storage.store(123, forKey: intKey)
        XCTAssertTrue(storage.bool(forKey: boolKey), "Stored bool value should be retrieved as true")
        XCTAssertEqual(storage.integer(forKey: intKey), 123, "Stored integer value should be retrieved correctly")
    }
    
    /// Test that incrementing an integer key works correctly.
    func testIncrementInteger() {
        let counterKey: String = "counterTest"
        
        // If the key does not exist, the first increment should return 1.
        XCTAssertEqual(storage.incrementInteger(forKey: counterKey), 1, "First increment should initialize to 1")
        
        // Increment by a custom value.
        XCTAssertEqual(storage.incrementInteger(forKey: counterKey, by: 2), 3, "Value should increment to 3 after adding 2")
        
        // Increment by default (1) should now make it 4.
        XCTAssertEqual(storage.incrementInteger(forKey: counterKey), 4, "Value should increment to 4 after another addition")
    }
    
    /// Test that bulkStore writes multiple items with one disk write and that skip behavior works.
    func testBulkStore() {
        let items: [String: (any Codable)?] = [
            "bulkString": "hello",
            "bulkInt": 99,
            "bulkBool": true
        ]
        storage.bulkStore(items: items)
        
        XCTAssertEqual(storage.retrieve(type: String.self, forKey: "bulkString"), "hello")
        XCTAssertEqual(storage.retrieve(type: Int.self, forKey: "bulkInt"), 99)
        XCTAssertEqual(storage.retrieve(type: Bool.self, forKey: "bulkBool"), true)
        
        // Now test skipKeyIfAlreadyPresent; change a value and verify it is not overwritten.
        storage.store("world", forKey: "bulkString")
        let newItems: [String: (any Codable)?] = ["bulkString": "shouldNotOverwrite"]
        storage.bulkStore(items: newItems, skipKeyIfAlreadyPresent: true)
        XCTAssertEqual(storage.retrieve(type: String.self, forKey: "bulkString"), "world", "BulkStore should skip keys that already exist when the flag is true")
    }
    
    /// Test migration from a UserDefaults instance.
    func testMigrate() {
        // Create an isolated UserDefaults instance using a unique suite name.
        let suiteName = "TinyStorageTestsSuite"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        
        // Set values that would simulate items stored by UserDefaults.
        userDefaults.set(123, forKey: "nonBoolInt")
        userDefaults.set("Test String", forKey: "nonBoolString")
        userDefaults.set(true, forKey: "boolKey")
        
        
        // Migrate keys from UserDefaults into TinyStorage.
        storage.migrate(userDefaults: userDefaults,
                        nonBoolKeys: ["nonBoolInt", "nonBoolString"],
                        boolKeys: ["boolKey"],
                        overwriteTinyStorageIfConflict: false)
        
        // Verify that the values have been migrated correctly.
        XCTAssertEqual(storage.retrieve(type: Int.self, forKey: "nonBoolInt"), 123)
        XCTAssertEqual(storage.retrieve(type: String.self, forKey: "nonBoolString"), "Test String")
        XCTAssertEqual(storage.retrieve(type: Bool.self, forKey: "boolKey"), true)
        
        // Clean up by removing the persistent domain for this test suite.
        userDefaults.removePersistentDomain(forName: suiteName)
    }
    
    /// Test that reset removes all stored values.
    func testReset() {
        let key: String = "someKey"
        storage.store("someValue", forKey: key)
        XCTAssertNotNil(storage.retrieve(type: String.self, forKey: key))
        
        storage.reset()
        XCTAssertNil(storage.retrieve(type: String.self, forKey: key), "After reset, the value should be removed")
        resetAfterTest = false // Prevent double reset in tearDown
    }
    
    /// Test that the allKeys property includes keys that have been stored.
    func testAllKeys() {
        let key: String = "testKey"
        storage.store("value", forKey: key)
        
        let has = storage.allKeys.contains { $0.rawValue == key }
        XCTAssertTrue(has, "allKeys should contain the stored key")
    }
    
    /// Test that the publisher emits an update when a value is added.
    func testPublisherValueAdded() {
        let expectation = self.expectation(description: "Publisher should emit change")
        let key: String = "publisherTest"
        
        // Subscribe to the publisher. Here we test that when a new value is stored for the key, a new value is emitted.
        let cancellable = storage.publisher(for: key)
            .sink {
                expectation.fulfill()
            }
        
        // Store a new value to trigger the publisher.
        storage.store(10, forKey: key)
        
        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
    }
    
    func testPublisherValueChanged() {
        let expectation = self.expectation(description: "Publisher should emit change")
        let key: String = "publisherTest"
        storage.store(11, forKey: key)
        // Subscribe to the publisher. Here we test that when a new value is stored for the key, a new value is emitted.
        let cancellable = storage.publisher(for: key)
            .sink {
                expectation.fulfill()
            }
        
        // Store a new value to trigger the publisher.
        storage.store(10, forKey: key)
        
        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
    }

    func testPublisherValueNotChanged() {
        let expectation = self.expectation(description: "Publisher should not emit change")
        expectation.isInverted = true
        let key: String = "publisherTest"
        storage.store(10, forKey: key)
        // Subscribe to the publisher. Here we test that when a new value is stored for the key, a new value is emitted.
        let cancellable = storage.publisher(for: key)
            .sink {
                expectation.fulfill()
            }
        
        // Store a new value to trigger the publisher.
        storage.store(10, forKey: key)
        
        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
    }
    
    func testPublisherValueDeleted() {
        let expectation = self.expectation(description: "Publisher should emit change")
        let key: String = "publisherTest"
        storage.store(10, forKey: key)
        // Subscribe to the publisher. Here we test that when a new value is stored for the key, a new value is emitted.
        let cancellable = storage.publisher(for: key)
            .sink {
                expectation.fulfill()
            }
        
        // Store a new value to trigger the publisher.
        storage.remove(key: key)
        
        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
    }

    @MainActor func testSwiftUINotifier(){
        let someUnusedKey = "someUnusedKey"
        let observedObject = TinyStorageItemNotifier<String>(storage: storage, key: someUnusedKey)
        XCTAssertFalse(observedObject.shouldUpdateFlag)
        
        //update it
        storage.store("someValue", forKey: someUnusedKey)
        XCTAssertTrue(observedObject.shouldUpdateFlag)
        
    }
    
}

    
