//
//  FFGLRenderer.m
//  VVOpenSource
//
//  Created by Tom on 24/07/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "FFGLRenderer.h"
#import "FFGLPlugin.h"
#import "FFGLGPURenderer.h"
#import "FFGLCPURenderer.h"

@implementation FFGLRenderer

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithPlugin:(FFGLPlugin *)plugin context:(CGLContextObj)cgl_ctx;
{
    if (self = [super init]) {
        if ([self class] == [FFGLRenderer class]) {
            [self release];
            if ([plugin mode] == FFGLPluginModeGPU) {
                return [[FFGLGPURenderer alloc] initWithPlugin:plugin context:cgl_ctx];
            } else if ([plugin mode] == FFGLPluginModeCPU) {
                return [[FFGLCPURenderer alloc] initWithPlugin:plugin context:cgl_ctx];
            } else {
                return nil;
            }        
        } else {
            _plugin = [plugin retain];
            _pluginContext = CGLRetainContext(cgl_ctx);
        }
    }	
    return self;
}

- (void)dealloc
{
    if(_pluginContext != nil) {
        CGLReleaseContext(_pluginContext);
    }
    [_plugin release];
    [super dealloc];
}

- (FFGLPlugin *)plugin
{
    return _plugin;
}

- (id)valueForParameterKey:(NSString *)key
{
    // TODO: or maybe subclasses override it.
}

- (void)setValue:(id)value forParameterKey:(NSString *)key
{
    // TODO: or maybe subclasses override it.
}

- (void)renderAtTime:(NSTimeInterval)time
{
    // Do nothing, subclasses override this. 
}
@end
