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
#import "FFGLImageRep.h"
#import <pthread.h>
#import <OpenGL/CGLMacro.h>

/*
	We currently check for NPOT 2D support once per FFGLImage. It would be more efficient to do this once
	per CGLContext...
 */

// This makes a noticable difference with large images. I'll ditch option at some stage... just here for testing
#define FFGL_USE_TEXTURE_RANGE 1

typedef NSUInteger FFGLImagePOT2DRule;
enum {
	FFGLImageUseNPOT2D = 0,
	FFGLImageUsePOT2D = 1,
	FFGLImagePOTUnknown = 2
};

typedef struct FFGLImagePrivate {
	NSUInteger      imageWidth;
    NSUInteger      imageHeight;
    CGLContextObj   context;
    pthread_mutex_t	conversionLock;
    FFGLImageRep	*texture2D;
    FFGLImageRep	*textureRect;
    FFGLImageRep	*buffer;
	NSUInteger		NPOTRule;
} FFGLImagePrivate;

#define ffglIPrivate(x) ((FFGLImagePrivate *)_private)->x

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
			|| (_private = malloc(sizeof(FFGLImagePrivate))) == NULL
			|| pthread_mutex_init(&ffglIPrivate(conversionLock), NULL) != 0)
		{
            [self release];
            return nil;
        }
        ffglIPrivate(context) = CGLRetainContext(context);
		ffglIPrivate(NPOTRule) = POT;
		
		if (rep->type == FFGLImageRepTypeTexture2D)
		{
			ffglIPrivate(texture2D) = rep;
			ffglIPrivate(textureRect) = ffglIPrivate(buffer) = NULL;
			ffglIPrivate(imageWidth) = rep->repInfo.textureInfo.width;
			ffglIPrivate(imageHeight) = rep->repInfo.textureInfo.height;
		}
		else if (rep->type == FFGLImageRepTypeTextureRect)
		{
			ffglIPrivate(textureRect) = rep;
			ffglIPrivate(texture2D) = ffglIPrivate(buffer) = NULL;
			ffglIPrivate(imageWidth) = rep->repInfo.textureInfo.width;
			ffglIPrivate(imageHeight) = rep->repInfo.textureInfo.height;
		}
		else if (rep->type == FFGLImageRepTypeBuffer)
		{
			ffglIPrivate(buffer) = rep;
			ffglIPrivate(textureRect) = ffglIPrivate(texture2D) = NULL;
			ffglIPrivate(imageWidth) = rep->repInfo.bufferInfo.width;
			ffglIPrivate(imageHeight) = rep->repInfo.bufferInfo.height;
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
    FFGLImageRep *rep = FFGLTextureRepCreateFromTexture(texture, FFGLImageRepTypeTexture2D, imageWidth, imageHeight, textureWidth, textureHeight, isFlipped, callback, userInfo);
    return [self initWithCGLContext:context imageRep:rep usePOT2D:FFGLImagePOTUnknown];
}

- (id)initWithTextureRect:(GLuint)texture CGLContext:(CGLContextObj)context pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height flipped:(BOOL)isFlipped releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseInfo:(void *)userInfo
{
	FFGLImageRep *rep = FFGLTextureRepCreateFromTexture(texture, FFGLImageRepTypeTextureRect, width, height, width, height, isFlipped, callback, userInfo);
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
	if (_private) {
		if (ffglIPrivate(texture2D) != NULL)
			FFGLImageRepDestroy(ffglIPrivate(context), (FFGLImageRep *)ffglIPrivate(texture2D));
		if (ffglIPrivate(textureRect) != NULL)
			FFGLImageRepDestroy(ffglIPrivate(context), (FFGLImageRep *)ffglIPrivate(textureRect));
		if (ffglIPrivate(buffer))
			FFGLImageRepDestroy(ffglIPrivate(context), (FFGLImageRep *)ffglIPrivate(buffer));
		CGLReleaseContext(ffglIPrivate(context));
		pthread_mutex_destroy(&ffglIPrivate(conversionLock));
		free(_private);
	}
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
    return ffglIPrivate(imageWidth);
}

