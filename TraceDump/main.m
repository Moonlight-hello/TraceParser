//
//  main.m
//  TraceDump
//
//  Created by MoonNight on 03/03/2024.
//  Copyright © 2025 MoonNight. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PrivateCPlusPlusHeader.h"
#import "InstrumentsPrivateHeader.h"
#import "AllocationPrivateHeader.h"
#import "TimeProfilePrivateHeader.h"
#import "VideoCardRunPrivateHeader.h"
#import "StreamPowerPrivateHeader.h"
#import "NetworkingPrivateHeader.h"
#import "ActivityMonitorHeader.h"

void printMethodInfo(Class cls);
NSString *getTypeAsString(const char *typeEncoding);
void printMethodInfo(Class cls) {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL selector = method_getName(methods[i]);
        const char *methodName = sel_getName(selector);
        
        // 获取方法的类型编码
        const char *typeEncoding = method_getTypeEncoding(methods[i]);
        
        // 打印方法名称和类型编码
        NSLog(@"Method: %s, Type Encoding: %s", methodName, typeEncoding);
    }
    
    free(methods);
}

// 函数：打印方法参数类型
void printMethodParameterTypes1(Class cls) {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        const char *methodName = sel_getName(selector);
        
        NSLog(@"Method: %s", methodName);
        
        // 获取参数数量
        unsigned int numberOfArguments = method_getNumberOfArguments(method);
        for (unsigned int j = 0; j < numberOfArguments; j++) {
            // 获取参数类型
            char *typeEncoding = method_copyArgumentType(method, j);
            if (typeEncoding) {
                NSLog(@"Parameter %d Type: %s", j, typeEncoding);
                free(typeEncoding); // 记得释放
            }
        }
        
        NSLog(@"\n"); // 换行
    }
    
    free(methods);
}

void printMethodParameterTypes2(Class cls) {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        const char *methodName = sel_getName(selector);
        
        NSLog(@"Method: %s", methodName);
        
        // 获取参数数量
        unsigned int numberOfArguments = method_getNumberOfArguments(method);
        
        for (unsigned int j = 0; j < numberOfArguments; j++) {
            char typeEncoding[256]; // 缓冲区
            method_getArgumentType(method, j, typeEncoding, sizeof(typeEncoding));
            //NSString *typeString = getTypeAsString(typeEncoding);
          //  NSLog(@"Parameter %d Type: %@", j, typeEncoding);
        }
        
        NSLog(@"\n"); // 换行
    }
    
    free(methods);
}

// 函数：打印对象的类型
// 函数：根据类型编码获取具体的对象类型
NSString *getTypeAsString(const char *typeEncoding) {
    if (typeEncoding[0] == '@') {
        // 对象类型，返回类名
        NSString *className = [NSString stringWithUTF8String:typeEncoding + 2]; // 跳过 "@" 和 "<"
        return className;
    } else if (typeEncoding[0] == 'i') {
        return @"int";
    } else if (typeEncoding[0] == 's') {
        return @"short";
    } else if (typeEncoding[0] == 'f') {
        return @"float";
    } else if (typeEncoding[0] == 'd') {
        return @"double";
    } else if (typeEncoding[0] == 'v') {
        return @"void";
    } else if (typeEncoding[0] == 'B') {
        return @"BOOL";
    }
    return [NSString stringWithUTF8String:typeEncoding]; // 返回原始编码
}

static NSBundle *(*NSBundle_mainBundle_original)(id self, SEL _cmd);
static NSBundle *NSBundle_mainBundle_replaced(id self, SEL _cmd) {
    return [NSBundle bundleWithPath:@"/Applications/Xcode.app/Contents/Applications/Instruments.app"];
//    return [NSBundle bundleWithPath:@"/Users/sherlock/Downloads/Xcode-beta.app/Contents/Applications/Instruments.app"];
}

static void __attribute__((constructor)) hook() {
    Method NSBundle_mainBundle = class_getClassMethod(NSBundle.class, @selector(mainBundle));
    NSBundle_mainBundle_original = (void *)method_getImplementation(NSBundle_mainBundle);
    method_setImplementation(NSBundle_mainBundle, (IMP)NSBundle_mainBundle_replaced);
}

