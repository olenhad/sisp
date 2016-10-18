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
        let program = try Parser.parseProgram(tokens: tokens)
        print("Parser Result\n: \(program)")
        
        let code = try Generator.codegen(program: program, ctx: &context)
        print("CodeGen Result:\n:")
        LLVMDumpModule(context.module)
        
        let result = context.run(function: code)
        
        print("RESULT = \(result)")
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


