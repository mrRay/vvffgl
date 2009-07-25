//
//  VVFFGLRenderer.m
//  VVOpenSource
//
//  Created by Tom on 24/07/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "VVFFGLRenderer.h"
#import "VVFFGLPlugin.h"

@implementation VVFFGLRenderer

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

// do we want the framework users to have to pass in FFGL viewport structs? Maybe, maybe not?
- (id)initWithPlugin:(VVFFGLPlugin *)plugin context(CGLContextObj)cgl_ctx;
{
    if (self = [super init]) {
        _plugin = [plugin retain];
		
		_pluginContext = cgl_ctx;
		CGLRetainContext(_pluginContext);
		
		// this rightnow is totally dependant on how we end up exposing the instantiate functions for the plugin, 
		// but we will need something like this somewhere. Feel free to fiddle :)
		
		// if plugin is GPU, we have to do specific instantiate functions
		if(isGPU) // placeholder bool
		{
			// we will need the _pluginViewport / pluginVideoInfo from somewhere.... the manager?
			_pluginInstanceIdentifier = [_plugin instantiateGL:_pluginViewport];
			if( _pluginInstanceIdentifier != FF_SUCCESS)
			{
				[self release];
				return nil;
			}
		}		
		else
		{
			_pluginInstanceIdentifier = [_plugin instantiate:_pluginVideoInfo];
			if( _pluginInstanceIdentifier != FF_SUCCESS)
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
	if(isGPU) // placeholder bool to change
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



@end
