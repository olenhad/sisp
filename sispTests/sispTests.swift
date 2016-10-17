//
//  sispTests.swift
//  sispTests
//
//  Created by Omer Iqbal on 18/10/16.
//  Copyright © 2016 Garena. All rights reserved.
//

import XCTest

class SispTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testLiterals() {
        assertValidInput(input: "1", expected: Expr.number(val: 1))
        assertValidInput(input: "a", expected: Expr.name(name: "a"))
    }
    
    func assertValidInput(input: String, expected: Expr) {
        do {
            let tokens = try Token.tokenize(input: input)
            let parseResult = try Parser.parse(tokens: tokens)
            print(parseResult.expr)
            XCTAssert(parseResult.expr == expected)
        }
        catch let err as TokenizerError {
            print(err)
            XCTAssert(false)
        }
        catch let err as ParserError {
            print(err)
            XCTAssert(false)
        }
        catch {
            print("Unknown Error")
            XCTAssert(false)
        }
    }
}
