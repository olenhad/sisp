//
//  Expr.swift
//  sisp
//
//  Created by Omer Iqbal on 17/10/16.
//  Copyright © 2016 Garena. All rights reserved.
//

import Foundation

enum Expr {
    case number(val: Double)
    case name(name: String)
    indirect case bin(op: String, lhs: Expr, rhs: Expr)
    indirect case call(callee: String, args: [Expr])
    indirect case function(proto: Prototype, body: Expr)
    indirect case ifexpr(cond: Expr, then: Expr, elseE: Expr)
}

struct Prototype {
    let name: String
    let args: [String]
}

struct Program {
    let exprs: [Expr]
}
