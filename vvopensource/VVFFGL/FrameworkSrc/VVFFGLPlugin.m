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

        plugMainUnion result;
        result = _pluginData->main(FF_GETINFO, 0, 0);
        if ((result.ivalue != FF_SUCCESS) || (result.svalue == NULL)) {
            [self release];
            return nil;
        }
        _pluginData->info = (PluginInfoStruct *)result.svalue;
        if ((_pluginData->info->PluginType != FF_SOURCE) && (_pluginData->info->PluginType != FF_EFFECT)) {
            // Bail if this is some future other type of plugin.
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
    return _pluginData->info->PluginType;
}
@end
