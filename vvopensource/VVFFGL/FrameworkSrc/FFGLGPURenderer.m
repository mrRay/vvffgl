//
//  FFGLGPURenderer.m
//  VVOpenSource
//
//  Created by Tom on 10/08/2009.
//

#import "FFGLGPURenderer.h"
#import "FFGLPluginInstances.h"
#import "FFGLRendererSubclassing.h"

#import <OpenGL/CGLMacro.h>

struct FFGLGPURendererData {
    NSUInteger instanceIdentifier;
    NSRect viewport;
    VideoInfoStruct videoInfo;
    FFGLProcessGLStruct frameStruct;
};

@implementation FFGLGPURenderer
- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

// do we want the framework users to have to pass in FFGL viewport structs? Maybe, maybe not?
// I say not - let's be completely opaque and expose none of the underlying FFGL stuff.
- (id)initWithPlugin:(FFGLPlugin *)plugin context:(CGLContextObj)cgl_ctx bounds:(NSRect)bounds;
{
    if (self = [super initWithPlugin:plugin context:cgl_ctx forBounds:bounds]) {        
        _data = malloc(sizeof(struct FFGLGPURendererData));
        if (_data == NULL) {
            [self release];
            return nil;
        }
        
        _data->viewport.origin.x = bounds.origin.x;
        _data->viewport.origin.y = bounds.origin.y;
        _data->viewport.size.width = bounds.size.width;
        _data->viewport.size.height = bounds.size.height;
        
        // this rightnow is totally dependant on how we end up exposing the instantiate functions for the plugin, 
        // but we will need something like this somewhere. Feel free to fiddle :)

        // TODO: set up our ProcessOpenGLStruct struct.
		
		// retain GL context
		_context = cgl_ctx;
		CGLRetainContext(_context);
		
		// make the rect to 2D texture FBO.
		CGLLockContext(cgl_ctx);
		
		glGenTextures(1, &_squareFBOTexture);
		glBindTexture(GL_TEXTURE_2D, _squareFBOTexture);
		
		// NOTE: we get the size from our viewport struct. So, we may end making temp textures rather than keeping one around.
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, _data->viewport.size.width, _data->viewport.size.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
		
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
    if (_data != NULL)
        free(_data);
    [super dealloc];
}

- (void)_setImage:(id)image forInputAtIndex:(NSUInteger)index
{
    // Get the texture from the image, then
    // [self _setTexture:ourtexture forInputAtIndex:index];
}

- (void)_setTexture:(GLuint)texture forInputAtIndex:(NSUInteger)index
{
    CGLContextObj cgl_ctx = _context;
	CGLLockContext(cgl_ctx);
	
	GLuint inputSquareTexture = [self rectTextureToSquareTexture:texture withCoords:NSZeroRect]; // some coords.
	
    // TODO: add the texture to the appropriate position in our ProcessOpenGLStruct. Note there can be several inputs...
	
	CGLUnlockContext(cgl_ctx);
}

- (void)_render
{
    // the steps are roughly:
	
	// attach GL context
	// take our input image, render it to a square texture, 
	// pass that square texture to our plugin
	// set the params of the plugin - Only the image params which we load into whatever sort of struct. We'll set the params as soon as setValue: forParameterKey: is called (in FFGLRenderer), not every render pass..
	// render.
	
	
	CGLContextObj cgl_ctx = _context;
	CGLLockContext(cgl_ctx);
		
    [[self plugin] _processFrameGL:frameStruct forInstance:[self _instance]];
	
	CGLUnlockContext(cgl_ctx);
}

- (GLuint) rectTextureToSquareTexture:(GLuint)inputTexture withCoords:(NSRect) rectCoords
{
    // TODO: we can have any number of image inputs, so we need this to be able to handle that
    
	// do we necessarily need to re-cache our previous FBO every frame? 
    // // Have moved that out of rendering, so it only happens when input changes... but you need as many square textures as there are inputs, not neccessarily one.
	// do we even need that iVar at all, should that be handled outside of the framework?

	// also, do we want to/need to generate a new texture attachment every frame? \
	// that may be required for changing input image dimensions

	// we also will probably need to round to the nearest power of two for the texture dimensions and viewport dimensions.
	// argh. JUST. FUCKING. SUPPORT. RECT. TEXTURES. PLEASE.
	
        CGLContextObj cgl_ctx = _context;

	glPushAttrib(GL_COLOR_BUFFER_BIT | GL_TRANSFORM_BIT | GL_VIEWPORT_BIT);
	
	// bind our FBO
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _rectToSquareFBO);
	
	// set the viewport to the size of our input viewport...
	glViewport(0, 0,  _data->viewport.size.width, _data->viewport.size.height);
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	
	glOrtho(0.0, width,  0.0,  height, -1, 1);		
	
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();
	
	// this may not be necessary if we use GL_REPLACE for texturing the entire quad.
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);		
	
	// attach our rect texture and draw it the entire size of the viewport, with the proper rect coords.
	glBegin(GL_QUADS);
	glTexCoord2f(0, 0);
	glVertex2f(0, 0);
	glTexCoord2f(0, rectCoords.size.height);
	glVertex2f(0, _data->viewport.size.height);
	glTexCoord2f(rectCoords.size.width, rectCoords.size.height);
	glVertex2f(_data->viewport.size.width, _data->viewport.size.height);
	glTexCoord2f(rectCoords.size.width, 0);
	glVertex2f(_data->viewport.size.width, 0);
	glEnd();		
		
	// Restore OpenGL states 
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	
	// restore states // assume this is balanced with above 
	glPopAttrib();
	
	// restore previous FBO
	
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);
	
	// we need to flush to make sure FBO Texture attachment is rendered
	
	glFlushRenderAPPLE();
	
	// our input rect texture should now be represented in the returned texture below.
	return _squareFBOTexture;
}


@end
