//
//  FFGLImage.m
//  VVOpenSource
//
//  Created by Tom on 04/10/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "FFGLImage.h"
#import "FFGLPlugin.h"
#import "FFGLInternal.h"

#import <OpenGL/CGLMacro.h>

// This makes a noticable difference with large images. I'll ditch option at some stage... just here for testing
#define FFGL_USE_TEXTURE_RANGE 1

#pragma mark Private image representation types and storage

typedef NSUInteger FFGLImageRepType;
enum {
    FFGLImageRepTypeTexture2D = 0,
    FFGLImageRepTypeTextureRect = 1,
    FFGLImageRepTypeBuffer = 2
};

// FFGLTextureInfo is in FFGLInternal.h as it's shared with plugins.

typedef struct FFGLBufferInfo {
    unsigned int	width;
    unsigned int    height;
    NSString		*pixelFormat;
    const void		*buffer;
} FFGLBufferInfo;

typedef union FFGLImageRepCallback {
    FFGLImageTextureReleaseCallback	textureCallback;
    FFGLImageBufferReleaseCallback	bufferCallback;
} FFGLImageRepCallback;

typedef union FFGLImageRepInfo {
    FFGLBufferInfo	bufferInfo;
    FFGLTextureInfo	textureInfo;
} FFGLImageRepInfo;

typedef struct FFGLImageRep
{
    FFGLImageRepType		    type;
    BOOL			    flipped;
    FFGLImageRepInfo                repInfo;
    FFGLImageRepCallback	    releaseCallback;
    void			    *releaseContext;
} FFGLImageRep;

#pragma mark Private Callbacks

static void FFGLImageBufferRelease(const void *baseAddress, void* context) {
    free((void *)baseAddress);
}

static void FFGLImageTextureRelease(GLuint name, CGLContextObj cgl_ctx, void *context) {
    CGLLockContext(cgl_ctx);
    glDeleteTextures(1, &name);
    CGLUnlockContext(cgl_ctx);
}

#pragma mark Private Utility

static NSUInteger ffglBytesPerPixelForPixelFormat(NSString *format) {
    if ([format isEqualToString:FFGLPixelFormatRGB565] || [format isEqualToString:FFGLPixelFormatBGR565]) {
        return 2;
    } else if ([format isEqualToString:FFGLPixelFormatRGB888] || [format isEqualToString:FFGLPixelFormatBGR888]) {
        return 3;
    } else if ([format isEqualToString:FFGLPixelFormatARGB8888] || [format isEqualToString:FFGLPixelFormatBGRA8888]) {
        return 4;
    } else {
        return 0;
    }
}

static BOOL ffglGLInfoForPixelFormat(NSString *ffglFormat, GLenum *format, GLenum *type)
{
	/*
	 I can't spot a difference using 5_6_5_REV and 5_6_5, etc. Anyone explain it? T.
	 */
	if ([ffglFormat isEqualToString:FFGLPixelFormatRGB565])
	{
		*format = GL_RGB;
		*type = GL_UNSIGNED_SHORT_5_6_5;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatRGB888])
	{
		*format = GL_RGB;
		*type = GL_UNSIGNED_BYTE;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatARGB8888])
	{ 
		*format = GL_BGRA;
		*type = GL_UNSIGNED_INT_8_8_8_8_REV;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatBGR565])
	{
		*format = GL_RGB;
		*type = GL_UNSIGNED_SHORT_5_6_5;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatBGR888])
	{
		*format = GL_RGB;
		*type = GL_UNSIGNED_BYTE;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatBGRA8888])
	{ 
		*format = GL_BGRA;
		*type = GL_UNSIGNED_INT_8_8_8_8_REV;
	}
	else {
		return NO;
	}
	return YES;
}

