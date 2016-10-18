//
//  LLVMDemo.swift
//  sisp
//
//  Created by Omer Iqbal on 18/10/16.
//  Copyright © 2016 Garena. All rights reserved.
//

import Foundation
import LLVM_C

func demo () {
    let module = LLVMModuleCreateWithName("test")
    
    let int32 = LLVMInt32Type()
    let returnType = int32
    
    let paramTypes: UnsafeMutablePointer<LLVMTypeRef?> = UnsafeMutablePointer.allocate(capacity: 2)
    paramTypes.initialize(from:[int32, int32])
    
    let functionType = LLVMFunctionType(returnType, paramTypes, 2, 0)
    
    let sumFunction = LLVMAddFunction(module, "add", functionType)
    
    let builder = LLVMCreateBuilder()
    let entryBlock = LLVMAppendBasicBlock(sumFunction, "entry")
    LLVMPositionBuilderAtEnd(builder, entryBlock)
    
    let a = LLVMGetParam(sumFunction, 0)
    let b = LLVMGetParam(sumFunction, 1)
    let result = LLVMBuildAdd(builder, a, b, "entry")
    LLVMBuildRet(builder, result)

    
    let engineSize = MemoryLayout<LLVMExecutionEngineRef?>.stride
    let engine = UnsafeMutablePointer<LLVMExecutionEngineRef?>.allocate(capacity: engineSize)
    
    let errorSize = MemoryLayout<UnsafeMutablePointer<Int8>?>.stride
    let error = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: errorSize)
    
    LLVMLinkInMCJIT()
    LLVMInitializeNativeTarget()
    LLVMInitializeNativeAsmPrinter()
    
    let res = LLVMCreateExecutionEngineForModule(engine, module, error)
    if res != 0 {
        let msg = String(cString: error.pointee!)
        print("\(msg)")
        exit(1)
    }
    
    
    func runSumFunc(a: Int, _ b: Int) -> Int {
        let functionType = LLVMFunctionType(int32, nil, 0, 0)
        let wrapperFunction = LLVMAddFunction(module, "", functionType)
        
        let entryBlock = LLVMAppendBasicBlock(wrapperFunction, "entry")
        LLVMPositionBuilderAtEnd(builder, entryBlock)
        
        let argumentsSize = MemoryLayout<LLVMValueRef>.stride * 2
        let arguments = UnsafeMutablePointer<LLVMValueRef?>.allocate(capacity: argumentsSize)
        
        let argA = LLVMConstInt(int32, UInt64(a), 0)
        let argB = LLVMConstInt(int32, UInt64(b), 0)
        
        arguments.initialize(from: [argA, argB])
        
        let callTem = LLVMBuildCall(builder, sumFunction, arguments, 2, "sum_temp")
        LLVMBuildRet(builder, callTem)
        
        let value = LLVMRunFunction(engine.pointee, wrapperFunction, 0, nil)
        
        let result = LLVMGenericValueToInt(value, 0)
        LLVMDumpModule(module)
        
        
        return Int(result)
    }
    
    print("11 + 22 = \(runSumFunc(a: 11, 22))")
        
    //LLVMDisposeModule(module)
}
