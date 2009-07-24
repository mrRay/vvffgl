//
//  vvFFGLPlugin.m
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "VVFFGLPlugin.h"
#import "FreeFrame.h"

struct VVFFGLPluginData {
    FF_Main_FuncPtr main;
    PluginInfoStruct *info;
};

@implementation VVFFGLPlugin

- (id)initWithPath:(NSString *)path
{
    if (self = [super init]) {
        
        NSURL *url = [NSURL URLWithString:path];
        if (url == nil) {
            [self release];
            return nil;
        }
        
        _bundle = CFBundleCreate(kCFAllocatorDefault, (CFURLRef)url);
        if (_bundle == NULL) {
            [self release];
            return nil;
        }
        
        _pluginData = malloc(sizeof(struct VVFFGLPluginData));
        if (_pluginData == NULL) {
            [self release];
            return nil;
        }
        
        _pluginData->main = CFBundleGetFunctionPointerForName(_bundle, CFSTR("plugMain"));
        if (_pluginData->main == NULL) {
            [self release];
            return nil;
        }
        plugMainUnion result = m_ffPluginMain(FF_GETPARAMETERDEFAULT,(DWORD)i,0);
        if (result.ivalue!=FF_FAIL)
        {
            SetFloatParameter(i,result.fvalue);
        }
    }
        plugMainUnion result;
        PluginInfoStruct *infoPtr;
        FF_Main_FuncPtr functionPtr = _pluginData->main;
        result = functionPtr(FF_GETINFO, 0, 0);
        _pluginData->info = (PluginInfoStruct *)(*_pluginData->main)(FF_GETINFO, 0, 0);
        DWORD r = (*_pluginData->main)(FF_INITIALISE, 0, 0);
        if (r != FF_SUCCESS) {
            [self release];
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    if (_bundle)
        CFRelease(_bundle);
    [super dealloc];
}

- (VVFFGLPluginType)type
{
    
}
@end