static FFGLImageRep *FFGLBufferRepCreateFromTextureRep(CGLContextObj cgl_ctx, const FFGLImageRep *fromTextureRep, NSString *pixelFormat)
{
	GLenum targetGL;
	if (fromTextureRep->type == FFGLImageRepTypeTexture2D)
	{
		targetGL = GL_TEXTURE_2D;

	}
	else if (fromTextureRep->type == FFGLImageRepTypeTextureRect)
	{
		targetGL = GL_TEXTURE_RECTANGLE_ARB;
	}
	else
	{
		return NULL;
	}

	unsigned int w = fromTextureRep->repInfo.textureInfo.width;
	unsigned int h = fromTextureRep->repInfo.textureInfo.height;
	GLenum format, type;
	if (ffglGLInfoForPixelFormat(pixelFormat, &format, &type) == NO)
	{
		return NULL;
	}
	FFGLImageRep *rep = malloc(sizeof(FFGLImageRep));
	if (rep != NULL)
	{
		GLvoid *buffer = valloc(w * h * ffglBytesPerPixelForPixelFormat(pixelFormat));
		if (buffer == NULL)
		{
			free(rep);
			return NULL;
		}

		CGLLockContext(cgl_ctx);
		// Save state, including those things not caught by glPushAttrib()
		glPushAttrib(GL_TEXTURE_BIT | GL_ENABLE_BIT);
		GLint prevRowLength, prevAlignment, prevImageHeight;
		glGetIntegerv(GL_PACK_ALIGNMENT, &prevAlignment);
		glGetIntegerv(GL_PACK_ROW_LENGTH, &prevRowLength);
		glGetIntegerv(GL_PACK_IMAGE_HEIGHT, &prevImageHeight);
		
		glPixelStorei(GL_PACK_ROW_LENGTH, w);
		glPixelStorei(GL_PACK_IMAGE_HEIGHT, h);
		glPixelStorei(GL_PACK_ALIGNMENT, 1);
		glEnable(targetGL);
		glBindTexture(targetGL, fromTextureRep->repInfo.textureInfo.texture);
		glGetTexImage(targetGL, 0, format, type, buffer);
		GLenum error = glGetError();
		
		// Restore state.
		glPixelStorei(GL_UNPACK_ALIGNMENT, prevAlignment);
		glPixelStorei(GL_UNPACK_ROW_LENGTH, prevRowLength);
		glPixelStorei(GL_UNPACK_IMAGE_HEIGHT, prevImageHeight);
		glPopAttrib();
		
		CGLUnlockContext(cgl_ctx);

		if (error != GL_NO_ERROR)
		{
			free(buffer);
			free(rep);
			return NULL;
		}
		
		rep->flipped = fromTextureRep->flipped;
		rep->releaseCallback.bufferCallback = FFGLImageBufferRelease;
		rep->releaseContext = NULL;
		rep->type = FFGLImageRepTypeBuffer;
		rep->repInfo.bufferInfo.buffer = buffer;
		rep->repInfo.bufferInfo.pixelFormat = [pixelFormat retain];
		rep->repInfo.bufferInfo.width = w;
		rep->repInfo.bufferInfo.height = h;
	}
	return rep;
}

