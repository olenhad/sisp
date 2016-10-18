//
//  Generator.swift
//  sisp
//
//  Created by Omer Iqbal on 18/10/16.
//  Copyright © 2016 Garena. All rights reserved.
//

import Foundation
import LLVM_C

struct Context {
    var namedValues: [String : LLVMValueRef]
    let builder: LLVMBuilderRef?
    let module: LLVMModuleRef?
    
    init(moduleName: String) {
        module = LLVMModuleCreateWithName(moduleName)
        builder = LLVMCreateBuilder()
        namedValues = [:]
        
        LLVMLinkInMCJIT()
        LLVMInitializeNativeTarget()
        LLVMInitializeNativeAsmPrinter()
        
    }
    
    func run(function: LLVMValueRef?) -> Double {
        
        let engineSize = MemoryLayout<LLVMExecutionEngineRef?>.stride
        let engine = UnsafeMutablePointer<LLVMExecutionEngineRef?>.allocate(capacity: engineSize)
        
        let errorSize = MemoryLayout<UnsafeMutablePointer<Int8>?>.stride
        let error = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: errorSize)
        
        let res = LLVMCreateExecutionEngineForModule(engine, module, error)
        if res != 0 {
            let msg = String(cString: error.pointee!)
            print("\(msg)")
            exit(1)
        }
        
        let value = LLVMRunFunction(engine.pointee, function, 0, nil)
        let result = LLVMGenericValueToFloat(LLVMDoubleType(), value)
        
        LLVMDeleteFunction(function)
        
        return result
    }
}

enum GeneratorError : Error {
    case invalidState(desc: String)
}

struct Generator {
    static func codegen(program: Program, ctx: inout Context) throws -> LLVMValueRef? {
        
        var lastVal = LLVMConstReal(LLVMDoubleType(), 0.0)
        
        let mainType = LLVMFunctionType(LLVMDoubleType(), nil, 0, 0)
        let mainFunction = LLVMAddFunction(ctx.module, "main", mainType)
        
        let entryBlock = LLVMAppendBasicBlock(mainFunction, "entry")
        
        for expr in program.exprs {
            switch expr {
            case .function(_):
                let _ = try codegen(expr: expr, ctx: &ctx)
            default:
                LLVMPositionBuilderAtEnd(ctx.builder, entryBlock)
                lastVal = try codegen(expr: expr, ctx: &ctx)
            }
            
        }

        LLVMPositionBuilderAtEnd(ctx.builder, entryBlock)
        LLVMBuildRet(ctx.builder, lastVal)
        
        LLVMVerifyFunction(mainFunction, LLVMAbortProcessAction)
        
        return mainFunction
    }
    
