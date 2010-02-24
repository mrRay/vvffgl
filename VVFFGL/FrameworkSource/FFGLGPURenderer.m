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

#if defined(FFGL_USE_TEXTURE_POOLS)

@interface FFGLGPURenderer (Private)
- (GLenum)textureTarget;
- (NSSize)textureSize;
@end

// to pass to FFGLPool
static const void *FFGLGPURendererTextureCreate(const void *userInfo)
{
    CGLContextObj cgl_ctx = [(FFGLGPURenderer *)userInfo context];
	GLenum target = [(FFGLGPURenderer *)userInfo textureTarget];
	NSSize dimensions = [(FFGLGPURenderer *)userInfo textureSize];
    // This is only ever called (by FFGLPoolObjectCreate())
    // in _implementationRender. GL context and state are
    // already set up.
	GLuint *tex = malloc(sizeof(GLuint));
    glGenTextures(1, tex);
	glBindTexture(target, *tex);
	glTexImage2D(target, 0, GL_RGBA8, dimensions.width, dimensions.height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, NULL);
    return tex;
}

// to pass to FFGLPool
static void FFGLGPURendererTextureDelete(const void *item, const void *userInfo)
{
	// This is only going to be called in an FFGLImage callback or when we are released, at which
	// time the context is locked.
    CGLContextObj cgl_ctx = [(FFGLGPURenderer *)userInfo context];
    glDeleteTextures(1, (GLuint *)item);
	free((void *)item);
}

// to pass to FFGLImage
static void FFGLGPURendererPoolObjectRelease(GLuint name, CGLContextObj cgl_ctx, void *object)
{
	FFGLPoolObjectRelease(object);
}

#else /* FFGL_USE_TEXTURE_POOLS is not defined */

// to pass to FFGLImage
static void FFGLGPURendererTextureDelete(GLuint name, CGLContextObj cgl_ctx, void *object)
{
    glDeleteTextures(1, &name);
}

#endif /* FFGL_USE_TEXTURE_POOLS */

static BOOL FFGLGPURendererSetupFBO(CGLContextObj cgl_ctx, GLenum textureTarget, GLuint textureWidth, GLuint textureHeight, GLuint *fbo, GLuint *depthBuffer)
{	
	// state vars
	GLint previousFBO;
	GLint previousRenderBuffer;
	GLint previousReadFBO;	
	GLint previousDrawFBO;
	
	// Save FBO state
	glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &previousFBO);
	glGetIntegerv(GL_RENDERBUFFER_BINDING_EXT, &previousRenderBuffer);
	glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &previousReadFBO);
	glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &previousDrawFBO);
	
	glPushAttrib(GL_ENABLE_BIT | GL_TEXTURE_BIT);
	// our temporary texture attachment
	GLuint rendererFBOTexture;
	glEnable(textureTarget);
	glGenTextures(1, &rendererFBOTexture);
	
	glBindTexture(textureTarget, rendererFBOTexture);
	glTexImage2D(textureTarget, 0, GL_RGBA8, textureWidth, textureHeight, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, NULL);
	
	// texture filtering and wrapping modes for FBO texture.
	
	// Set these now because FBO-creation fails on some older ATI cards with non-clamped NPOT textures
	glTexParameteri(textureTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(textureTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(textureTarget, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(textureTarget, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(textureTarget, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);

	// Some plugins require a depth buffer
	glGenRenderbuffersEXT(1, depthBuffer);
	glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, *depthBuffer);
	glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT, textureWidth, textureHeight);		
	
	// bind our FBO
	glGenFramebuffersEXT(1, fbo);
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, *fbo);
	
	// set our new renderbuffer depth attachment
	glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, textureTarget, rendererFBOTexture, 0);
	glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT, GL_RENDERBUFFER_EXT, *depthBuffer);
	
	GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
	
	// return FBO state
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, previousFBO);
	glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, previousRenderBuffer);
	glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, previousReadFBO);
	glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, previousDrawFBO);
	
	// delete our temporary texture 
	glDeleteTextures(1, &rendererFBOTexture);
	
	BOOL result;
	
	if(status != GL_FRAMEBUFFER_COMPLETE_EXT)
	{	
	    // cleanup GL resources
	    glDeleteFramebuffersEXT(1, fbo);
	    glDeleteRenderbuffersEXT(1, depthBuffer);
		result = NO;
//	    NSLog(@"Cannot create FBO for FFGLGPURenderer: %u", status);
	}
	else
	{
		result = YES;
	}

	glPopAttrib();
		
	return result;
}

@implementation FFGLGPURenderer

