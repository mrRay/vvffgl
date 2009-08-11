//
//  FFGLGPURenderer.m
//  VVOpenSource
//
//  Created by Tom on 10/08/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "FFGLGPURenderer.h"
#import "FFGLPluginInstances.h"
#import "FFGL.h"

struct FFGLGPURendererData {
    NSUInteger instanceIdentifier;
    FFGLViewportStruct viewport;
    VideoInfoStruct videoInfo;
};

@implementation FFGLGPURenderer
- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

// do we want the framework users to have to pass in FFGL viewport structs? Maybe, maybe not?
// I say not - let's be completely opaque and expose none of the underlying FFGL stuff.
- (id)initWithPlugin:(FFGLPlugin *)plugin context:(CGLContextObj)cgl_ctx;
{
    if (self = [super initWithPlugin:plugin context:cgl_ctx]) {        
        _data = malloc(sizeof(struct FFGLGPURendererData));
        if (_data == NULL) {
            [self release];
            return nil;
        }
        
        // this rightnow is totally dependant on how we end up exposing the instantiate functions for the plugin, 
        // but we will need something like this somewhere. Feel free to fiddle :)

        // we will need the _pluginViewport / pluginVideoInfo from somewhere.... the manager?
        _data->instanceIdentifier = [[self plugin] instantiateGL:_data->viewport];
        if(_data->instanceIdentifier == FF_FAIL) 
        {
            [self release];
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    [[self plugin] deinstantiateGL];
    [super dealloc];
}

- (void)renderAtTime:(NSTimeInterval)time
{
    // TODO: 
}

@end
