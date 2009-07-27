//
//  VVFFGLRenderer.m
//  VVOpenSource
//
//  Created by Tom on 24/07/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "VVFFGLRenderer.h"
#import "VVFFGLPlugin.h"
#import "VVFFGLPluginInstances.h"

struct VVFFGLRendererData {
    NSUInteger instanceIdentifier;
    FFGLViewportStruct viewport;
    VideoInfoStruct videoInfo;
};

@implementation VVFFGLRenderer

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

// do we want the framework users to have to pass in FFGL viewport structs? Maybe, maybe not?
    // I say not - let's be completely opaque and expose none of the underlying FFGL stuff.
- (id)initWithPlugin:(VVFFGLPlugin *)plugin context(CGLContextObj)cgl_ctx;
{
    if (self = [super init]) {
        _plugin = [plugin retain];
        _pluginContext = cgl_ctx;
        CGLRetainContext(_pluginContext);
        
        _data = malloc(sizeof(VVFFGLRendererData));
        if (_data == NULL) {
            [self release];
            return nil;
        }
        
        // this rightnow is totally dependant on how we end up exposing the instantiate functions for the plugin, 
        // but we will need something like this somewhere. Feel free to fiddle :)
        
        // if plugin is GPU, we have to do specific instantiate functions
        if([plugin mode] == VVFFGLPluginModeGPU)
        {
                // we will need the _pluginViewport / pluginVideoInfo from somewhere.... the manager?
                _data->instanceIdentifier = [_plugin instantiateGL:_data->viewport];
                if(_data->instanceIdentifier == FF_FAIL) 
                {
                        [self release];
                        return nil;
                }
        } else {
                _data->instanceIdentifier = [_plugin instantiate:_data->viewport];
                if(_data->instanceIdentifier == FF_FAIL)
                {
                        [self release];
                        return nil;
                }
        }
	}
	
    return self;
}

- (void)dealloc
{
	// same reasoning as in init
	if([plugin mode] == VVFFGLPluginModeGPU)
	{
		if([_plugin deinstantiateGL] != FF_SUCCESS)
			return nil;
	}		
	else
	{
		if([_plugin deinstantiate] != FF_SUCCESS)
			return nil;
	}

	// need to keep this around so GPU plugins can deinitialize correctly.
	if(_pluginContext != nil)
	{
		CGLReleaseContext(_pluginContext);
	}
	
    [_plugin release];
    [super dealloc];
}

- (VVFFGLPlugin *)plugin
{
    return _plugin;
}

- (id)valueForParameterKey:(NSString *)key
{
    // TODO: 
}

- (void)setValue:(id)value forParameterKey:(NSString *)key
{
    // TODO:     
}

- (void)renderAtTime:(NSTimeInterval)time
{
    // TODO: 
}
@end
