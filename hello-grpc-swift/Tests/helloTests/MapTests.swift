import Foundation
import Testing

@testable import HelloCommon // Allows access to Utils internal/public members

@Suite("Map Tests")
struct MapTests {
    @Test("Test HelloList Content and Order")
    func testHelloListComprehensive() {
        let expectedHelloList: [String] = [
            "Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요",
        ]
        #expect(Utils.helloList.count == expectedHelloList.count, "helloList count should be \(expectedHelloList.count)")
        #expect(Utils.helloList == expectedHelloList, "helloList content and order should match expected")
    }

    @Test("Test All HelloList Greetings Have Answers in AnsMap")
    func testAllHelloListGreetingsHaveAnswers() {
        for greeting in Utils.helloList {
            #expect(Utils.ansMap[greeting] != nil, "Greeting '\(greeting)' should have an entry in ansMap")
            if let answer = Utils.ansMap[greeting] {
                #expect(!answer.isEmpty, "Answer for '\(greeting)' should not be empty")
            }
        }
    }

    @Test("Test Specific AnsMap Entries")
    func testSpecificAnsMapEntries() {
        // Test a few specific key-value pairs for known important translations
        #expect(Utils.ansMap["Hello"] == "Thank you very much", "AnsMap entry for 'Hello' is incorrect")
        #expect(Utils.ansMap["Bonjour"] == "Merci beaucoup", "AnsMap entry for 'Bonjour' is incorrect")
        #expect(Utils.ansMap["こんにちは"] == "どうも ありがとう ございます", "AnsMap entry for 'こんにちは' is incorrect")
        
        // Test the extra entry not in helloList
        #expect(Utils.ansMap["你好"] == "非常感谢", "AnsMap entry for '你好' is incorrect")
    }

    @Test("Test AnsMap Contains All HelloList Keys") // Redundant with testAllHelloListGreetingsHaveAnswers but more explicit
    func testAnsMapCoverageOfHelloList() {
        for greeting in Utils.helloList {
            #expect(Utils.ansMap.keys.contains(greeting), "ansMap should contain the key '\(greeting)' from helloList")
        }
    }
    
    @Test("Debug Print Mappings") // Optional: keep if useful for debugging, can be removed
    func debugPrintMappings() {
        print("--- Debug: helloList ---")
        for item in Utils.helloList {
            print(item)
        }
        print("--- Debug: ansMap ---")
        for (key, value) in Utils.ansMap {
            print("\(key) -> \(value)")
        }
    }
}
