//
//  Parser.swift
//  sisp
//
//  Created by Omer Iqbal on 17/10/16.
//  Copyright © 2016 Garena. All rights reserved.
//

import Foundation

struct ParserResult<T> {
    let expr: T
    let remaining: [Token]
}

enum ParserError : Error {
    case invalidState
    case unexpectedInput(expected: String)
}

struct Parser {
    static func parseProgram(tokens: [Token]) throws -> Program {
        var result = try parseExpr(tokens: tokens)
        var exprs = [result.expr]
        
        while result.remaining.count > 0 {
            result = try parseExpr(tokens: result.remaining)
            exprs.append(result.expr)
        }
        
        return Program(exprs: exprs)
    }
    
    static func parseExpr(tokens: [Token]) throws -> ParserResult<Expr> {
        guard let first = tokens.first else {
            throw ParserError.invalidState
        }
        
        switch first.type {
        case .number:
            guard let double = Double(first.val) else {
                throw ParserError.invalidState
            }
            return ParserResult(expr: Expr.number(val: double), remaining: tokens.rest())
        
        case .name:
            return ParserResult(expr: Expr.name(name: first.val), remaining: tokens.rest())
        
        case .paren where first.val == "(":
            if tokens.count == 1 {
                throw ParserError.unexpectedInput(expected: "More tokens after )")
            }
            
            let next = tokens[1]
            switch next.type {
            case .op:
                return try parseBinOp(tokens: tokens.rest())
            case .name where next.val == "defn":
                return try parseFunction(tokens: tokens.rest().rest())
            case .name where next.val == "if":
                return try parseIf(tokens: tokens.rest())
            case .name:
                return try parseCall(tokens: tokens.rest())
            default:
                throw ParserError.unexpectedInput(expected: "Expected op, defn, if, or call")
            }

        default:
            throw ParserError.unexpectedInput(expected: "Expected number, name or paren")
        }
    }
    
    static func parseBinOp(tokens: [Token]) throws -> ParserResult<Expr> {
        guard let first = tokens.first else {
            throw ParserError.invalidState
        }
        
        let lhs = try parseExpr(tokens: tokens.rest())
        if lhs.remaining.count < 2 {
            throw ParserError.unexpectedInput(expected: "Binary Op should have two operands")
        }
        
        let rhs = try parseExpr(tokens: lhs.remaining)
        
        guard let closing = rhs.remaining.first else {
            throw ParserError.unexpectedInput(expected: "Expected closing paren )")
        }
        
        if !closing.isClosingParen() {
            throw ParserError.unexpectedInput(expected: "Expected closing paren )")
        }
        
        return ParserResult(expr: Expr.bin(op: first.val, lhs: lhs.expr, rhs: rhs.expr), 
                            remaining: rhs.remaining.rest())
    }
    
    static func parseFunction(tokens: [Token]) throws -> ParserResult<Expr> {
        guard let funcName = tokens.first else {
            throw ParserError.invalidState
        }
        
        if funcName.type != .name {
            throw ParserError.unexpectedInput(expected: "Expected function Name")
        }
        
        let funcProto = try parseFunctionArgs(tokens: tokens.rest(), funcName: funcName.val)
        
        let funcBody = try parseExpr(tokens: funcProto.remaining)
        
        guard let closing = funcBody.remaining.first else {
            throw ParserError.unexpectedInput(expected: "Expected closing paren )")
        }
        
        if !closing.isClosingParen() {
            throw ParserError.unexpectedInput(expected: "Expected closing paren )")
        }
        
        return ParserResult(expr: Expr.function(proto: funcProto.expr, body: funcBody.expr), remaining: funcBody.remaining.rest())
    }
    
    static func parseFunctionArgs(tokens: [Token], funcName: String) throws -> ParserResult<Prototype> {
        guard let _ = tokens.first else {
            throw ParserError.unexpectedInput(expected: "Expected (")
        }
        
        let (args, rest) = tokens.rest().splitUntil { (token) -> Bool in
            return token.type != .name
        }
        
        let names = args.map {$0.val}
        let protoExpr = Prototype(name: funcName, args: names)
        
        guard let closing = rest.first else {
            throw ParserError.unexpectedInput(expected: "Expected closing paren )")
        }
        
        if !closing.isClosingParen() {
            throw ParserError.unexpectedInput(expected: "Expected closing paren )")
        }
        
        return ParserResult(expr: protoExpr, remaining: rest.rest())
    }
    
    static func parseCall(tokens: [Token]) throws -> ParserResult<Expr> {
        guard let name = tokens.first else {
            throw ParserError.unexpectedInput(expected: "Expected calling func name")
        }
        
        var remaining: [Token] = tokens.rest()
        var exprs: [Expr] = []
        
        while remaining.count > 0 && !remaining[0].isClosingParen() {
            let result = try parseExpr(tokens: remaining)
            remaining = result.remaining
            exprs.append(result.expr)
        }
        
        return ParserResult(expr: Expr.call(callee: name.val, args: exprs), remaining: remaining.rest()) 
    }
    
    static func parseIf(tokens: [Token]) throws -> ParserResult<Expr> {
        guard let first = tokens.first else {
            throw ParserError.unexpectedInput(expected: "Expected if")
        }
        
        if !(first.type == .name && first.val == "if") {
            throw ParserError.unexpectedInput(expected: "Expected if")
        }
        
        let cond = try parseExpr(tokens: tokens.rest())
        let then = try parseExpr(tokens: cond.remaining)
        let elseE = try parseExpr(tokens: then.remaining)
        
        guard let closing = elseE.remaining.first else {
            throw ParserError.unexpectedInput(expected: "Expected closing paren )")
        }
        
        if !closing.isClosingParen() {
            throw ParserError.unexpectedInput(expected: "Expected closing paren )")
        }
        
        return ParserResult(expr: Expr.ifexpr(cond: cond.expr, then: then.expr, elseE: elseE.expr), remaining: elseE.remaining.rest())
    }
}

extension Array {
    func rest() -> Array {
        return Array(self.dropFirst())
    }

    func splitUntil(pred: (Element) -> Bool) -> ([Element], [Element]) {
        var first : [Element] = []
        var second: [Element] = []
        var split = false
        for item in self {
            if !split {
                split = pred(item)
            }
            if !split {
                first.append(item)
            } else {
                second.append(item)
            }
        }
        
        return (first, second)
    }
}
