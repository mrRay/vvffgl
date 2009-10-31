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

static void FFGLGPURendererTextureReleaseCallback(GLuint name, CGLContextObj cgl_ctx, void *context) {
//  NSLog(@"delete texture %u in renderer callback (created)", name);
    CGLLockContext(cgl_ctx);
    glDeleteTextures(1, &name);
    CGLUnlockContext(cgl_ctx);
}

@implementation FFGLGPURenderer

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithPlugin:(FFGLPlugin *)plugin context:(CGLContextObj)context pixelFormat:(NSString *)format forBounds:(NSRect)bounds
{
    if (self = [super initWithPlugin:plugin context:context pixelFormat:format forBounds:bounds]) {
        
        // this rightnow is totally dependant on how we end up exposing the instantiate functions for the plugin, 
        // but we will need something like this somewhere. Feel free to fiddle :)
	
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
        _textureWidth = FFGLPOTDimension(bounds.size.width);
        _textureHeight = FFGLPOTDimension(bounds.size.height);
      
	CGLContextObj cgl_ctx = context;
        CGLLockContext(cgl_ctx);
        
        // state vars
        GLint _previousFBO;		
        GLint _previousRenderBuffer;
        GLint _previousReadFBO;	
        GLint _previousDrawFBO;
        
        glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &_previousFBO);
        glGetIntegerv(GL_RENDERBUFFER_BINDING_EXT, &_previousRenderBuffer);
        glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &_previousReadFBO);
        glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &_previousDrawFBO);
        
        // our temporary texture attachment
        GLuint _rendererFBOTexture;
        glEnable(GL_TEXTURE_2D);
        glGenTextures(1, &_rendererFBOTexture);	
        glBindTexture(GL_TEXTURE_2D, _rendererFBOTexture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, _textureWidth, _textureHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
                        
        // our depth buffer (NO MSAA)
        glGenRenderbuffersEXT(1, &_rendererDepthBuffer);
		glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, _rendererDepthBuffer);
		glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT, _textureWidth, _textureHeight);		
        
        // our FBO
        glGenFramebuffersEXT(1, &_rendererFBO);
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _rendererFBO);

        // set attachments
        glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, _rendererFBOTexture, 0);
        glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT, GL_RENDERBUFFER_EXT, _rendererDepthBuffer);

        GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
        if(status != GL_FRAMEBUFFER_COMPLETE_EXT)
        {	
			// return FBO state
			glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);
			glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, _previousRenderBuffer);
			glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, _previousReadFBO);
			glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, _previousDrawFBO);
			
			// cleanup GL resources
			glDeleteFramebuffersEXT(1, &_rendererFBO);
			glDeleteRenderbuffersEXT(1, &_rendererDepthBuffer);
			glDeleteTextures(1, &_rendererFBOTexture);
			
			CGLUnlockContext(cgl_ctx);
			NSLog(@"Cannot create FBO for FFGLGPURenderer: %u", status);
			
			[self release];
			return nil;
        }	

        _frameStruct.hostFBO = _rendererFBO;

        // return FBO state
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);
        glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, _previousRenderBuffer);
        glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, _previousReadFBO);
        glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, _previousDrawFBO);
        
        // delete our temporary texture 
        glDeleteTextures(1, &_rendererFBOTexture);
	glDisable(GL_TEXTURE_2D);
		
        CGLUnlockContext(cgl_ctx);
		
		// if all of that worked, we now set our preferred FFGL image type.
	_requestedFFGLImageType = GL_TEXTURE_2D;
		
    }
    return self;
}

