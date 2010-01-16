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

/*
	We currently check for NPOT 2D support once per FFGLImage. It would be more efficient to do this once
	per CGLContext...
 */

// This makes a noticable difference with large images. I'll ditch option at some stage... just here for testing
#define FFGL_USE_TEXTURE_RANGE 1

#pragma mark Private image representation types and storage

typedef NSUInteger FFGLImageRepType;
enum {
    FFGLImageRepTypeTexture2D = 0,
    FFGLImageRepTypeTextureRect = 1,
    FFGLImageRepTypeBuffer = 2
};

typedef NSUInteger FFGLImagePOT2DRule;
enum {
	FFGLImageUseNPOT2D = 0,
	FFGLImageUsePOT2D = 1,
	FFGLImagePOTUnknown = 2
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

static FFGLImageRep *FFGLBufferRepCreateFromBuffer(const void *source, NSUInteger width, NSUInteger height, NSUInteger rowBytes, NSString *pixelFormat, BOOL isFlipped, FFGLImageBufferReleaseCallback callback, void *userInfo, BOOL forceCopy);
static FFGLImageRep *FFGLTextureRepCreateFromTextureRep(CGLContextObj cgl_ctx, const FFGLImageRep *fromTextureRep, FFGLImageRepType toTarget, BOOL useNPOT);
static FFGLImageRep *FFGLTextureRepCreateFromBufferRep(CGLContextObj cgl_ctx, const FFGLImageRep *fromBufferRep, FFGLImageRepType toTarget, BOOL useNPOT);
static void FFGLImageRepDestroy(CGLContextObj cgl_ctx, FFGLImageRep *rep);

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
		// If our source has POT dimensions beyond its bounds, we fail. In that case,
		// the caller should first create a rect texture then convert from that
		if (fromTextureRep->repInfo.textureInfo.hardwareWidth != fromTextureRep->repInfo.textureInfo.width
			|| fromTextureRep->repInfo.textureInfo.hardwareHeight != fromTextureRep->repInfo.textureInfo.height
			)
		{
			return NULL;
		}
		else
		{
			targetGL = GL_TEXTURE_2D;
		}
	}
	else if (fromTextureRep->type == FFGLImageRepTypeTextureRect)
	{
		targetGL = GL_TEXTURE_RECTANGLE_ARB;
	}
	else
	{
		return NULL;
	}

	GLenum format, type;
	if (ffglGLInfoForPixelFormat(pixelFormat, &format, &type) == NO)
	{
		return NULL;
	}
	unsigned int rowBytes = fromTextureRep->repInfo.textureInfo.hardwareWidth * ffglBytesPerPixelForPixelFormat(pixelFormat);
	GLvoid *buffer = valloc(rowBytes * fromTextureRep->repInfo.textureInfo.hardwareHeight);
	if (buffer == NULL)
	{
		return NULL;
	}

	CGLLockContext(cgl_ctx);

	// Save state
	glPushAttrib(GL_TEXTURE_BIT | GL_ENABLE_BIT);
	glPushClientAttrib(GL_CLIENT_PIXEL_STORE_BIT);
	
	// Make sure pixel-storage is set up as we need it
	glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
	glPixelStorei(GL_PACK_ROW_LENGTH, 0);
	glPixelStorei(GL_PACK_IMAGE_HEIGHT, 0);
	glPixelStorei(GL_PACK_ALIGNMENT, 1);
	glPixelStorei(GL_PACK_LSB_FIRST, GL_FALSE);
	glPixelStorei(GL_PACK_SKIP_IMAGES, 0);
	glPixelStorei(GL_PACK_SKIP_PIXELS, 0);
	glPixelStorei(GL_PACK_SKIP_ROWS, 0);
	glPixelStorei(GL_PACK_SWAP_BYTES, GL_FALSE);
	
	// Get the pixel data
	glEnable(targetGL);
	glBindTexture(targetGL, fromTextureRep->repInfo.textureInfo.texture);
	glGetTexImage(targetGL, 0, format, type, buffer);
	
	// Check for error
	GLenum error = glGetError();
	
	// Restore state
	glPopClientAttrib();
	glPopAttrib();

	CGLUnlockContext(cgl_ctx);

	if (error != GL_NO_ERROR)
	{
		free(buffer);
		return NULL;
	}

	FFGLImageRep *rep = FFGLBufferRepCreateFromBuffer(buffer,
													  fromTextureRep->repInfo.textureInfo.width,
													  fromTextureRep->repInfo.textureInfo.height,
													  rowBytes, pixelFormat, fromTextureRep->flipped,
													  FFGLImageBufferRelease, NULL, NO);
	return rep;
}

