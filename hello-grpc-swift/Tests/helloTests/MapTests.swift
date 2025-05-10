import Foundation
import Testing

@testable import HelloCommon

@Suite("Map Tests")
struct MapTests {
    @Test("Test Answer Map")
    func testAnswerMap() {
        // 测试 ansMap 中的值是否正确
        let hello = Utils.helloList[1] // "Bonjour"
        let thanks = Utils.ansMap[hello]

        #expect(thanks == "Merci beaucoup", "The answer for 'Bonjour' should be 'Merci beaucoup'")

        // 打印所有映射关系以便调试
        print("全部语言对应关系:")
        for (key, value) in Utils.ansMap {
            print("\(key) -> \(value)")
        }
    }

    @Test("Test Hello List")
    func testHelloList() {
        // 测试 helloList 是否包含预期的值
        #expect(Utils.helloList.count == 6, "Hello list should contain 6 items")
        #expect(Utils.helloList[0] == "Hello")
        #expect(Utils.helloList[1] == "Bonjour")
        #expect(Utils.helloList[2] == "Hola")
    }
}