- (void)nonGCCleanup
{
    CGLContextObj cgl_ctx = _context;
    CGLLockContext(cgl_ctx);
    
    glDeleteFramebuffersEXT(1, &_rendererFBO);
    glDeleteRenderbuffersEXT(1, &_rendererDepthBuffer);
	
    CGLUnlockContext(cgl_ctx);
    if (_frameStruct.inputTextures != NULL) {
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

- (BOOL)_implementationSetImage:(FFGLImage *)image forInputAtIndex:(NSUInteger)index
{
    if ([image lockTexture2DRepresentation]) {
        _frameStruct.inputTextures[index] = [image _texture2DInfo];
        return YES;
    } else {
        return NO;
    }
}

// we may want to optionally ask the FFGLGPURenderer to let us output rect textures and save a conversion stage.
- (BOOL)_implementationRender
{
    CGLContextObj cgl_ctx = _context;
    CGLLockContext(cgl_ctx);
	
    // TODO: need to set output, bind FBO so we render in output's texture, register FBO in _frameStruct, then do this:	
	// - vade: we will be using our _renderFBO texture associated with our FFGLGPURenderer
    
	// state vars
	GLint _previousFBO;	
	GLint _previousRenderBuffer;	// probably dont need this each frame, only during init? hrm.
	GLint _previousReadFBO;	
	GLint _previousDrawFBO;
	
	glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &_previousFBO);
	glGetIntegerv(GL_RENDERBUFFER_BINDING_EXT, &_previousRenderBuffer);
	glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &_previousReadFBO);
	glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &_previousDrawFBO);
	
	// save our current GL state - 
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	
	// create a new texture for this frame
	GLuint _rendererFBOTexture;
	
	// this texture is going to depend on whether or not we have a 2D or RECT texture.
	glEnable(_requestedFFGLImageType);
	
	glGenTextures(1, &_rendererFBOTexture);	
	glBindTexture(_requestedFFGLImageType, _rendererFBOTexture);

//	NSLog(@"new implementationRender texture: %u", _rendererFBOTexture);
	// TODO: looks like _textureWidth/_textureHeight can be set when requestedFFGLImageType is set and the following collapsed to one line
	if(_requestedFFGLImageType == GL_TEXTURE_2D)
	{
//		NSLog(@"requesting 2D FFGL");
		glTexImage2D(_requestedFFGLImageType, 0, GL_RGBA8, _textureWidth, _textureHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

	}
	else if(_requestedFFGLImageType == GL_TEXTURE_RECTANGLE_ARB)
	{
//		NSLog(@"requesting RECT FFGL");
		glTexImage2D(_requestedFFGLImageType, 0, GL_RGBA8, _bounds.size.width, _bounds.size.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	}
	else
		return NO;
	
	// texture filtering and wrapping modes. Do we actually want to fuck with this here? Hrm.
	glTexParameteri(_requestedFFGLImageType, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(_requestedFFGLImageType, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(_requestedFFGLImageType, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
	glTexParameteri(_requestedFFGLImageType, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
		
	
	// bind our FBO
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _rendererFBO);
	
	// attach our new texture
	glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, _requestedFFGLImageType, _rendererFBOTexture, 0);
	
	// this was our fix. Disable texturing and now FFGL renders. 
	glBindTexture(_requestedFFGLImageType, 0);
	glDisable(_requestedFFGLImageType);
	
	// set up viewport/projection matrices and coordinate system for FBO target.
    // Not sure if we want our own dimensions or _textureWidth, _textureHeight here?
    // Guessing this is right with our dimensions.
	glViewport(_bounds.origin.x, _bounds.origin.y, _bounds.size.width, _bounds.size.height);
	
	GLint matrixMode;
	glGetIntegerv(GL_MATRIX_MODE, &matrixMode);
	
	glMatrixMode(GL_TEXTURE);
	glLoadIdentity();
	glPushMatrix();
	
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
		
	// dont fucking change the ortho view, AT FUCKING ALL. Duh.
	//glOrtho(0.0, self.bounds.size.width,  0.0,  self.bounds.size.height, -1, 1);		
	//glOrtho(0.0, 1.0, 0.0, 1.0, 1, -1);
	//glOrtho(self.bounds.origin.x, self.bounds.size.width,  self.bounds.origin.y,  self.bounds.size.height, -1, 1);		
	
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();
		
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
	// render our plugin to our FBO
	BOOL result = [_plugin _processFrameGL:&_frameStruct forInstance:_instance];
	
	//BOOL result = YES;
	
	// Restore OpenGL states 
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	glMatrixMode(GL_TEXTURE);
	glPopMatrix();

	glMatrixMode(matrixMode);
	
	// restore states // assume this is balanced with above 
	glPopAttrib();
	glFlushRenderAPPLE();

	// return FBO state
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);
	glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, _previousRenderBuffer);
	glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, _previousReadFBO);
	glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, _previousDrawFBO);
		
	