static FFGLImageRep *FFGLTextureRepCreateFromBufferRep(CGLContextObj cgl_ctx, const FFGLImageRep *fromBufferRep, FFGLImageRepType toTarget)
{
//	NSLog(@"Buffer->Texture");
	GLenum targetGL;
	unsigned int texWidth, texHeight;
	if (toTarget == FFGLImageRepTypeTexture2D)
	{
		targetGL = GL_TEXTURE_2D;
		/*
		 Some 10.5 systems don't support non-power-of-two 2D textures
		 So we have to create them with POT dimensions.
		 There is a considerable performance hit doing this. We might want to
		 check (once, probably in class initialization) for support for
		 GL_ARB_texture_non_power_of_two and only generate larger textures if
		 we have to.
		 This current way seems a bit weird (GL_UNPACK_ROW_LENGTH & GL_UNPACK_IMAGE_HEIGHT
		 describe an image smaller than our texture)
		 Tom.
		 */
		texWidth = FFGLPOTDimension(fromBufferRep->repInfo.bufferInfo.width);
		texHeight = FFGLPOTDimension(fromBufferRep->repInfo.bufferInfo.height);
	}
	else if (toTarget == FFGLImageRepTypeTextureRect)
	{
		targetGL = GL_TEXTURE_RECTANGLE_ARB;
		texWidth = fromBufferRep->repInfo.bufferInfo.width;
		texHeight = fromBufferRep->repInfo.bufferInfo.height;
	}
	else
	{
		return NULL;
	}
	
	GLenum format;
	GLenum type;
	if (ffglGLInfoForPixelFormat(fromBufferRep->repInfo.bufferInfo.pixelFormat, &format, &type) == NO)
	{
		return NULL;
	}
	FFGLImageRep *rep = malloc(sizeof(FFGLImageRep));
	
	if (rep != NULL)
	{
		rep->flipped = NO;
		rep->releaseCallback.textureCallback = FFGLImageTextureRelease;
		rep->releaseContext = NULL;
		rep->type = toTarget;
		rep->repInfo.textureInfo.width = fromBufferRep->repInfo.bufferInfo.width;
		rep->repInfo.textureInfo.height = fromBufferRep->repInfo.bufferInfo.height;
		rep->repInfo.textureInfo.hardwareWidth = texWidth;
		rep->repInfo.textureInfo.hardwareHeight = texHeight;

		CGLLockContext(cgl_ctx);
		
		// Save state, including those things not caught by glPushAttrib()
		glPushAttrib(GL_TEXTURE_BIT | GL_ENABLE_BIT);
		GLint prevRowLength, prevAlignment, prevImageHeight, prevClientStorage;
		
		glGetIntegerv(GL_UNPACK_ALIGNMENT, &prevAlignment);
		glGetIntegerv(GL_UNPACK_ROW_LENGTH, &prevRowLength);
		glGetIntegerv(GL_UNPACK_IMAGE_HEIGHT, &prevImageHeight);
		glGetIntegerv(GL_UNPACK_CLIENT_STORAGE_APPLE, &prevClientStorage);
		
#if defined(FFGL_USE_TEXTURE_RANGE)
		GLint prevTextureRangeLength;
		GLint prevTextureStorageHint;
		GLvoid *prevTextureRangePointer;
		glGetTexParameteriv(targetGL, GL_TEXTURE_RANGE_LENGTH_APPLE, &prevTextureRangeLength);
		glGetTexParameterPointervAPPLE(targetGL, GL_TEXTURE_RANGE_POINTER_APPLE, &prevTextureRangePointer);
		glGetTexParameteriv(targetGL, GL_TEXTURE_STORAGE_HINT_APPLE, &prevTextureStorageHint);
#endif

		glEnable(targetGL);
		GLuint tex;
		glGenTextures(1, &tex);
		glBindTexture(targetGL, tex);
		glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
		glPixelStorei(GL_UNPACK_ROW_LENGTH, fromBufferRep->repInfo.bufferInfo.width);
		glPixelStorei(GL_UNPACK_IMAGE_HEIGHT, fromBufferRep->repInfo.bufferInfo.height);
		// GL_UNPACK_CLIENT_STORAGE_APPLE tells GL to use our buffer in memory if possible, to avoid a copy to the GPU.
		glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
		
		// Set storage hint GL_STORAGE_SHARED_APPLE to tell GL to share storage with main memory.
#if defined(FFGL_USE_TEXTURE_RANGE)
		glTexParameteri(targetGL, GL_TEXTURE_STORAGE_HINT_APPLE , GL_STORAGE_SHARED_APPLE);
		glTextureRangeAPPLE(targetGL, fromBufferRep->repInfo.bufferInfo.width * fromBufferRep->repInfo.bufferInfo.height, fromBufferRep->repInfo.bufferInfo.buffer);
#endif
		glTexParameteri(targetGL, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(targetGL, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(targetGL, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(targetGL, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

		glTexImage2D(targetGL, 0, GL_RGBA8, rep->repInfo.textureInfo.hardwareWidth, rep->repInfo.textureInfo.hardwareHeight, 0, format, type, fromBufferRep->repInfo.bufferInfo.buffer);

		GLenum error = glGetError();
		// We get the error now but wait until we've popped attributes so our texture is unbound
		// when we delete it.
		
		// restore state.
		glPixelStorei(GL_UNPACK_ALIGNMENT, prevAlignment);
		glPixelStorei(GL_UNPACK_ROW_LENGTH, prevRowLength);
		glPixelStorei(GL_UNPACK_IMAGE_HEIGHT, prevImageHeight);
		glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, prevClientStorage);
#if defined(FFGL_USE_TEXTURE_RANGE)
		glTextureRangeAPPLE(targetGL, prevTextureRangeLength, prevTextureRangePointer);
		glTexParameteri(targetGL, GL_TEXTURE_STORAGE_HINT_APPLE, prevTextureStorageHint);
#endif
		glPopAttrib();
		
		if (error != GL_NO_ERROR)
		{
			glDeleteTextures(1, &tex);
			free(rep);
			rep = NULL;
		}
		else
		{
			rep->repInfo.textureInfo.texture = tex;
		}
		CGLUnlockContext(cgl_ctx);
	}
	return rep;
}

static FFGLImageRep *FFGLTextureRepCreateFromTextureRep(CGLContextObj cgl_ctx, const FFGLImageRep *fromTextureRep, GLenum toTarget)
{
    if (cgl_ctx == NULL
	|| fromTextureRep == NULL
	|| (fromTextureRep->type != FFGLImageRepTypeTexture2D && fromTextureRep->type != FFGLImageRepTypeTextureRect)
	|| fromTextureRep->repInfo.textureInfo.width == 0
	|| fromTextureRep->repInfo.textureInfo.height == 0
	)
    {
	return NULL;
    }
    FFGLImageRep *toTextureRep = malloc(sizeof(FFGLImageRep));
    if (toTextureRep != NULL)
    {
		// direct access to the FFGLTextureInfo and texture target of the source
		const FFGLTextureInfo *fromTexture = &fromTextureRep->repInfo.textureInfo;
		GLenum fromTarget = fromTextureRep->type == FFGLImageRepTypeTexture2D ? GL_TEXTURE_2D : GL_TEXTURE_RECTANGLE_ARB;
		
		// set up our new texture-rep.
		toTextureRep->flipped = NO;
		toTextureRep->releaseCallback.textureCallback = FFGLImageTextureRelease;
		toTextureRep->releaseContext = NULL;
		toTextureRep->type = toTarget == GL_TEXTURE_2D ? FFGLImageRepTypeTexture2D : FFGLImageRepTypeTextureRect;
		
		FFGLTextureInfo *toTexture = &toTextureRep->repInfo.textureInfo;

		// cache FBO state
		GLint previousFBO, previousReadFBO, previousDrawFBO;
		
		// the FBO attachment texture we are going to render to.
				
		GLsizei fboWidth, fboHeight;
		// set up our destination target
		if(toTarget == GL_TEXTURE_2D)
		{
			// Most but not all GPUs support GL_ARB_texture_non_power_of_two - we could check but meh...
			fboWidth = toTexture->hardwareWidth = FFGLPOTDimension(fromTexture->width);
			fboHeight = toTexture->hardwareHeight = FFGLPOTDimension(fromTexture->height);
		} 
		else
		{
			fboWidth = toTexture->hardwareWidth = fromTexture->width;
			fboHeight = toTexture->hardwareHeight = fromTexture->height;
		}
		toTexture->width = fromTexture->width;
		toTexture->height = fromTexture->height;
		
		CGLLockContext(cgl_ctx);
		
		glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &previousFBO);
		glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &previousReadFBO);
		glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &previousDrawFBO);
		
		// save as much state;
		glPushAttrib(GL_ALL_ATTRIB_BITS);
		
		// new texture
		GLuint newTex;
		glGenTextures(1, &newTex);
		
		glEnable(toTarget);
		// here we're binding to previousFBO..? Can't we do it onto our FBO once?
		glBindTexture(toTarget, newTex);
		glTexImage2D(toTarget, 0, GL_RGBA8, fboWidth, fboHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

		// texture filtering and wrapping modes for FBO texture.
		glTexParameteri(toTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(toTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(toTarget, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
		glTexParameteri(toTarget, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
		
	//	NSLog(@"new texture: %u, original texture: %u", newTex, fromTexture->texture);
		toTexture->texture = newTex;

		// make new FBO and attach.
		GLuint fboID;
		glGenFramebuffersEXT(1, &fboID);
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, fboID);
		glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, toTarget, newTex, 0);

		// unbind texture
		glBindTexture(toTarget, 0);
		glDisable(toTarget);

		GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
		if(status != GL_FRAMEBUFFER_COMPLETE_EXT)
		{
			glDeleteTextures(1, &newTex);
			free(toTextureRep);
			toTextureRep = NULL;
			NSLog(@"Cannot create FBO for swapTextureTarget: %u", status);
		}
		else // FBO creation worked, carry on
		{	
			glViewport(0, 0, fboWidth, fboHeight);
			glMatrixMode(GL_PROJECTION);
			glPushMatrix();
			glLoadIdentity();
			
			// weirdo ortho
			glOrtho(0.0, fboWidth, 0.0, fboHeight, -1, 1);		
			
			glMatrixMode(GL_MODELVIEW);
			glPushMatrix();
			glLoadIdentity();
			
			// draw the texture.
			
			glClearColor(0,0,0,0);
			glClear(GL_COLOR_BUFFER_BIT);
			
			glActiveTexture(GL_TEXTURE0);
			glEnable(fromTarget);
			glBindTexture(fromTarget, fromTexture->texture);
			
			if(fromTarget == GL_TEXTURE_RECTANGLE_ARB || fromTarget == GL_TEXTURE_2D)
			{	
				glTexParameteri(fromTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
				glTexParameteri(fromTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
				glTexParameteri(fromTarget, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
				glTexParameteri(fromTarget, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);				
			
				// since our image is NPOT but our texture is POT, we must 
				// deduce proper texture coords in normalized space
				
				GLfloat texImageWidth, texImageHeight;

				texImageWidth = fromTarget == GL_TEXTURE_2D ? (GLfloat) fromTexture->width / (GLfloat)fromTexture->hardwareWidth : fromTexture->width;
				texImageHeight = fromTarget == GL_TEXTURE_2D ? (GLfloat)fromTexture->height / (GLfloat)fromTexture->hardwareHeight : fromTexture->height;
				GLfloat fboImageWidth, fboImageHeight;
				fboImageWidth = toTexture->width;
				fboImageHeight = toTexture->height;
//				NSLog(@"%@ -> %@ flipped: %@ texWidth: %f texHeight: %f fboImageWidth: %d fboImageHeight: %d", fromTarget == GL_TEXTURE_2D ? @"2D" : @"Rect", toTarget == GL_TEXTURE_2D ? @"2D" : @"Rect", fromTextureRep->flipped ? @"YES" : @"NO", texWidth, texHeight, fboImageWidth, fboImageHeight);
				if(fromTextureRep->flipped)
				{
					glBegin(GL_QUADS);
					glTexCoord2f(0, 0);
					glVertex2f(0, fboImageHeight);
					glTexCoord2f(0, texImageHeight); 
					glVertex2f(0, 0);
					glTexCoord2f(texImageWidth, texImageHeight);
					glVertex2f(fboImageWidth, 0);
					glTexCoord2f(texImageWidth, 0);
					glVertex2f(fboImageWidth, fboImageHeight);
					glEnd();		
					
				}
				else
				{
					glBegin(GL_QUADS);
					glTexCoord2f(0, 0);
					glVertex2f(0, 0);
					glTexCoord2f(0, texImageHeight); 
					glVertex2f(0, fboImageHeight);
					glTexCoord2f(texImageWidth, texImageHeight);
					glVertex2f(fboImageWidth, fboImageHeight);
					glTexCoord2f(texImageWidth, 0);
					glVertex2f(fboImageWidth, 0);
					glEnd();		
				}				
			}
			else
			{
				// uh....
			}
		}
		glBindTexture(fromTarget, 0);
		glDisable(fromTarget);
		
		// Restore OpenGL states 
		glMatrixMode(GL_MODELVIEW);
		glPopMatrix();
		glMatrixMode(GL_PROJECTION);
		glPopMatrix();
		
		// restore states // assume this is balanced with above 
		glPopAttrib();
		
		// pop back to old FBO
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, previousFBO);	
		glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, previousReadFBO);
		glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, previousDrawFBO);
		
		glFlushRenderAPPLE();
		
		// delete our FBO so we dont leak.
		glDeleteFramebuffersEXT(1, &fboID);
		
		CGLUnlockContext(cgl_ctx);
    }
    return toTextureRep;
}

static FFGLImageRep *FFGLBufferRepCreateFromBuffer(const void *source, NSUInteger width, NSUInteger height, NSUInteger rowBytes, NSString *pixelFormat, BOOL isFlipped, FFGLImageBufferReleaseCallback callback, void *userInfo, BOOL forceCopy)
{
	FFGLImageRep *rep;
    NSUInteger bpp = ffglBytesPerPixelForPixelFormat(pixelFormat);
	if (source == NULL
		|| width == 0
		|| height == 0
		|| rowBytes == 0
		|| bpp == 0)
		return NULL;

	rep = malloc(sizeof(FFGLImageRep));
	if (rep != NULL)
	{
		if ((width * bpp) != rowBytes || isFlipped || forceCopy) {
			// FF plugins don't support pixel buffers where image width != row width.
			// We could just fiddle the reported image width, but this would give wrong results if the plugin takes borders into account.
			// We also flip buffers the right way up because we don't support upside down buffers - though FF plugins do...
			// In these cases we make a new buffer with no padding.
			unsigned int i;
			int newRowBytes = width * bpp;
			void *newBuffer = valloc(width * bpp * height);
			if (newBuffer == NULL)
			{
				free(rep);
				return NULL;
			}
			const void *s = source;
			void *d = newBuffer + (isFlipped ? newRowBytes * (height - 1) : 0);
			int droller = isFlipped ? -newRowBytes : newRowBytes;
			for (i = 0; i < height; i++) {
				memcpy(d, s, newRowBytes);
				s+=rowBytes;
				d+=droller;
			}
			if (callback)
				callback(source, userInfo);
			source = newBuffer;
			callback = FFGLImageBufferRelease;
			userInfo = NULL;
		}
		rep->flipped = NO;
		rep->releaseCallback.bufferCallback = callback;
		rep->releaseContext = userInfo;
		rep->type = FFGLImageRepTypeBuffer;
		rep->repInfo.bufferInfo.buffer = source;
		rep->repInfo.bufferInfo.width = width;
		rep->repInfo.bufferInfo.height = height;
		rep->repInfo.bufferInfo.pixelFormat = [pixelFormat retain];
	}
	return rep;
}

@interface FFGLImage (Private)
- (id)initWithCGLContext:(CGLContextObj)context imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight imageRep:(FFGLImageRep *)rep;
- (void)releaseResources;
@end

@implementation FFGLImage

/*
 Our private designated initializer
 */

- (id)initWithCGLContext:(CGLContextObj)context imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight imageRep:(FFGLImageRep *)rep
{
    if (self = [super init]) {
        if (imageWidth == 0 || imageHeight == 0 || rep == NULL || pthread_mutex_init(&_conversionLock, NULL) != 0) {
            [self release];
            return nil;
        }
        _context = CGLRetainContext(context);
        _imageWidth = imageWidth;
        _imageHeight = imageHeight;
	if (rep->type == FFGLImageRepTypeTexture2D)
	    _texture2D = rep;
	else if (rep->type == FFGLImageRepTypeTextureRect)
	    _textureRect = rep;
	else if (rep->type == FFGLImageRepTypeBuffer)
	    _buffer = rep;
	else
	{
	    [self release];
	    return nil;
	}
    }
    return self;
}
           
- (id)initWithTexture2D:(GLuint)texture CGLContext:(CGLContextObj)context imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight texturePixelsWide:(NSUInteger)textureWidth texturePixelsHigh:(NSUInteger)textureHeight flipped:(BOOL)isFlipped releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseInfo:(void *)userInfo
{
    FFGLImageRep *rep;
    // 2D textures are never stored flipped because plugins need them to be the right way up
    // we could however postpone the flipping to a call to lockTexture2DRepresentation..?
    if (isFlipped)
    {
	FFGLImageRep source;
	source.flipped = YES;
	source.releaseCallback.textureCallback = callback;
	source.releaseContext = userInfo;
	source.type = FFGLImageRepTypeTexture2D;
	source.repInfo.textureInfo.texture = texture;
	source.repInfo.textureInfo.hardwareWidth = textureWidth;
	source.repInfo.textureInfo.hardwareHeight = textureHeight;
	source.repInfo.textureInfo.width = imageWidth;
	source.repInfo.textureInfo.height = imageHeight;
	rep = FFGLTextureRepCreateFromTextureRep(context, &source, GL_TEXTURE_2D);
	if (callback != NULL)
	{
	    callback(texture, context, userInfo);
	}
    }
    else
    {
	rep = malloc(sizeof(FFGLImageRep));
	if (rep != NULL)
	{
	    
	    rep->type = FFGLImageRepTypeTexture2D;
	    rep->releaseCallback.textureCallback = callback;
	    rep->releaseContext = userInfo;
	    rep->repInfo.textureInfo.texture = texture;
	    rep->repInfo.textureInfo.width = imageWidth;
	    rep->repInfo.textureInfo.height = imageHeight;
	    rep->repInfo.textureInfo.hardwareWidth = textureWidth;
	    rep->repInfo.textureInfo.hardwareHeight = textureHeight;
	    rep->flipped = NO;        
	}	
    }
    return [self initWithCGLContext:context imagePixelsWide:imageWidth imagePixelsHigh:imageHeight imageRep:rep];
}

- (id)initWithTextureRect:(GLuint)texture CGLContext:(CGLContextObj)context pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height flipped:(BOOL)isFlipped releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseInfo:(void *)userInfo
{
    FFGLImageRep *rep = malloc(sizeof(FFGLImageRep));
    if (rep != NULL)
    {
	rep->type = FFGLImageRepTypeTextureRect;
	rep->releaseCallback.textureCallback = callback;
	rep->releaseContext = userInfo;
	rep->repInfo.textureInfo.texture = texture;
	rep->repInfo.textureInfo.width = rep->repInfo.textureInfo.hardwareWidth = width;
	rep->repInfo.textureInfo.height = rep->repInfo.textureInfo.hardwareHeight = height;
	rep->flipped = isFlipped;
    }
    return [self initWithCGLContext:context imagePixelsWide:width imagePixelsHigh:height imageRep:rep];
}

- (id)initWithBuffer:(const void *)buffer CGLContext:(CGLContextObj)context pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes flipped:(BOOL)isFlipped releaseCallback:(FFGLImageBufferReleaseCallback)callback releaseInfo:(void *)userInfo
{
    FFGLImageRep *rep = FFGLBufferRepCreateFromBuffer(buffer, width, height, rowBytes, format, isFlipped, callback, userInfo, NO);
    return [self initWithCGLContext:context imagePixelsWide:width imagePixelsHigh:height imageRep:rep];
}

- (id)initWithCopiedTextureRect:(GLuint)texture CGLContext:(CGLContextObj)context pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height flipped:(BOOL)isFlipped
{
    FFGLImageRep source;
    source.type = FFGLImageRepTypeTextureRect;
    source.flipped = isFlipped;
    source.repInfo.textureInfo.texture = texture;
    source.repInfo.textureInfo.hardwareWidth = source.repInfo.textureInfo.width = width;
    source.repInfo.textureInfo.hardwareHeight = source.repInfo.textureInfo.height = height;
    // copy to 2D to save doing it when images get used by a renderer.
    FFGLImageRep *new = FFGLTextureRepCreateFromTextureRep(context, &source, GL_TEXTURE_2D);
    return [self initWithCGLContext:context imagePixelsWide:width imagePixelsHigh:height imageRep:new];
}

- (id)initWithCopiedTexture2D:(GLuint)texture CGLContext:(CGLContextObj)context imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight texturePixelsWide:(NSUInteger)textureWidth texturePixelsHigh:(NSUInteger)textureHeight flipped:(BOOL)isFlipped
{
    FFGLImageRep source;
    source.type = FFGLImageRepTypeTexture2D;
    source.flipped = isFlipped;
    source.repInfo.textureInfo.texture = texture;
    source.repInfo.textureInfo.hardwareWidth = textureWidth;
    source.repInfo.textureInfo.width = imageWidth;
    source.repInfo.textureInfo.hardwareHeight = textureHeight;
    source.repInfo.textureInfo.height = imageHeight;
    FFGLImageRep *new = FFGLTextureRepCreateFromTextureRep(context, &source, GL_TEXTURE_2D);
    return [self initWithCGLContext:context imagePixelsWide:imageWidth imagePixelsHigh:imageHeight imageRep:new];
}

- (id)initWithCopiedBuffer:(const void *)buffer CGLContext:(CGLContextObj)context pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes flipped:(BOOL)isFlipped
{
    FFGLImageRep *rep = FFGLBufferRepCreateFromBuffer(buffer, width, height, rowBytes, format, isFlipped, NULL, NULL, YES);
    return [self initWithCGLContext:context imagePixelsWide:width imagePixelsHigh:height imageRep:rep];
}

- (void)releaseResources 
{
    if (_texture2D)
    {
		if (((FFGLImageRep *)_texture2D)->releaseCallback.textureCallback != NULL)
			((FFGLImageRep *)_texture2D)->releaseCallback.textureCallback(((FFGLImageRep *)_texture2D)->repInfo.textureInfo.texture, _context, ((FFGLImageRep *)_texture2D)->releaseContext);
		free(_texture2D);
    }
    if (_textureRect)
	{
		if (((FFGLImageRep *)_textureRect)->releaseCallback.textureCallback != NULL)
			((FFGLImageRep *)_textureRect)->releaseCallback.textureCallback(((FFGLImageRep *)_textureRect)->repInfo.textureInfo.texture, _context, ((FFGLImageRep *)_textureRect)->releaseContext);
		free(_textureRect);
    }
    if (_buffer)
    {
		[((FFGLImageRep *)_buffer)->repInfo.bufferInfo.pixelFormat release];
		if (((FFGLImageRep *)_buffer)->releaseCallback.bufferCallback != NULL)
			((FFGLImageRep *)_buffer)->releaseCallback.bufferCallback(((FFGLImageRep *)_buffer)->repInfo.bufferInfo.buffer, ((FFGLImageRep *)_buffer)->releaseContext);
		free(_buffer);
    }
    CGLReleaseContext(_context);
    pthread_mutex_destroy(&_conversionLock);
}

- (void)dealloc {
    [self releaseResources];
    [super dealloc];
}

- (void)finalize {
    [self releaseResources];
    [super finalize];
}

- (NSUInteger)imagePixelsWide {
    return _imageWidth;
}

- (NSUInteger)imagePixelsHigh {
    return _imageHeight;
}

#pragma mark GL_TEXTURE_2D

- (BOOL)lockTexture2DRepresentation {
    BOOL result = NO;
    pthread_mutex_lock(&_conversionLock);
    if (_texture2D)
    {
		result = YES;
    }
    else
    {
		if (_textureRect)
		{
			_texture2D = FFGLTextureRepCreateFromTextureRep(_context, _textureRect, GL_TEXTURE_2D);
			if (_texture2D)
				result = YES;
		}
		else if (_buffer)
		{
			_texture2D = FFGLTextureRepCreateFromBufferRep(_context, _buffer, FFGLImageRepTypeTexture2D);
			if (_texture2D)
				result = YES;
		}
    }
    pthread_mutex_unlock(&_conversionLock);
    return result;
}

- (void)unlockTexture2DRepresentation {
    // do nothing
}

- (GLuint)texture2DName
{
    return ((FFGLImageRep *)_texture2D)->repInfo.textureInfo.texture;
}

- (NSUInteger)texture2DPixelsWide 
{
    return ((FFGLImageRep *)_texture2D)->repInfo.textureInfo.hardwareWidth;
}

- (NSUInteger)texture2DPixelsHigh
{
    return ((FFGLImageRep *)_texture2D)->repInfo.textureInfo.hardwareHeight;
}

- (BOOL)texture2DIsFlipped
{
    // currently this will always be NO
    return ((FFGLImageRep *)_texture2D)->flipped;
}

- (FFGLTextureInfo *)_texture2DInfo
{
    return &((FFGLImageRep *)_texture2D)->repInfo.textureInfo;
}

#pragma mark GL_TEXTURE_RECTANGLE_EXT

- (BOOL)lockTextureRectRepresentation {
    BOOL result = NO;
    pthread_mutex_lock(&_conversionLock);
    if (_textureRect)
    {
		result = YES;
    }
    else if (_texture2D)
    {
		_textureRect = FFGLTextureRepCreateFromTextureRep(_context, _texture2D, GL_TEXTURE_RECTANGLE_ARB);
		if (_textureRect)
			result = YES;
    }
    else if (_buffer)
    {
		_textureRect = FFGLTextureRepCreateFromBufferRep(_context, _buffer, FFGLImageRepTypeTextureRect);
		if (_textureRect)
			result = YES;
    }	
    pthread_mutex_unlock(&_conversionLock);
    return result;
}

- (void)unlockTextureRectRepresentation
{
    // do nothing
}

- (GLuint)textureRectName
{
    return ((FFGLImageRep *)_textureRect)->repInfo.textureInfo.texture;
}

- (NSUInteger)textureRectPixelsWide
{
    return ((FFGLImageRep *)_textureRect)->repInfo.textureInfo.hardwareWidth;
}

- (NSUInteger)textureRectPixelsHigh
{
    return ((FFGLImageRep *)_textureRect)->repInfo.textureInfo.hardwareHeight;
}

- (BOOL)textureRectIsFlipped
{
    return ((FFGLImageRep *)_textureRect)->flipped;
}

#pragma mark Pixel Buffers

- (BOOL)lockBufferRepresentationWithPixelFormat:(NSString *)format {
    BOOL result = NO;
    pthread_mutex_lock(&_conversionLock);
    if (_buffer)
    {
		if (![format isEqualToString:((FFGLImageRep *)_buffer)->repInfo.bufferInfo.pixelFormat])
		{
			// We don't support converting between different formats (yet?).
		}
		else
		{
			result = YES;
		}
    }
    else if (_textureRect)
    {
		_buffer = FFGLBufferRepCreateFromTextureRep(_context, _textureRect, format);
		if (_buffer)
			result = YES;
    }
	else if (_texture2D)
	{
		_buffer = FFGLBufferRepCreateFromTextureRep(_context, _texture2D, format);
		if (_buffer)
			result = YES;
	}
    pthread_mutex_unlock(&_conversionLock);
    return result;
}

- (void)unlockBufferRepresentation
{
    // Do nothing.
}

- (const void *)bufferBaseAddress
{
    return ((FFGLImageRep *)_buffer)->repInfo.bufferInfo.buffer;
}

- (NSUInteger)bufferPixelsWide
{
    return _imageWidth; // our buffers are never padded.
}

- (NSUInteger)bufferPixelsHigh
{
    return _imageHeight; // our buffers are never padded.
}

- (NSUInteger)bufferBytesPerRow
{
    return _imageWidth * ffglBytesPerPixelForPixelFormat(((FFGLImageRep *)_buffer)->repInfo.bufferInfo.pixelFormat);
}

- (NSString *)bufferPixelFormat
{
    return ((FFGLImageRep *)_buffer)->repInfo.bufferInfo.pixelFormat;
}

- (BOOL)bufferIsFlipped
{
    return ((FFGLImageRep *)_buffer)->flipped;
}
@end