- (NSUInteger)imagePixelsHigh {
    return ffglIPrivate(imageHeight);
}

- (BOOL)useNPOT2D
{
	// always called from within a lock, so no need to lock
	if (ffglIPrivate(NPOTRule) == FFGLImagePOTUnknown)
	{
		ffglIPrivate(NPOTRule) = ffglOpenGLSupportsExtension(ffglIPrivate(context), "GL_ARB_texture_non_power_of_two") ? FFGLImageUseNPOT2D : FFGLImageUsePOT2D;
	}
	return ffglIPrivate(NPOTRule) == FFGLImageUseNPOT2D ? YES : NO;
}

#pragma mark GL_TEXTURE_2D

- (BOOL)lockTexture2DRepresentation {
    BOOL result = NO;
    pthread_mutex_lock(&ffglIPrivate(conversionLock));
    if (ffglIPrivate(texture2D))
    {
		if (ffglIPrivate(texture2D)->flipped == YES)
		{
			// An FFGLImage may be initted with a flipped texture, but we always lock with it not flipped
			// as plugins don't support flipping
			FFGLImageRep *rep = FFGLTextureRepCreateFromTextureRep(ffglIPrivate(context), ffglIPrivate(texture2D), FFGLImageRepTypeTexture2D, [self useNPOT2D]);
			if (rep != NULL)
			{
				FFGLImageRepDestroy(ffglIPrivate(context), ffglIPrivate(texture2D));
				ffglIPrivate(texture2D) = rep;
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
		if (ffglIPrivate(textureRect))
		{
			ffglIPrivate(texture2D) = FFGLTextureRepCreateFromTextureRep(ffglIPrivate(context), ffglIPrivate(textureRect), FFGLImageRepTypeTexture2D, [self useNPOT2D]);
			if (ffglIPrivate(texture2D))
				result = YES;
		}
		else if (ffglIPrivate(buffer))
		{
			BOOL useNPOT2D = [self useNPOT2D];
			ffglIPrivate(texture2D) = FFGLTextureRepCreateFromBufferRep(ffglIPrivate(context), ffglIPrivate(buffer), FFGLImageRepTypeTexture2D, useNPOT2D);
			if (ffglIPrivate(texture2D) == NULL)
			{
				// Buffer->2D creation will fail in some cases, so try buffer->rect->2D
				ffglIPrivate(textureRect) = FFGLTextureRepCreateFromBufferRep(ffglIPrivate(context), ffglIPrivate(buffer), FFGLImageRepTypeTextureRect, useNPOT2D);
				if (ffglIPrivate(textureRect))
				{
					ffglIPrivate(texture2D) = FFGLTextureRepCreateFromTextureRep(ffglIPrivate(context), ffglIPrivate(textureRect), FFGLImageRepTypeTexture2D, useNPOT2D);
				}
			}
			if (ffglIPrivate(texture2D))
			{
				result = YES;
			}
		}
    }
    pthread_mutex_unlock(&ffglIPrivate(conversionLock));
    return result;
}

- (void)unlockTexture2DRepresentation {
    // do nothing
}

- (GLuint)texture2DName
{
    return ffglIPrivate(texture2D)->repInfo.textureInfo.texture;
}

- (NSUInteger)texture2DPixelsWide 
{
    return ffglIPrivate(texture2D)->repInfo.textureInfo.hardwareWidth;
}

- (NSUInteger)texture2DPixelsHigh
{
    return ffglIPrivate(texture2D)->repInfo.textureInfo.hardwareHeight;
}

- (BOOL)texture2DIsFlipped
{
    // currently this will always be NO
    return ffglIPrivate(texture2D)->flipped;
}

- (FFGLTextureInfo *)_texture2DInfo
{
    return &ffglIPrivate(texture2D)->repInfo.textureInfo;
}

#pragma mark GL_TEXTURE_RECTANGLE_EXT

- (BOOL)lockTextureRectRepresentation {
    BOOL result = NO;
    pthread_mutex_lock(&ffglIPrivate(conversionLock));
    if (ffglIPrivate(textureRect))
    {
		result = YES;
    }
    else if (ffglIPrivate(texture2D))
    {
		ffglIPrivate(textureRect) = FFGLTextureRepCreateFromTextureRep(ffglIPrivate(context), ffglIPrivate(texture2D), FFGLImageRepTypeTextureRect, [self useNPOT2D]);
		if (ffglIPrivate(textureRect))
			result = YES;
    }
    else if (ffglIPrivate(buffer))
    {
		ffglIPrivate(textureRect) = FFGLTextureRepCreateFromBufferRep(ffglIPrivate(context), ffglIPrivate(buffer), FFGLImageRepTypeTextureRect, [self useNPOT2D]);
		if (ffglIPrivate(textureRect))
			result = YES;
    }	
    pthread_mutex_unlock(&ffglIPrivate(conversionLock));
    return result;
}

- (void)unlockTextureRectRepresentation
{
    // do nothing
}

- (GLuint)textureRectName
{
    return ffglIPrivate(textureRect)->repInfo.textureInfo.texture;
}

/*
- (NSUInteger)textureRectPixelsWide
{
    return ffglIPrivate(textureRect)->repInfo.textureInfo.hardwareWidth;
}

- (NSUInteger)textureRectPixelsHigh
{
    return ffglIPrivate(textureRect)->repInfo.textureInfo.hardwareHeight;
}
*/

- (BOOL)textureRectIsFlipped
{
    return ffglIPrivate(textureRect)->flipped;
}

#pragma mark Pixel Buffers

- (BOOL)lockBufferRepresentationWithPixelFormat:(NSString *)format {
    BOOL result = NO;
    pthread_mutex_lock(&ffglIPrivate(conversionLock));
    if (ffglIPrivate(buffer))
    {
		if (![format isEqualToString:ffglIPrivate(buffer)->repInfo.bufferInfo.pixelFormat])
		{
			// We don't support converting between different formats (yet?).
		}
		else
		{
			result = YES;
		}
    }
    else if (ffglIPrivate(textureRect))
    {
		ffglIPrivate(buffer) = FFGLBufferRepCreateFromTextureRep(ffglIPrivate(context), ffglIPrivate(textureRect), format);
		if (ffglIPrivate(buffer))
			result = YES;
    }
	else if (ffglIPrivate(texture2D))
	{
		ffglIPrivate(buffer) = FFGLBufferRepCreateFromTextureRep(ffglIPrivate(context), ffglIPrivate(texture2D), format);
		if (ffglIPrivate(buffer) == NULL)
		{
			// Buffer creation from 2D textures fails if it would involve a buffer copy stage.
			// In such cases, create a rect texture, then create the buffer from that.
			ffglIPrivate(textureRect) = FFGLTextureRepCreateFromTextureRep(ffglIPrivate(context), ffglIPrivate(texture2D), FFGLImageRepTypeTextureRect, [self useNPOT2D]);
			if (ffglIPrivate(textureRect))
			{
				ffglIPrivate(buffer) = FFGLBufferRepCreateFromTextureRep(ffglIPrivate(context), ffglIPrivate(textureRect), format);
			}
		}
		if (ffglIPrivate(buffer))
			result = YES;
	}
    pthread_mutex_unlock(&ffglIPrivate(conversionLock));
    return result;
}

- (void)unlockBufferRepresentation
{
    // Do nothing.
}

- (const void *)bufferBaseAddress
{
    return ffglIPrivate(buffer)->repInfo.bufferInfo.buffer;
}

/* Deprecated already
- (NSUInteger)bufferPixelsWide
{
    return ffglIPrivate(imageWidth); // our buffers are never padded.
}

- (NSUInteger)bufferPixelsHigh
{
    return ffglIPrivate(imageHeight); // our buffers are never padded.
}
*/

- (NSUInteger)bufferBytesPerRow
{
    return ffglIPrivate(imageWidth) * ffglBytesPerPixelForPixelFormat(ffglIPrivate(buffer)->repInfo.bufferInfo.pixelFormat);
}

- (NSString *)bufferPixelFormat
{
    return ffglIPrivate(buffer)->repInfo.bufferInfo.pixelFormat;
}

- (BOOL)bufferIsFlipped
{
    return ffglIPrivate(buffer)->flipped;
}
@end
