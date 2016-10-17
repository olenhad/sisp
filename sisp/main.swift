//
//  main.swift
//  sisp
//
//  Created by Omer Iqbal on 16/10/16.
//  Copyright © 2016 Garena. All rights reserved.
//

import Foundation

while true {
    print("sisp> ", terminator: "")
    guard let input = readLine(strippingNewline: true) else {
        continue
    }
    
    do {
        let tokens = try Token.tokenize(input: input)
        let parseResult = try Parser.parse(tokens: tokens)
        print(parseResult.expr)
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

