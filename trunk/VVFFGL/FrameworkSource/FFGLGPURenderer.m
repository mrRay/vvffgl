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

// to pass to FFGLPool
static const void *FFGLGPURendererTextureCreate(const void *userInfo)
{
    CGLContextObj cgl_ctx = (CGLContextObj)userInfo;
    // This is only ever called (by FFGLPoolObjectCreate())
    // in _implementationRender. GL context and state are
    // already set up.
    GLuint *texturePtr = malloc(sizeof(GLuint));
    glGenTextures(1, texturePtr);
    return texturePtr;
}

// to pass to FFGLPool
static void FFGLGPURendererTextureDelete(const void *item, const void *userInfo)
{
    CGLContextObj cgl_ctx = (CGLContextObj)userInfo;
    GLuint *name = (GLuint*)item;
    CGLLockContext(cgl_ctx);
    glDeleteTextures(1, name);
    CGLUnlockContext(cgl_ctx);
    free(name);
}

// to pass to FFGLImage
static void FFGLGPURendererPoolObjectRelease(GLuint name, CGLContextObj cgl_ctx, void *object)
{
	FFGLPoolObjectRelease(object);
}

#else /* FFGL_USE_TEXTURE_POOLS is not defined */

static void FFGLGPURendererTextureDelete(GLuint name, CGLContextObj cgl_ctx, void *object)
{
    CGLLockContext(cgl_ctx);
    glDeleteTextures(1, &name);
    CGLUnlockContext(cgl_ctx);
}

#endif /* FFGL_USE_TEXTURE_POOLS */

