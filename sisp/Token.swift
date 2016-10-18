//
//  Tokenizer.swift
//  sisp
//
//  Created by Omer Iqbal on 16/10/16.
//  Copyright © 2016 Garena. All rights reserved.
//

import Foundation

enum TokenType {
    case paren
    case number
    case op
    case name
}

struct Token {
    let type: TokenType
    let val: String
    
    func isClosingParen() -> Bool {
        return type == .paren && val == ")" 
    }
    
    func isOpeningParen() -> Bool {
        return type == .paren && val == "(" 
    }
}

enum TokenizerError: Error {
    case unexpectedInput(input: String, failedAtChar: String)
}

extension Token {
    static func tokenize(input: String) throws -> [Token]  {
        var currentIndex = 0
        var tokens: [Token] = []
        
        while currentIndex < input.characters.count {
            var char = String(input[input.index(input.startIndex, offsetBy: currentIndex)])
            if char == ")" {
                tokens.append(Token(type:.paren, val: ")"))
                currentIndex = currentIndex + 1
                continue
            }
            if char == "(" {
                tokens.append(Token(type:.paren, val: "("))
                currentIndex = currentIndex + 1
                continue
            }
            
            let ops: [String] = ["+", "*", "-", "/", "<", ">", "="]
            if ops.contains(char) {
                tokens.append(Token(type:.op, val: String(char)))
                currentIndex = currentIndex + 1
                continue
            }
            
            if char.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines) == "" {
                currentIndex = currentIndex + 1;
                continue
            }
            

            if NSCharacterSet.decimalDigits.contains(char.unicodeScalars[char.unicodeScalars.startIndex]) {
                var val = ""
                var usedDecimal = false
                while currentIndex < input.characters.count && 
                    ((NSCharacterSet.decimalDigits.contains(char.unicodeScalars[char.unicodeScalars.startIndex])) ||
                    (!usedDecimal && char == ".")) 
                {
                        
                    if char == "." {
                        usedDecimal = true
                    }
                    
                    val.append(char)
                    if currentIndex + 1 >= input.characters.count {
                        tokens.append(Token(type: .number, val: val))
                        return tokens
                    }
                    
                    currentIndex = currentIndex + 1
                    char = String(input[input.index(input.startIndex, offsetBy: currentIndex)])
                }
                
                tokens.append(Token(type: .number, val: val))
                continue
            }

            if NSCharacterSet.letters.contains(char.unicodeScalars[char.unicodeScalars.startIndex]) {
                var val = ""
                while currentIndex < input.characters.count && NSCharacterSet.letters.contains(char.unicodeScalars[char.unicodeScalars.startIndex]) {
                    val.append(char)
                    if currentIndex + 1 >= input.characters.count {
                        tokens.append(Token(type: .name, val: val))
                        return tokens
                    }
                    currentIndex = currentIndex + 1
                    char = String(input[input.index(input.startIndex, offsetBy: currentIndex)])
                }
                
                tokens.append(Token(type: .name, val: val))
                continue
            }
            
            print("Sorry I can't parse this \(char)")
            throw TokenizerError.unexpectedInput(input: input, failedAtChar: char)
        }
        
        return tokens
    }
}