int main(int argc, const char * argv[]) {
    if (argc !=2) {
        LKPrint(@"usage:  /path/to/TraceDump /path/to/xxx.trace");
        return 0;
    }
    
    @autoreleasepool {
        //初始化 Instruments
        Class myClass = NSClassFromString(@"XRPackageConflictErrorAccumulator");
        
        if (!myClass) {
            NSLog(@"Class XRPackageConflictErrorAccumulator not found");
            return 1;
        }
        
        id myInstance = [myClass alloc];
        SEL selector = @selector(initWithNextResponder:);
        if ([myInstance respondsToSelector:selector]) {
//            // 使用 NSInvocation 调用方法 这句代码非常重要！！！！
            NSMethodSignature *signature = [myInstance methodSignatureForSelector:selector];
        } else {
            NSLog(@"Method handleIssue:type:from: not found");
        }
        
        PFTInitializeSharedFrameworks();
        
        [PFTDocumentController sharedDocumentController];
        
        // 打开一个 trace document.
        // NSString *tracePath = @"/Users/wangxinlong/Documents/Text-systrace.trace";
        NSString *tracePath = @"/Users/wangxinlong/Documents/MemoryTrace.trace";
        NSError *error = nil;
        NSURL *traceUrl = [NSURL fileURLWithPath:tracePath];
        
        PFTTraceDocument *document = [[PFTTraceDocument alloc] init];
        
        //读取trace文件
        error = nil;
        
        [document readFromURL:traceUrl ofType:@"com.apple.instruments.trace" error:&error];
        
        if (error) {
            LKPrint(@"\nError: %@\n", error);
            return 1;
        }
        LKPrint(@"Trace: %@\n", tracePath);
        
        // List some useful metadata of the document.
        XRDevice *device = document.targetDevice;
        LKPrint(@"Device: %@ (%@ %@ %@)\n", device.deviceDisplayName, device.productType, device.productVersion, device.buildVersion);
        PFTProcess *process = document.defaultProcess;
        LKPrint(@"Process: %@ (%@)\n", process.displayName, process.bundleIdentifier);
        
        
        // Each trace document consists of data from several different instruments.
        XRTrace *trace = document.trace;
        //打印Target信息
        NSDictionary *_runData = LKIvar(LKIvar(trace, _runData),_runData)[@1];
        NSArray *arr = _runData[@"recordingSettingsSummary"];
        LKPrint(@"%@",arr[0]);
        for (XRInstrument *instrument in trace.allInstrumentsList.allInstruments) {
            LKPrint(@"\nInstrument: %@ (%@)\n", instrument.type.name, instrument.type.uuid);
            
            // Common routine to obtain the data container.
            if (![instrument isKindOfClass:XRLegacyInstrument.class]) {
                instrument.viewController = [[XRAnalysisCoreStandardController alloc]initWithInstrument:instrument document:document];
            }
            id<XRInstrumentViewController> controller = instrument.viewController;
            
            id<XRContextContainer> container = controller.detailContextContainer.contextRepresentation.container;
            
            // Each instrument can have multiple runs.
            NSArray<XRRun *> *runs = instrument.allRuns;
            if (runs.count == 0) {
                LKPrint(@"No data.\n");
                continue;
            }
            
            for (XRRun *run in runs) {
                LKPrint(@"Run #%@: %@\n", @(run.runNumber));
                instrument.currentRun = run;
                NSString *instrumentID = instrument.type.uuid;
                
                if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.coresampler2"]) {
                    ParseTimeProfile(instrument);
                }else if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.oa"]) {
                    ParseAllocationWithRun(run);
                }else if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.coreanimation"]){
                    ParseCoreAnimation(run);
                }else if([instrumentID isEqualToString:@"com.apple.xray.power.mobile.cpu"] || [instrumentID isEqualToString:@"com.apple.xray.power.mobile.energy"] || [instrumentID isEqualToString:@"com.apple.xray.power.mobile.net"]){
                    ParsePowerMobileTemplate(container);
                }else if([instrumentID isEqualToString:@"com.apple.xray.instrument-type.quartz"]){
                    ParseGPUDriver(run);
                }else if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.networking"]){
                    ParseNetworking(container);
                }else if([instrumentID isEqualToString:@"com.apple.xray.instrument-type.activity.all"]){
                    ParseActivitymonitor(run);
                }else {
                    LKPrint(@"Data processor has not been implemented for this type of instrument.\n");
                }
            }
            [controller instrumentWillBecomeInvalid];
        }
        [document close];
    }
    return 0;
}
