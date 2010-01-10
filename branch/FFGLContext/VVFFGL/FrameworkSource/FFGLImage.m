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

#pragma mark Private image representation types and storage

typedef NSUInteger FFGLImageRepType;
enum {
    FFGLImageRepTypeTexture2D = 0,
    FFGLImageRepTypeTextureRect = 1,
    FFGLImageRepTypeBuffer = 2
};

// FFGLTextureInfo is in FFGLInternal.h as it's shared with plugins.

typedef struct FFGLBufferInfo {
    unsigned int        width;
    unsigned int        height;
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

static NSUInteger bytesPerPixelForPixelFormat(NSString *format) {
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

/*
 swapTextureTargets
 Takes pointers to two FFGLTextureInfo structures and performs the TEXTURE_2D <-> TEXTURE_RECTANGLE conversion
 of fromTexture.
 On return toTexture will be filled out with details of a new texture.
 You are responsible for deleting this texture (using glDeleteTextures).
 */
static FFGLImageRep *FFGLImageRepCreateFromTextureRep(CGLContextObj cgl_ctx, const FFGLImageRep *fromTextureRep, GLenum toTarget)
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
		    
	GLsizei width, height;
	// set up our destination target
	if(fromTarget == GL_TEXTURE_RECTANGLE_ARB)
	{
	    width = toTexture->hardwareWidth = FFGLPOTDimension(fromTexture->width);
	    height = toTexture->hardwareHeight = FFGLPOTDimension(fromTexture->height);
	} 
	else
	{
	    width = toTexture->hardwareWidth = fromTexture->width;
	    height = toTexture->hardwareHeight = fromTexture->height;
	}
	toTexture->width = fromTexture->width;
	toTexture->height = fromTexture->height;
	
	CGLContextObj previousContext = CGLGetCurrentContext();
	CGLSetCurrentContext(cgl_ctx);
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
	
	glBindTexture(toTarget, newTex);
	glTexImage2D(toTarget, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

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
	    glViewport(0, 0, width, height);
	    glMatrixMode(GL_PROJECTION);
	    glPushMatrix();
	    glLoadIdentity();
	    
	    // weirdo ortho
	    glOrtho(0.0, width, 0.0, height, -1, 1);		
	    
	    glMatrixMode(GL_MODELVIEW);
	    glPushMatrix();
	    glLoadIdentity();
	    
	    // draw the texture.
	    //texture->draw(0,0);
	    
	    glClearColor(0,0,0,0);
	    glClear(GL_COLOR_BUFFER_BIT);
	    
	    glActiveTexture(GL_TEXTURE0);
	    glEnable(fromTarget);
	    glBindTexture(fromTarget, fromTexture->texture);
	    
	    if(fromTarget == GL_TEXTURE_RECTANGLE_ARB)
	    {	
		    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
		    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
		    
		    if(fromTextureRep->flipped)
		    {
			    glBegin(GL_QUADS);
			    glTexCoord2f(0, 0);
			    glVertex2f(0, height);
			    glTexCoord2f(0, height);
			    glVertex2f(0, 0);
			    glTexCoord2f(width, height);
			    glVertex2f(width, 0);
			    glTexCoord2f(width, 0);
			    glVertex2f(width, height);
			    glEnd();		
		    }
		    else
		    {
			    glBegin(GL_QUADS);
			    glTexCoord2f(0, 0);
			    glVertex2f(0, 0);
			    glTexCoord2f(0, height);
			    glVertex2f(0, height);
			    glTexCoord2f(width, height);
			    glVertex2f(width, height);
			    glTexCoord2f(width, 0);
			    glVertex2f(width, 0);
			    glEnd();					
		    }
	    }
	    else if(fromTarget == GL_TEXTURE_2D)
	    {
		    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
		    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
		    
		    // since our image is NPOT but our texture is POT, we must 
		    // deduce proper texture coords in normalized space
		    GLfloat texWidth = (GLfloat) fromTexture->width / (GLfloat)fromTexture->hardwareWidth;
		    GLfloat texHeight = (GLfloat)fromTexture->height / (GLfloat)fromTexture->hardwareHeight;
		    
		    if(fromTextureRep->flipped)
		    {
			    glBegin(GL_QUADS);
			    glTexCoord2f(0, 0);
			    glVertex2f(0, texHeight);
			    glTexCoord2f(0, 0); 
			    glVertex2f(0, height);
			    glTexCoord2f(texWidth, texHeight);
			    glVertex2f(width, 0);
			    glTexCoord2f(texWidth, 0);
			    glVertex2f(width, texHeight);
			    glEnd();		
			    
		    }
		    else
		    {
			    glBegin(GL_QUADS);
			    glTexCoord2f(0, 0);
			    glVertex2f(0, 0);
			    glTexCoord2f(0, texHeight); 
			    glVertex2f(0, height);
			    glTexCoord2f(texWidth, texHeight);
			    glVertex2f(width, height);
			    glTexCoord2f(texWidth, 0);
			    glVertex2f(width, 0);
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
		CGLSetCurrentContext(previousContext);
    }
    return toTextureRep;
}

static void *createBufferFromTexture(CGLContextObj cgl_ctx, FFGLTextureInfo *sourceInfo)
{
    // TODO: !
    return NULL;
}


static FFGLTextureInfo *createTextureFromBuffer(CGLContextObj cgl_ctx, void *buffer, NSUInteger pixelsWide, NSUInteger pixelsHigh) // plus pixelFormat, presumably
{
    // TODO: !
    return NULL;
}

static void *FFGLImageBufferCreateCopy(const void *source, NSUInteger width, NSUInteger height, NSUInteger rowBytes, NSUInteger bytesPerPixel, BOOL isFlipped)
{
    if (width == 0
	|| height == 0
	|| rowBytes == 0
	|| bytesPerPixel == 0)
	return NULL;
    unsigned int i;
    int newRowBytes = width * bytesPerPixel;
    void *newBuffer = valloc(width * bytesPerPixel * height);
    if (newBuffer) {
	int soffset = 0;
	int doffset = isFlipped ? newRowBytes * (height - 1) : 0;
	int droller = isFlipped ? -newRowBytes : newRowBytes;
	for (i = 0; i < height; i++) {
	    memcpy(newBuffer + doffset, source + soffset, newRowBytes);
	    soffset+=rowBytes;
	    doffset+=droller;
	}	
    }
    return newBuffer;
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
	rep = FFGLImageRepCreateFromTextureRep(context, &source, GL_TEXTURE_2D);
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
    FFGLImageRep *rep;
    NSUInteger bpp = bytesPerPixelForPixelFormat(format);
    // Check the pixel-format is valid
    if (bpp != 0)
    {
	rep = malloc(sizeof(FFGLImageRep));
	if (rep != NULL)
	{
	    if ((width * bpp) != rowBytes || isFlipped) {
		// FF plugins don't support pixel buffers where image width != row width.
		// We could just fiddle the reported image width, but this would give wrong results if the plugin takes borders into account.
		// We also flip buffers the right way up because we don't support upside down buffers - though FF plugins do...
		// In these cases we make a new buffer with no padding.
		void *newBuffer = FFGLImageBufferCreateCopy(buffer, width, height, rowBytes, bpp, isFlipped);
		if (newBuffer == NULL) {
		    free(rep);
		    [self release];
		    return nil;
		}
		if (callback)
		    callback(buffer, userInfo);
		buffer = newBuffer;
		callback = FFGLImageBufferRelease;
		userInfo = NULL;
	    }
	    rep->flipped = NO;
	    rep->releaseCallback.bufferCallback = callback;
	    rep->releaseContext = userInfo;
	    rep->type = FFGLImageRepTypeBuffer;
	    rep->repInfo.bufferInfo.buffer = buffer;
	    rep->repInfo.bufferInfo.width = width;
	    rep->repInfo.bufferInfo.height = height;
	    rep->repInfo.bufferInfo.pixelFormat = [format retain];
	}
    }
    else
    {
	rep = NULL;
    }
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
    FFGLImageRep *new = FFGLImageRepCreateFromTextureRep(context, &source, GL_TEXTURE_2D);
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
    FFGLImageRep *new = FFGLImageRepCreateFromTextureRep(context, &source, GL_TEXTURE_2D);
    return [self initWithCGLContext:context imagePixelsWide:imageWidth imagePixelsHigh:imageHeight imageRep:new];
}

- (id)initWithCopiedBuffer:(const void *)buffer CGLContext:(CGLContextObj)context pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes flipped:(BOOL)isFlipped
{
    // Check the pixel-format is valid
    NSUInteger bpp = bytesPerPixelForPixelFormat(format);
    if (bpp == 0 || buffer == NULL || width == 0 || height == 0 || rowBytes == 0) { 
        [NSException raise:@"FFGLImageException" format:@"Invalid arguments in init."];
        [self release];
        return nil;
    }
    FFGLImageRep *rep = malloc(sizeof(FFGLImageRep));
    if (rep != NULL)
    {
		void *newBuffer = FFGLImageBufferCreateCopy(buffer, width, height, rowBytes, bpp, isFlipped);
		if (newBuffer == NULL) {
			free(rep);
			[self release];
			return nil;
		}
		rep->flipped = NO;
		rep->releaseCallback.bufferCallback = FFGLImageBufferRelease;
		rep->releaseContext = NULL;
		rep->type = FFGLImageRepTypeBuffer;
		rep->repInfo.bufferInfo.buffer = newBuffer;
		rep->repInfo.bufferInfo.width = width;
		rep->repInfo.bufferInfo.height = height;
		rep->repInfo.bufferInfo.pixelFormat = [format retain];
    }
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
	    _texture2D = FFGLImageRepCreateFromTextureRep(_context, _textureRect, GL_TEXTURE_2D);
	    if (_texture2D)
		result = YES;
	}
	else if (_buffer)
	{
	    // TODO: buffer->texture conversion
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
	_textureRect = FFGLImageRepCreateFromTextureRep(_context, _texture2D, GL_TEXTURE_RECTANGLE_ARB);
	if (_textureRect)
	    result = YES;
    }
    else if (_buffer)
    {
	// TODO: generate it, return YES;
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
    else
    {
	// TODO: Conversion from GL textures.
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
    return _imageWidth * bytesPerPixelForPixelFormat(((FFGLImageRep *)_buffer)->repInfo.bufferInfo.pixelFormat);
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