//	NSLog(@"new FFGL image with texture: %u", _rendererFBOTexture);
	
	FFGLImage *output;
	
	if(_requestedFFGLImageType == GL_TEXTURE_2D)
	{
		output = [[[FFGLImage alloc] initWithTexture2D:_rendererFBOTexture
						    CGLContext:cgl_ctx
					       imagePixelsWide:_bounds.size.width
					       imagePixelsHigh:_bounds.size.height
					     texturePixelsWide:_textureWidth
					     texturePixelsHigh:_textureHeight
					       releaseCallback:FFGLGPURendererTextureReleaseCallback
						   releaseInfo:NULL] autorelease];
	}
	else if(_requestedFFGLImageType == GL_TEXTURE_RECTANGLE_ARB)
	{
		output = [[[FFGLImage alloc] initWithTextureRect:_rendererFBOTexture
						      CGLContext:cgl_ctx 
						      pixelsWide:_bounds.size.width
						      pixelsHigh:_bounds.size.height
						 releaseCallback:FFGLGPURendererTextureReleaseCallback
						     releaseInfo:NULL] autorelease];
		
	}

    CGLUnlockContext(cgl_ctx);
    
    [self setOutputImage:output];
     
    return result;
}

// if we switch COLOR ATTACHMENT target types we switch widths, 
// thus, we must rebuild our render buffer attachment too, 
// but we only need to do this once, ever, per target type change.
- (void) setRequestedFFGLImageType:(GLenum)target
{
	if(_requestedFFGLImageType != target && (_context != NULL))
	{
		// respect KVO
		[self willChangeValueForKey:@"requestedFFGLImageType"];

		_requestedFFGLImageType = target;
		
		CGLContextObj cgl_ctx = _context;
		CGLLockContext(cgl_ctx);
		
		// state vars
		GLint _previousFBO;	
		GLint _previousRenderBuffer;	// probably dont need this each frame, only during init? hrm.
		GLint _previousReadFBO;	
		GLint _previousDrawFBO;
		
		glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &_previousFBO);
		glGetIntegerv(GL_RENDERBUFFER_BINDING_EXT, &_previousRenderBuffer);
		glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &_previousReadFBO);
		glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &_previousDrawFBO);
		
		// delete our current rendererDepthBuffer
		glDeleteRenderbuffersEXT(1, &_rendererDepthBuffer);
		
		// new
		glGenRenderbuffersEXT(1, &_rendererDepthBuffer);
		glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, _rendererDepthBuffer);
		
		if(_requestedFFGLImageType == GL_TEXTURE_2D)
			glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT, _textureWidth, _textureHeight);		
		if(_requestedFFGLImageType == GL_TEXTURE_RECTANGLE_ARB)
			glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT, _bounds.size.width, _bounds.size.height);		
		
		// bind our FBO
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _rendererFBO);
		
		// set our new renderbuffer depth attachment
		glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT, GL_RENDERBUFFER_EXT, _rendererDepthBuffer);
		
		// return FBO state
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);
		glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, _previousRenderBuffer);
		glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, _previousReadFBO);
		glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, _previousDrawFBO);		
		
		CGLUnlockContext(cgl_ctx);
		
		[self didChangeValueForKey:@"requestedFFGLImageType"];
	}
}

@end