    static func codegen(expr: Expr, ctx: inout Context) throws -> LLVMValueRef? {
        switch expr {
        case let .number(val):
            return LLVMConstReal(LLVMDoubleType(), val)
            
        case let .name(name):
            guard let value = ctx.namedValues[name] else {
                throw GeneratorError.invalidState(desc: "Unknown variable name: \(name)")
            }
            return value
            
        case .bin(op: let op, lhs: let lhs, rhs: let rhs):
            let l = try codegen(expr: lhs, ctx: &ctx)
            let r = try codegen(expr: rhs, ctx: &ctx)
            
            switch op {
                case "+":
                return LLVMBuildFAdd(ctx.builder, l, r, "addtmp")
                case "-":
                return LLVMBuildFSub(ctx.builder, l, r, "subtmp")
                case "*":
                return LLVMBuildFMul(ctx.builder, l, r, "multmp")
                case "/":
                return LLVMBuildFDiv(ctx.builder, l, r, "divtmp")
                case "=":
                let cmp = LLVMBuildFCmp(ctx.builder, LLVMRealOEQ, l, r, "cmptmp")
                return LLVMBuildSIToFP(ctx.builder, cmp, LLVMDoubleType(), "booltmp")
                case "<":
                    let cmp = LLVMBuildFCmp(ctx.builder, LLVMRealOLT, l, r, "cmptmp")
                    return LLVMBuildSIToFP(ctx.builder, cmp, LLVMDoubleType(), "booltmp")
                case ">":
                    let cmp = LLVMBuildFCmp(ctx.builder, LLVMRealOGT, l, r, "cmptmp")
                    return LLVMBuildSIToFP(ctx.builder, cmp, LLVMDoubleType(), "booltmp")
                default:
                    throw GeneratorError.invalidState(desc: "Unsupported Bin op: \(op)")
            }
            
        case .call(callee: let callee, args: let args):
            guard let function = LLVMGetNamedFunction(ctx.module, callee) else {
                throw GeneratorError.invalidState(desc: "Unknown function referenced: \(callee)")
            }
            let argCount = LLVMCountParams(function)
            if argCount != UInt32(args.count) {
                throw GeneratorError.invalidState(desc: "Invalid # of args. Expected \(argCount) args. Got \(args.count) args")
            }
            
            let codegenArgs: [LLVMValueRef?] = try args.map {(expr) in
                return try codegen(expr: expr, ctx: &ctx)
            }
            
            let argumentsSize = MemoryLayout<LLVMValueRef?>.stride * codegenArgs.count
            let arguments = UnsafeMutablePointer<LLVMValueRef?>.allocate(capacity: argumentsSize)
            
            arguments.initialize(from: codegenArgs)
            
            return LLVMBuildCall(ctx.builder, function, arguments, argCount, "sisp_call")
        
        case .function(proto: let proto, body: let body):
            let existingFunc = LLVMGetNamedFunction(ctx.module, proto.name)
            if existingFunc != nil {
                LLVMDeleteFunction(existingFunc)
            }
            
            let function = try codegen(proto: proto, ctx: ctx)
            
            let entryBlock = LLVMAppendBasicBlock(function, "entry")
            LLVMPositionBuilderAtEnd(ctx.builder, entryBlock)
            
            var namesInFnScope : [String] = []
            
            for i in 0..<proto.args.count {
                let param = LLVMGetParam(function, UInt32(i))
                let name = String(cString: LLVMGetValueName(param))
                namesInFnScope.append(name)
                
                ctx.namedValues[name] = param
            }
            
            let retVal = try codegen(expr: body, ctx: &ctx)
            LLVMBuildRet(ctx.builder, retVal)
            
            LLVMVerifyFunction(function, LLVMAbortProcessAction)
            
            for name in namesInFnScope {
                ctx.namedValues.removeValue(forKey: name)
            }
            
            return function
        
        case .ifexpr(cond: let cond, then: let then, elseE: let elseE):
            let condCode = try codegen(expr: cond, ctx: &ctx)
            let ifCond = LLVMBuildFCmp(ctx.builder, LLVMRealONE, condCode, LLVMConstReal(LLVMDoubleType(), 0.0), "ifcond")
            
            let functionEntryBB = LLVMGetInsertBlock(ctx.builder)
            let function = LLVMGetBasicBlockParent(functionEntryBB)
            
            var thenBB = LLVMAppendBasicBlock(function, "then")
            LLVMPositionBuilderAtEnd(ctx.builder, thenBB)
            let thenCode = try codegen(expr: then, ctx: &ctx)
            thenBB = LLVMGetInsertBlock(ctx.builder)
            
            var elseBB = LLVMAppendBasicBlock(function, "else")
            LLVMMoveBasicBlockAfter(elseBB, thenBB)
            LLVMPositionBuilderAtEnd(ctx.builder, elseBB)
            
            let elseCode = try codegen(expr: elseE, ctx: &ctx)
            elseBB = LLVMGetInsertBlock(ctx.builder)
            
            LLVMPositionBuilderAtEnd(ctx.builder, functionEntryBB)
            LLVMBuildCondBr(ctx.builder, ifCond, thenBB, elseBB)
            
            let continueBB = LLVMAppendBasicBlock(function, "continue")
            
            LLVMPositionBuilderAtEnd(ctx.builder, thenBB)
            LLVMBuildBr(ctx.builder, continueBB)
            thenBB = LLVMGetInsertBlock(ctx.builder)
            
            LLVMPositionBuilderAtEnd(ctx.builder, elseBB)
            LLVMBuildBr(ctx.builder, continueBB)
            elseBB = LLVMGetInsertBlock(ctx.builder)
            
            LLVMPositionBuilderAtEnd(ctx.builder, continueBB)
            
            let phi = LLVMBuildPhi(ctx.builder, LLVMDoubleType(), "iftmp")
            
            let incomingVals = UnsafeMutablePointer<LLVMValueRef?>.allocate(capacity: MemoryLayout<LLVMValueRef?>.stride * 2)
            incomingVals.initialize(from: [thenCode, elseCode])
            
            let incomingBlocks = UnsafeMutablePointer<LLVMBasicBlockRef?>.allocate(capacity: MemoryLayout<LLVMBasicBlockRef?>.stride * 2)
            incomingBlocks.initialize(from: [thenBB, elseBB])
            
            LLVMAddIncoming(phi, incomingVals, incomingBlocks, 2)
            
            return phi
        }
    }
    
    static func codegen(proto: Prototype, ctx: Context) throws -> LLVMValueRef? {
        let returnType = LLVMDoubleType()
        
        let paramTypes = UnsafeMutablePointer<LLVMTypeRef?>.allocate(capacity: proto.args.count)
        let doubleArgs: [LLVMTypeRef?] = (0..<proto.args.count).map {_ in LLVMDoubleType()}
        paramTypes.initialize(from: doubleArgs)
        
        let functionType = LLVMFunctionType(returnType, paramTypes, UInt32(proto.args.count), 0)
        let function = LLVMAddFunction(ctx.module, proto.name, functionType)
        
        for i in (0..<proto.args.count) {
            let param = LLVMGetParam(function, UInt32(i))
            LLVMSetValueName(param, proto.args[i])
        } 
        
        return function
    }
}
