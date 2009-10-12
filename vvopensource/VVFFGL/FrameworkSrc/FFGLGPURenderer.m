//
//  FFGLGPURenderer.m
//  VVOpenSource
//
//  Created by Tom on 10/08/2009.
//

#import "FFGLGPURenderer.h"
#import "FFGLInternal.h"
#import "FFGLImage.h"
#import <OpenGL/CGLMacro.h>

static void FFGLGPURendererTextureReleaseCallback(GLuint name, void *context) {
    // TODO: destroy the texture we create for our output image
	//	glDeleteTextures(1, &name);
}

@implementation FFGLGPURenderer
- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithPlugin:(FFGLPlugin *)plugin context:(CGLContextObj)cgl_ctx bounds:(NSRect)bounds;
{
    if (self = [super initWithPlugin:plugin context:cgl_ctx forBounds:bounds]) {
        
        // this rightnow is totally dependant on how we end up exposing the instantiate functions for the plugin, 
        // but we will need something like this somewhere. Feel free to fiddle :)
		
		// retain GL context
		_context = cgl_ctx;
		CGLRetainContext(cgl_ctx);
		
        // set up our _frameStruct
        NSUInteger numInputs = [plugin _maximumInputFrameCount];
        _frameStruct.inputTextureCount = numInputs;
        if (numInputs > 0) {
            _frameStruct.inputTextures = malloc(sizeof(void *) * numInputs);
            if (_frameStruct.inputTextures == NULL) {
                [self release];
                return nil;
            }
        } else {
            _frameStruct.inputTextures = NULL;
        }
        // TODO: do we need an FBO to reuse for rendering into our output texture?
		
		CGLLockContext(cgl_ctx);
		
		// state vars
		GLint _previousFBO;		
		GLint _previousReadFBO;	
		GLint _previousDrawFBO;
		
		glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &_previousFBO);
		glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &_previousReadFBO);
		glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &_previousDrawFBO);
		
		// our texture attachment
		glGenTextures(1, &_rendererFBOTexture);	
		glBindTexture(GL_TEXTURE_2D, _rendererFBOTexture);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, bounds.size.width, bounds.size.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

		// our FBO
		glGenFramebuffersEXT(1, &_rendererFBO);
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _rendererFBO);
		glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, _rendererFBOTexture, 0);

		GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
		if(status != GL_FRAMEBUFFER_COMPLETE_EXT)
		{	
			// return FBO state
			glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);
			glBindFramebufferEXT(GL_READ_FRAMEBUFFER_BINDING_EXT, _previousReadFBO);
			glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_BINDING_EXT, _previousDrawFBO);
			
			// cleanup GL resources
			glDeleteFramebuffersEXT(1, &_rendererFBO);
			glDeleteTextures(1, &_rendererFBOTexture);
			
			CGLUnlockContext(cgl_ctx);
			NSLog(@"Cannot create FBO for FFGLGPURenderer");
			
			[self release];
			return nil;
		}	
		
		// return FBO state
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);
		glBindFramebufferEXT(GL_READ_FRAMEBUFFER_BINDING_EXT, _previousReadFBO);
		glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_BINDING_EXT, _previousDrawFBO);
				
		CGLUnlockContext(cgl_ctx);
    }
    return self;
}

- (void)nonGCCleanup
{
    // TODO: if we add an FBO in init, delete it here.
    CGLReleaseContext(_context);
    if (_frameStruct.inputTextures != NULL) {
        NSUInteger i;
        for (i = 0; i < _frameStruct.inputTextureCount; i++) {
            if (_frameStruct.inputTextures[i] != NULL) {
                free(_frameStruct.inputTextures[i]);
            }
        }
        free(_frameStruct.inputTextures);
    }    
}

- (void)dealloc
{
    [self nonGCCleanup];
    [super dealloc];
}

- (void)finalize
{
    [self nonGCCleanup];
    [super finalize];
}

- (void)_implementationSetImage:(FFGLImage *)image forInputAtIndex:(NSUInteger)index
{
    if ([image lockTexture2DRepresentation]) {
        _frameStruct.inputTextures[index] = [image _texture2DInfo];
    }
}

- (BOOL)_implementationRender
{
    CGLContextObj cgl_ctx = _context;
    CGLLockContext(cgl_ctx);
    
    // TODO: need to set output, bind FBO so we render in output's texture, register FBO in _frameStruct, then do this:
//    _frameStruct.hostFBO = whatever; // or if we reuse the same FBO, do this once in init, and not here.
	
	// - vade: we will be using our _renderFBO texture associated with our FFGLGPURenderer
    
	// state vars
	GLint _previousFBO;		
	GLint _previousReadFBO;	
	GLint _previousDrawFBO;
	
	glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &_previousFBO);
	glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &_previousReadFBO);
	glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &_previousDrawFBO);
	
	// save our current GL state - 
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	
	// bind our FBO
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _rendererFBO);
	
	// set up viewport/projection matrices and coordinate system for FBO target.
	GLsizei	width = self.bounds.size.width,	height = self.bounds.size.height;
	
	glViewport(0, 0,  width, height);
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	
	glOrtho(0.0, width,  0.0,  height, -1, 1);		

	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();
	
	// render our plugin to our FBO
	BOOL result = [[self plugin] _processFrameGL:&_frameStruct forInstance:[self _instance]];
	
	// Restore OpenGL states 
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	
	// restore states // assume this is balanced with above 
	glPopAttrib();
	
	// return FBO state
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);
	glBindFramebufferEXT(GL_READ_FRAMEBUFFER_BINDING_EXT, _previousReadFBO);
	glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_BINDING_EXT, _previousDrawFBO);

	glFlushRenderAPPLE();
	
    CGLUnlockContext(cgl_ctx);
    
    FFGLImage *output = [[[FFGLImage alloc] initWithTexture2D:_rendererFBOTexture
											  imagePixelsWide:self.bounds.size.width
											  imagePixelsHigh:self.bounds.size.height
											texturePixelsWide:self.bounds.size.width
											texturePixelsHigh:self.bounds.size.height
											  releaseCallback:FFGLGPURendererTextureReleaseCallback
											   releaseContext:NULL] autorelease];
    [self setOutputImage:output];
     
    return result;
}

@end