static FFGLImageRep *FFGLTextureRepCreateFromBufferRep(CGLContextObj cgl_ctx, const FFGLImageRep *fromBufferRep, FFGLImageRepType toTarget, BOOL useNPOT)
{
	GLenum targetGL;
	
	// We fail if the image does not fill the texture (eg some POT-dimensioned 2D textures)
	// because it is quicker to do buffer->rect->2d than to create a temporary scaled buffer
	
	unsigned int texWidth, texHeight;
	texWidth = fromBufferRep->repInfo.bufferInfo.width;
	texHeight = fromBufferRep->repInfo.bufferInfo.height;
	
	if (toTarget == FFGLImageRepTypeTexture2D)
	{
		targetGL = GL_TEXTURE_2D;
		if (!useNPOT
			&& (texWidth != ffglPOTDimension(texWidth) || texHeight != ffglPOTDimension(texHeight))
			)
		{
			return NULL;
		}
	}
	else if (toTarget == FFGLImageRepTypeTextureRect)
	{
		targetGL = GL_TEXTURE_RECTANGLE_ARB;
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
		
		// Save state
		glPushAttrib(GL_TEXTURE_BIT | GL_ENABLE_BIT);
		glPushClientAttrib(GL_CLIENT_PIXEL_STORE_BIT);

		glEnable(targetGL);
		
		// Make our new texture
		GLuint tex;
		glGenTextures(1, &tex);
		glBindTexture(targetGL, tex);
		
		// Set up the environment for unpacking
		glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
		glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
		glPixelStorei(GL_UNPACK_ROW_LENGTH, fromBufferRep->repInfo.bufferInfo.width);
		glPixelStorei(GL_UNPACK_IMAGE_HEIGHT, 0);
		glPixelStorei(GL_UNPACK_LSB_FIRST, GL_FALSE);
		glPixelStorei(GL_UNPACK_SKIP_IMAGES, 0);
		glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
		glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);
		glPixelStorei(GL_UNPACK_SWAP_BYTES, GL_FALSE);
		
		// GL_UNPACK_CLIENT_STORAGE_APPLE tells GL to use our buffer in memory if possible, to avoid a copy to the GPU.
		glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
		
#if defined(FFGL_USE_TEXTURE_RANGE)
		// Set storage hint GL_STORAGE_SHARED_APPLE to tell GL to share storage with main memory.
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
		glPopClientAttrib();
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

static FFGLImageRep *FFGLTextureRepCreateFromTextureRep(CGLContextObj cgl_ctx, const FFGLImageRep *fromTextureRep, FFGLImageRepType toTarget, BOOL useNPOT)
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
		GLenum fromGLTarget = fromTextureRep->type == FFGLImageRepTypeTexture2D ? GL_TEXTURE_2D : GL_TEXTURE_RECTANGLE_ARB;
		GLenum toGLTarget = toTarget == FFGLImageRepTypeTexture2D ? GL_TEXTURE_2D : GL_TEXTURE_RECTANGLE_ARB;
		// set up our new texture-rep.
		toTextureRep->flipped = NO;
		toTextureRep->releaseCallback.textureCallback = FFGLImageTextureRelease;
		toTextureRep->releaseContext = NULL;
		toTextureRep->type = toTarget;
		
		FFGLTextureInfo *toTexture = &toTextureRep->repInfo.textureInfo;

		// cache FBO state
		GLint previousFBO, previousReadFBO, previousDrawFBO;
		
		// the FBO attachment texture we are going to render to.
				
		GLsizei fboWidth, fboHeight;
		// set up our destination target
		if((toGLTarget == GL_TEXTURE_2D) && (!useNPOT))
		{
			fboWidth = toTexture->hardwareWidth = ffglPOTDimension(fromTexture->width);
			fboHeight = toTexture->hardwareHeight = ffglPOTDimension(fromTexture->height);
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
		
		glEnable(toGLTarget);

		glBindTexture(toGLTarget, newTex);
		glTexImage2D(toGLTarget, 0, GL_RGBA8, fboWidth, fboHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

		// texture filtering and wrapping modes for FBO texture.
		glTexParameteri(toGLTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(toGLTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(toGLTarget, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
		glTexParameteri(toGLTarget, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
		
	//	NSLog(@"new texture: %u, original texture: %u", newTex, fromTexture->texture);
		toTexture->texture = newTex;

		// make new FBO and attach.
		GLuint fboID;
		glGenFramebuffersEXT(1, &fboID);
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, fboID);
		glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, toGLTarget, newTex, 0);

		// unbind texture
		glBindTexture(toGLTarget, 0);
		glDisable(toGLTarget);

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
			
			glActiveTexture(GL_TEXTURE0);
			glEnable(fromGLTarget);
			glBindTexture(fromGLTarget, fromTexture->texture);
			
			if(fromGLTarget == GL_TEXTURE_RECTANGLE_ARB || fromGLTarget == GL_TEXTURE_2D)
			{	
				glTexParameteri(fromGLTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
				glTexParameteri(fromGLTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
				glTexParameteri(fromGLTarget, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
				glTexParameteri(fromGLTarget, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);				
			
				// since our image is NPOT but our texture is POT, we must 
				// deduce proper texture coords in normalized space
				
				GLfloat texImageWidth, texImageHeight;

				texImageWidth = fromGLTarget == GL_TEXTURE_2D ? (GLfloat) fromTexture->width / (GLfloat)fromTexture->hardwareWidth : fromTexture->width;
				texImageHeight = fromGLTarget == GL_TEXTURE_2D ? (GLfloat)fromTexture->height / (GLfloat)fromTexture->hardwareHeight : fromTexture->height;
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
		glBindTexture(fromGLTarget, 0);
		glDisable(fromGLTarget);
		
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

static void FFGLImageRepDestroy(CGLContextObj cgl_ctx, FFGLImageRep *rep)
{
	if (rep->type == FFGLImageRepTypeTexture2D || rep->type == FFGLImageRepTypeTextureRect)
	{
		if (rep->releaseCallback.textureCallback != NULL)
			rep->releaseCallback.textureCallback(rep->repInfo.textureInfo.texture, cgl_ctx, rep->releaseContext);
    }
    else if (rep->type == FFGLImageRepTypeBuffer)
    {
		[rep->repInfo.bufferInfo.pixelFormat release];
		if (rep->releaseCallback.bufferCallback != NULL)
			rep->releaseCallback.bufferCallback(rep->repInfo.bufferInfo.buffer, rep->releaseContext);
    }
	free(rep);
}

@interface FFGLImage (Private)
- (id)initWithCGLContext:(CGLContextObj)context imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight imageRep:(FFGLImageRep *)rep usePOT2D:(FFGLImagePOT2DRule)POT;
- (void)releaseResources;
- (BOOL)useNPOT2D;
@end

@implementation FFGLImage

/*
 Our private designated initializer
 */

- (id)initWithCGLContext:(CGLContextObj)context imageRep:(FFGLImageRep *)rep usePOT2D:(FFGLImagePOT2DRule)POT
{
    if (self = [super init]) {
        if (rep == NULL
			|| pthread_mutex_init(&_conversionLock, NULL) != 0)
		{
            [self release];
            return nil;
        }
        _context = CGLRetainContext(context);
		_NPOTRule = POT;
		
		if (rep->type == FFGLImageRepTypeTexture2D)
		{
			_texture2D = rep;
			_imageWidth = rep->repInfo.textureInfo.width;
			_imageHeight = rep->repInfo.textureInfo.height;
		}
		else if (rep->type == FFGLImageRepTypeTextureRect)
		{
			_textureRect = rep;
			_imageWidth = rep->repInfo.textureInfo.width;
			_imageHeight = rep->repInfo.textureInfo.height;
		}
		else if (rep->type == FFGLImageRepTypeBuffer)
		{
			_buffer = rep;
			_imageWidth = rep->repInfo.bufferInfo.width;
			_imageHeight = rep->repInfo.bufferInfo.height;
		}
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
    FFGLImageRep *rep = malloc(sizeof(FFGLImageRep));
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
	    rep->flipped = isFlipped;
	}
    return [self initWithCGLContext:context imageRep:rep usePOT2D:FFGLImagePOTUnknown];
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
    return [self initWithCGLContext:context imageRep:rep usePOT2D:FFGLImagePOTUnknown];
}

- (id)initWithBuffer:(const void *)buffer CGLContext:(CGLContextObj)context pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes flipped:(BOOL)isFlipped releaseCallback:(FFGLImageBufferReleaseCallback)callback releaseInfo:(void *)userInfo
{
    FFGLImageRep *rep = FFGLBufferRepCreateFromBuffer(buffer, width, height, rowBytes, format, isFlipped, callback, userInfo, NO);
    return [self initWithCGLContext:context imageRep:rep usePOT2D:FFGLImagePOTUnknown];
}

- (id)initWithCopiedTextureRect:(GLuint)texture CGLContext:(CGLContextObj)context pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height flipped:(BOOL)isFlipped
{
    FFGLImageRep source;
    source.type = FFGLImageRepTypeTextureRect;
    source.flipped = isFlipped;
    source.repInfo.textureInfo.texture = texture;
    source.repInfo.textureInfo.hardwareWidth = source.repInfo.textureInfo.width = width;
    source.repInfo.textureInfo.hardwareHeight = source.repInfo.textureInfo.height = height;
	BOOL useNPOT = ffglOpenGLSupportsExtension(context, "GL_ARB_texture_non_power_of_two");
	FFGLImagePOT2DRule POTRule = useNPOT ? FFGLImageUseNPOT2D : FFGLImageUsePOT2D;
    // copy to 2D to save doing it when images get used by a renderer.
    FFGLImageRep *new = FFGLTextureRepCreateFromTextureRep(context, &source, FFGLImageRepTypeTexture2D, useNPOT);
    return [self initWithCGLContext:context imageRep:new usePOT2D:POTRule];
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
	BOOL useNPOT = ffglOpenGLSupportsExtension(context, "GL_ARB_texture_non_power_of_two");
	FFGLImagePOT2DRule POTRule = useNPOT ? FFGLImageUseNPOT2D : FFGLImageUsePOT2D;
    FFGLImageRep *new = FFGLTextureRepCreateFromTextureRep(context, &source, FFGLImageRepTypeTexture2D, useNPOT);
    return [self initWithCGLContext:context imageRep:new usePOT2D:POTRule];
}

- (id)initWithCopiedBuffer:(const void *)buffer CGLContext:(CGLContextObj)context pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes flipped:(BOOL)isFlipped
{
    FFGLImageRep *rep = FFGLBufferRepCreateFromBuffer(buffer, width, height, rowBytes, format, isFlipped, NULL, NULL, YES);
    return [self initWithCGLContext:context imageRep:rep usePOT2D:FFGLImagePOTUnknown];
}

- (void)releaseResources 
{
    if (_texture2D)
		FFGLImageRepDestroy(_context, (FFGLImageRep *)_texture2D);
	if (_textureRect)
		FFGLImageRepDestroy(_context, (FFGLImageRep *)_textureRect);
    if (_buffer)
		FFGLImageRepDestroy(_context, (FFGLImageRep *)_buffer);
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

- (BOOL)useNPOT2D
{
	// always called from within a lock, so no need to lock
	if (_NPOTRule == FFGLImagePOTUnknown)
	{
		_NPOTRule = ffglOpenGLSupportsExtension(_context, "GL_ARB_texture_non_power_of_two") ? FFGLImageUseNPOT2D : FFGLImageUsePOT2D;
	}
	return _NPOTRule == FFGLImageUseNPOT2D ? YES : NO;
}

#pragma mark GL_TEXTURE_2D

- (BOOL)lockTexture2DRepresentation {
    BOOL result = NO;
    pthread_mutex_lock(&_conversionLock);
    if (_texture2D)
    {
		if (((FFGLImageRep *)_texture2D)->flipped == YES)
		{
			// An FFGLImage may be initted with a flipped texture, but we always lock with it not flipped
			// as plugins don't support flipping
			FFGLImageRep *rep = FFGLTextureRepCreateFromTextureRep(_context, _texture2D, FFGLImageRepTypeTexture2D, [self useNPOT2D]);
			if (rep != NULL)
			{
				FFGLImageRepDestroy(_context, _texture2D);
				_texture2D = rep;
				result = YES;
			}
		}
		else
		{
			result = YES;
		}
    }
    else
    {
		if (_textureRect)
		{
			_texture2D = FFGLTextureRepCreateFromTextureRep(_context, _textureRect, FFGLImageRepTypeTexture2D, [self useNPOT2D]);
			if (_texture2D)
				result = YES;
		}
		else if (_buffer)
		{
			BOOL useNPOT2D = [self useNPOT2D];
			_texture2D = FFGLTextureRepCreateFromBufferRep(_context, _buffer, FFGLImageRepTypeTexture2D, useNPOT2D);
			if (_texture2D == NULL)
			{
				// Buffer->2D creation will fail in some cases, so try buffer->rect->2D
				_textureRect = FFGLTextureRepCreateFromBufferRep(_context, _buffer, FFGLImageRepTypeTextureRect, useNPOT2D);
				if (_textureRect)
				{
					_texture2D = FFGLTextureRepCreateFromTextureRep(_context, _textureRect, FFGLImageRepTypeTexture2D, useNPOT2D);
				}
			}
			if (_texture2D)
			{
				result = YES;
			}
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
		_textureRect = FFGLTextureRepCreateFromTextureRep(_context, _texture2D, FFGLImageRepTypeTextureRect, [self useNPOT2D]);
		if (_textureRect)
			result = YES;
    }
    else if (_buffer)
    {
		_textureRect = FFGLTextureRepCreateFromBufferRep(_context, _buffer, FFGLImageRepTypeTextureRect, [self useNPOT2D]);
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
		if (_buffer == NULL)
		{
			// Buffer creation from 2D textures fails if it would involve a buffer copy stage.
			// In such cases, create a rect texture, then create the buffer from that.
			_textureRect = FFGLTextureRepCreateFromTextureRep(_context, _texture2D, FFGLImageRepTypeTextureRect, [self useNPOT2D]);
			if (_textureRect)
			{
				_buffer = FFGLBufferRepCreateFromTextureRep(_context, _textureRect, format);
			}
		}
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
