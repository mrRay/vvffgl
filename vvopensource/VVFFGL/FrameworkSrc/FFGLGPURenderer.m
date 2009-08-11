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
		
		// retain GL context
		_context = cgl_ctx;
		CGLRetainContext(_context);
		
		// make the rect to 2D texture FBO.
		CGLLockContext(cgl_ctx);
		
		glGenTextures(1, &_squareFBOTexture);
		glBindTexture(GL_TEXTURE_2D, _squareFBOTexture);
		
		// NOTE: we need to get the size in from the input image. So, we may end making temp textures rather than keeping one around.
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, bounds.size.width, bounds.size.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
		
		// cache previous FBO.
		glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &_previousFBO);
		
		// Create temporary FBO to render in texture 
		glGenFramebuffersEXT(1, &_rectToSquareFBO);
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _rectToSquareFBO);
		glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, _squareFBOTexture, 0);
		
		GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
		if(status != GL_FRAMEBUFFER_COMPLETE_EXT)
		{	
			glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);
			glDeleteFramebuffersEXT(1, &_rectToSquareFBO);
			glDeleteTextures(1, &_squareFBOTexture);
			
			CGLUnlockContext(cgl_ctx);
			NSLog(@"Cannot create FFGL FBO");
			return nil;
		}	
		
		// looks like everything worked... cleanup!
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);
		CGLUnlockContext(cgl_ctx);
    }
    return self;
}

- (void)dealloc
{
    [[self plugin] deinstantiateGL];
    if (_data != NULL)
        free(_data);
    [super dealloc];
}

- (void)renderAtTime:(NSTimeInterval)time
{
    // TODO: 
}

@end