static BOOL FFGLGPURendererSetupFBO(CGLContextObj cgl_ctx, GLenum textureTarget, GLuint textureWidth, GLuint textureHeight, GLuint *fbo, GLuint *depthBuffer)
{
	CGLLockContext(cgl_ctx);
	
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
	// TODO: here we are unbinding any previously bound texture. we need to push/pop attributes to catch that,
	// or do it once we have bound our FBO if possible
	glBindTexture(textureTarget, rendererFBOTexture);
	glTexImage2D(textureTarget, 0, GL_RGBA8, textureWidth, textureHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	
	// texture filtering and wrapping modes for FBO texture.
	
	// Set these now because FBO-creation fails on some older ATI cards with non-clamped NPOT textures
	glTexParameteri(textureTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(textureTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(textureTarget, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
	glTexParameteri(textureTarget, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);

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
	    
	    NSLog(@"Cannot create FBO for FFGLGPURenderer: %u", status);
		result = NO;
	}
	else
	{
		result = YES;
	}

	glPopAttrib();
	
	CGLUnlockContext(cgl_ctx);
	
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
        } else
		{
            _frameStruct.inputTextures = NULL;
        }
		
		// set up our texture properties
//		BOOL tryNPOT2D = NO;
		if (_outputHint == FFGLRendererHintTextureRect)
		{
			_textureTarget = GL_TEXTURE_RECTANGLE_ARB;
			_textureWidth = _size.width;
			_textureHeight = _size.height;
		}
		else
		{
			_textureTarget = GL_TEXTURE_2D;
			// In 10.5 some GPUs don't support non-power-of-two textures
			if (ffglOpenGLSupportsExtension(context, "GL_ARB_texture_non_power_of_two"))
			{
				_textureWidth = _size.width;
				_textureHeight = _size.height;
//				tryNPOT2D = YES;
			}
			else
			{
				_textureWidth = ffglPOTDimension(_size.width);
				_textureHeight = ffglPOTDimension(_size.height);
			}
		}
		
#if defined(FFGL_USE_TEXTURE_POOLS)
		// set up our texture pool
		FFGLPoolCallBacks callbacks = {FFGLGPURendererTextureCreate, FFGLGPURendererTextureDelete};
		_pool = FFGLPoolCreate(&callbacks, 3, context);
		if (_pool == NULL)
		{
			[self release];
			return nil;
		}
#endif
		
		BOOL success = FFGLGPURendererSetupFBO(context, _textureTarget, _textureWidth, _textureHeight, &_rendererFBO, &_rendererDepthBuffer);
		/*
		 
		 // The following will go unless any other setups have problems, problem with ATI cards is dealt with
		 // in FFGLGPURendererSetupFBO()
		if (!success && tryNPOT2D)
		{
			NSLog(@"Trying POT fallback");
			// Some older ATI cards report support for GL_ARB_texture_non_power_of_two, but cannot handle NPOT FBOs.
			// Rather than check for those cards, we guess that may have been a problem and try again, with POT dimensions.
			_textureWidth = ffglPOTDimension(_textureWidth);
			_textureHeight = ffglPOTDimension(_textureHeight);
			success = FFGLGPURendererSetupFBO(context, _textureTarget, _textureWidth, _textureHeight, &_rendererFBO, &_rendererDepthBuffer);
		}
		 */
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
#if defined(FFGL_USE_TEXTURE_POOLS)
    FFGLPoolRelease(_pool);
#endif
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

- (void)_implementationSetImageInputCount:(NSUInteger)count
{
    _frameStruct.inputTextureCount = count;
}

- (BOOL)_implementationRender
{
    CGLContextObj cgl_ctx = _context;
    CGLLockContext(cgl_ctx);
	
    // TODO: need to set output, bind FBO so we render in output's texture, register FBO in _frameStruct, then do this:	
	// - vade: we will be using our _renderFBO texture associated with our FFGLGPURenderer
    
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
	GLuint rendererFBOTexture = *(GLuint *)FFGLPoolObjectGetData(obj);
#else
    
	GLuint rendererFBOTexture;
	glGenTextures(1, &rendererFBOTexture);
#endif
	glBindTexture(_textureTarget, rendererFBOTexture);

//	NSLog(@"new implementationRender texture: %u", _rendererFBOTexture);
	glTexImage2D(_textureTarget, 0, GL_RGBA8, _textureWidth, _textureHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	
	// texture filtering and wrapping modes. Do we actually want to fuck with this here? Hrm.
	glTexParameteri(_textureTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(_textureTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(_textureTarget, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
	glTexParameteri(_textureTarget, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
		
	
	// bind our FBO
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _rendererFBO);
	
	// attach our new texture
	glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, _textureTarget, rendererFBOTexture, 0);
	
	// this was our fix. Disable texturing and now FFGL renders. 
	glBindTexture(_textureTarget, 0);
	glDisable(_textureTarget);
	
	// set up viewport/projection matrices and coordinate system for FBO target.
    // Not sure if we want our own dimensions or _textureWidth, _textureHeight here?
    // Guessing this is right with our dimensions.
	glViewport(0, 0, _size.width, _size.height);
	
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
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, previousFBO);
	glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, previousRenderBuffer);
	glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, previousReadFBO);
	glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, previousDrawFBO);
		
	
//	NSLog(@"new FFGL image with texture: %u", _rendererFBOTexture);
	
	FFGLImage *output = nil;
#if defined(FFGL_USE_TEXTURE_POOLS)

	FFGLImageTextureReleaseCallback callback = FFGLGPURendererPoolObjectRelease;
	void *info = obj;
#else
    
	FFGLImageTextureReleaseCallback callback = FFGLGPURendererTextureDelete;
	void *info = NULL;
#endif
	if(_textureTarget == GL_TEXTURE_2D)
	{
		output = [[[FFGLImage alloc] initWithTexture2D:rendererFBOTexture
						    CGLContext:cgl_ctx
					       imagePixelsWide:_size.width
					       imagePixelsHigh:_size.height
					     texturePixelsWide:_textureWidth
					     texturePixelsHigh:_textureHeight
						       flipped:NO
					       releaseCallback:callback
						   releaseInfo:info] autorelease];
	}
	else if(_textureTarget == GL_TEXTURE_RECTANGLE_ARB)
	{
		output = [[[FFGLImage alloc] initWithTextureRect:rendererFBOTexture
						      CGLContext:cgl_ctx 
						      pixelsWide:_size.width
						      pixelsHigh:_size.height
							 flipped:NO
						 releaseCallback:callback
						     releaseInfo:info] autorelease];						
	}

    CGLUnlockContext(cgl_ctx);
    
    [self setOutputImage:output];
     
    return result;
}

@end
