//
//  main.swift
//  sisp
//
//  Created by Omer Iqbal on 16/10/16.
//  Copyright © 2016 Garena. All rights reserved.
//

import Foundation
import LLVM_C

//demo()

var context = Context(moduleName: "sisp")

while true {
    print("sisp> ", terminator: "")
    guard let input = readLine(strippingNewline: true) else {
        continue
    }
    
    do {
        let tokens = try Token.tokenize(input: input)
        let parseResult = try Parser.parse(tokens: tokens)
        print("Parser Result\n: \(parseResult.expr)")
        let value = try Generator.codegen(expr: parseResult.expr, ctx: &context)
        LLVMDumpValue(value)
    }
    catch let err as TokenizerError {
        print(err)
    }
    catch let err as ParserError {
        print(err)
    }
    catch {
        print("Unknown Error")
    }
}