- (id)initWithPlugin:(FFGLPlugin *)plugin context:(CGLContextObj)context pixelFormat:(NSString *)format outputHint:(FFGLRendererHint)hint size:(NSSize)size
{
    if (self = [super initWithPlugin:plugin context:context pixelFormat:format outputHint:hint size:size]) {
		
        // set up our _frameStruct
        NSUInteger numInputs = [plugin _maximumInputFrameCount];
        _frameStruct.inputTextureCount = numInputs;
        if (numInputs > 0)
		{
            _frameStruct.inputTextures = malloc(sizeof(void *) * numInputs);
            if (_frameStruct.inputTextures == NULL)
			{
                [self release];
                return nil;
            }
			for (int i = 0; i < numInputs; i++) {
				_frameStruct.inputTextures[i] = NULL;
			}
        } else
		{
            _frameStruct.inputTextures = NULL;
        }
		
#if defined(FFGL_USE_TEXTURE_POOLS)
		// set up our texture pool
		FFGLPoolCallBacks callbacks = {FFGLGPURendererTextureCreate, FFGLGPURendererTextureDelete};
		_pool = FFGLPoolCreate(&callbacks, 3, self);
		if (_pool == NULL)
		{
			[self release];
			return nil;
		}
#endif /* FFGL_USE_TEXTURE_POOLS */
		
		// Lock now in case we call ffglOpenGLSupportsExtension and for FFGLGPURendererSetupFBO soon
		CGLLockContext(context);
		
		if (_outputHint == FFGLRendererHintTextureRect)
		{
			_textureTarget = GL_TEXTURE_RECTANGLE_ARB;
			_textureWidth = _size.width;
			_textureHeight = _size.height;
		}
		else
		{
			_textureTarget = GL_TEXTURE_2D;
#if defined(FFGL_ALLOW_NPOT_2D)
			// In 10.5 some GPUs don't support non-power-of-two textures
			if (ffglOpenGLSupportsExtension(context, "GL_ARB_texture_non_power_of_two"))
			{
				_textureWidth = _size.width;
				_textureHeight = _size.height;
			}
			else
			{
				_textureWidth = ffglPOTDimension(_size.width);
				_textureHeight = ffglPOTDimension(_size.height);
			}
#else
			_textureWidth = ffglPOTDimension(_size.width);
			_textureHeight = ffglPOTDimension(_size.height);
#endif /* FFGL_ALLOW_NPOT_2D */
		}
		
		BOOL success = FFGLGPURendererSetupFBO(context, _textureTarget, _textureWidth, _textureHeight, &_rendererFBO, &_rendererDepthBuffer);
		
		// Unlock context
		CGLUnlockContext(context);
		
        if(!success)
        {	
			[self release];
			return nil;
        }	
		
		_frameStruct.hostFBO = _rendererFBO;
		
		
    }
    return self;
}

- (void)nonGCCleanup
{
	CGLContextObj prevContext;
	CGLContextObj cgl_ctx = _context;
	
	ffglSetContext(cgl_ctx, prevContext);
	
	CGLLockContext(cgl_ctx);

#if defined(FFGL_USE_TEXTURE_POOLS)
    FFGLPoolRelease(_pool);
#endif
	    
    glDeleteFramebuffersEXT(1, &_rendererFBO);
    glDeleteRenderbuffersEXT(1, &_rendererDepthBuffer);
	
    CGLUnlockContext(cgl_ctx);
	
	ffglRestoreContext(cgl_ctx, prevContext);
    
	free(_frameStruct.inputTextures);
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

#if defined(FFGL_USE_TEXTURE_POOLS)

- (GLenum)textureTarget
{
	return _textureTarget;
}

- (NSSize)textureSize
{
	return NSMakeSize(_textureWidth, _textureHeight);
}
#endif
- (BOOL)_implementationReplaceImage:(FFGLImage *)prevImage withImage:(FFGLImage *)newImage forInputAtIndex:(NSUInteger)index
{
    return YES;
}

- (void)_implementationSetImageInputCount:(NSUInteger)count
{
    _frameStruct.inputTextureCount = count;
}

- (FFGLImage *)_implementationCreateOutput
{
    CGLContextObj cgl_ctx = _context;
	CGLContextObj prevContext;
	
	ffglSetContext(cgl_ctx, prevContext);
    CGLLockContext(cgl_ctx);
	
	BOOL result = YES;
	FFGLImage *output = nil;
	
	for (int i = 0; i < _frameStruct.inputTextureCount; i++) {
		if ([_inputs[i] lockTexture2DRepresentation])
		{
			_frameStruct.inputTextures[i] = [_inputs[i] _texture2DInfo];
		}
		else
		{
			_frameStruct.inputTextures[i] = NULL;
			result = NO;
		}
	}
	
	if (result == YES)
	{
		// state vars
		GLint previousFBO;	
		GLint previousRenderBuffer;	// probably dont need this each frame, only during init? hrm.
		GLint previousReadFBO;	
		GLint previousDrawFBO;
		
		glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &previousFBO);
		glGetIntegerv(GL_RENDERBUFFER_BINDING_EXT, &previousRenderBuffer);
		glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &previousReadFBO);
		glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &previousDrawFBO);
		
		// save our current GL state - 
		glPushAttrib(GL_ALL_ATTRIB_BITS);
			
		// this texture is going to depend on whether or not we have a 2D or RECT texture.
		glEnable(_textureTarget);
		
		// create a new texture for this frame
	#if defined(FFGL_USE_TEXTURE_POOLS)
		FFGLPoolObjectRef obj = FFGLPoolObjectCreate(_pool);
		GLuint rendererFBOTexture = *((GLuint *)FFGLPoolObjectGetData(obj));
		glBindTexture(_textureTarget, rendererFBOTexture);
	#else
		GLuint rendererFBOTexture;
		glGenTextures(1, &rendererFBOTexture);
		glBindTexture(_textureTarget, rendererFBOTexture);
		//	NSLog(@"new implementationRender texture: %u", _rendererFBOTexture);
		glTexImage2D(_textureTarget, 0, GL_RGBA8, _textureWidth, _textureHeight, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, NULL);
	#endif
		
		// texture filtering and wrapping modes. Do we actually want to fuck with this here? Hrm.
		glTexParameteri(_textureTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(_textureTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(_textureTarget, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(_textureTarget, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(_textureTarget, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
		
		// bind our FBO
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _rendererFBO);
		
		// attach our new texture
		glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, _textureTarget, rendererFBOTexture, 0);
		
		// disable texturing
		glBindTexture(_textureTarget, 0);
		glDisable(_textureTarget);
		
		// set up viewport/projection matrices and coordinate system for FBO target.
		glViewport(0, 0, _size.width, _size.height);
		
		GLint matrixMode;
		glGetIntegerv(GL_MATRIX_MODE, &matrixMode);
		
		glMatrixMode(GL_TEXTURE);
		glLoadIdentity();
		glPushMatrix();
		
		glMatrixMode(GL_PROJECTION);
		glPushMatrix();
		glLoadIdentity();
		
		glMatrixMode(GL_MODELVIEW);
		glPushMatrix();
		glLoadIdentity();
		
		glActiveTexture(GL_TEXTURE0);

		// Some plugins get very upset if we don't do a glClear before rendering
		glClearColor(0.0, 0.0, 0.0, 0.0);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
			
	//	glActiveTexture(GL_TEXTURE0);
	//	glEnable(GL_TEXTURE_2D);
		
		// render our plugin to our FBO
		result = [_plugin _processFrameGL:&_frameStruct forInstance:_instance];
		
		if (result == NO)
		{
	#if defined(FFGL_USE_TEXTURE_POOLS)
			FFGLPoolObjectRelease(obj);
	#else
			glDeleteTextures(1, &rendererFBOTexture);
	#endif
		}
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
		
		// this fixes apparent render issues with Bendoscope (and friends) during software fallback (?)
		// If a plugin uses GL_TEXTURE_2D on some hardware with GL_REPEAT wrapping mode, fallback happens.
		// This forces proper texture synchronization with the hardware (since this may happen on the CPU.)
		glFlush();	
		//glFlushRenderAPPLE(); // only will work if we remain on the GPU.
		
		// return FBO state
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, previousFBO);
		glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, previousRenderBuffer);
		glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, previousReadFBO);
		glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, previousDrawFBO);
				
		if (result == YES)
		{
			//	NSLog(@"new FFGL image with texture: %u", _rendererFBOTexture);
	#if defined(FFGL_USE_TEXTURE_POOLS)
			
			FFGLImageTextureReleaseCallback callback = FFGLGPURendererPoolObjectRelease;
			void *info = obj;
	#else
			
			FFGLImageTextureReleaseCallback callback = FFGLGPURendererTextureDelete;
			void *info = NULL;
	#endif
			if(_textureTarget == GL_TEXTURE_2D)
			{
				output = [[FFGLImage alloc] initWithTexture2D:rendererFBOTexture
												   CGLContext:cgl_ctx
											  imagePixelsWide:_size.width
											  imagePixelsHigh:_size.height
											texturePixelsWide:_textureWidth
											texturePixelsHigh:_textureHeight
													  flipped:NO
											  releaseCallback:callback
												  releaseInfo:info];
			}
			else if(_textureTarget == GL_TEXTURE_RECTANGLE_ARB)
			{
				output = [[FFGLImage alloc] initWithTextureRect:rendererFBOTexture
													 CGLContext:cgl_ctx 
													 pixelsWide:_size.width
													 pixelsHigh:_size.height
														flipped:NO
												releaseCallback:callback
													releaseInfo:info];
			}
		}
	}
	
	CGLUnlockContext(cgl_ctx);
	ffglRestoreContext(cgl_ctx, prevContext);
	
	for (int i = 0; i < _frameStruct.inputTextureCount; i++) {
		if (_frameStruct.inputTextures[i] != NULL)
		{
			[_inputs[i] unlockTexture2DRepresentation];
		}
	}
	
    return output;
}

@end
