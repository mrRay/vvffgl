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
#import "FFGLTextureRep.h"
#import "FFGLBufferRep.h"
#import <pthread.h>
#import <OpenGL/CGLMacro.h>

/*
	We currently check for NPOT 2D support once per FFGLImage. It would be more efficient to do this once
	per CGLContext...
 */

typedef unsigned int FFGLImagePOT2DRule;
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
    FFGLTextureRep	*texture2D;
    FFGLTextureRep	*textureRect;
    FFGLBufferRep	*buffer;
	unsigned int	NPOTRule;
} FFGLImagePrivate;

#define ffglIPrivate(x) ((FFGLImagePrivate *)_private)->x

@interface FFGLImage (Private)
- (id)initWithCGLContext:(CGLContextObj)context retainedImageRep:(FFGLImageRep *)rep usePOT2D:(FFGLImagePOT2DRule)POT;
- (void)releaseResources;
- (BOOL)useNPOT2D;
@end

@implementation FFGLImage

/*
 Our private designated initializer
 */

- (id)initWithCGLContext:(CGLContextObj)context retainedImageRep:(FFGLImageRep *)rep usePOT2D:(FFGLImagePOT2DRule)POT
{
    if (self = [super init]) {
        if (rep == nil
			|| (_private = malloc(sizeof(FFGLImagePrivate))) == NULL
			|| pthread_mutex_init(&ffglIPrivate(conversionLock), NULL) != 0)
		{
            [self release];
            return nil;
        }
        ffglIPrivate(context) = CGLRetainContext(context);
		ffglIPrivate(NPOTRule) = POT;
				
		if (rep.type == FFGLImageRepTypeTexture2D)
		{
			ffglIPrivate(texture2D) = ((FFGLTextureRep *)rep);
			ffglIPrivate(textureRect) = nil;
			ffglIPrivate(buffer) = nil;
			ffglIPrivate(imageWidth) = ((FFGLTextureRep *)rep).textureInfo->width;
			ffglIPrivate(imageHeight) = ((FFGLTextureRep *)rep).textureInfo->height;
		}
		else if (rep.type == FFGLImageRepTypeTextureRect)
		{
			ffglIPrivate(textureRect) = ((FFGLTextureRep *)rep);
			ffglIPrivate(texture2D) = nil;
			ffglIPrivate(buffer) = nil;
			ffglIPrivate(imageWidth) = ((FFGLTextureRep *)rep).textureInfo->width;
			ffglIPrivate(imageHeight) = ((FFGLTextureRep *)rep).textureInfo->height;
		}
		else if (rep.type == FFGLImageRepTypeBuffer)
		{
			ffglIPrivate(buffer) = ((FFGLBufferRep *)rep);
			ffglIPrivate(textureRect) = ffglIPrivate(texture2D) = NULL;
			ffglIPrivate(imageWidth) = ((FFGLBufferRep *)rep).imageWidth;
			ffglIPrivate(imageHeight) = ((FFGLBufferRep *)rep).imageHeight;
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
	FFGLTextureRep *rep = [[FFGLTextureRep alloc] initWithTexture:texture
														  context:context
														   ofType:FFGLImageRepTypeTexture2D
													   imageWidth:imageWidth imageHeight:imageHeight
													 textureWidth:textureWidth textureHeight:textureHeight
														isFlipped:isFlipped
														 callback:callback userInfo:userInfo
													 asPrimaryRep:YES];
    return [self initWithCGLContext:context retainedImageRep:rep usePOT2D:FFGLImagePOTUnknown];
}

- (id)initWithTextureRect:(GLuint)texture CGLContext:(CGLContextObj)context pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height flipped:(BOOL)isFlipped releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseInfo:(void *)userInfo
{
	FFGLTextureRep *rep = [[FFGLTextureRep alloc] initWithTexture:texture
														  context:context
														   ofType:FFGLImageRepTypeTextureRect
													   imageWidth:width
													  imageHeight:height
													 textureWidth:width
													textureHeight:height
														isFlipped:isFlipped
														 callback:callback
														 userInfo:userInfo
													 asPrimaryRep:YES];
    return [self initWithCGLContext:context retainedImageRep:rep usePOT2D:FFGLImagePOTUnknown];
}

- (id)initWithBuffer:(const void *)buffer CGLContext:(CGLContextObj)context pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes flipped:(BOOL)isFlipped releaseCallback:(FFGLImageBufferReleaseCallback)callback releaseInfo:(void *)userInfo
{
	FFGLBufferRep *rep = [[FFGLBufferRep alloc] initWithBuffer:buffer
														 width:width
														height:height
												   bytesPerRow:rowBytes
												   pixelFormat:format
													 isFlipped:isFlipped
													  callback:callback
													  userInfo:userInfo
												  asPrimaryRep:YES];
    return [self initWithCGLContext:context retainedImageRep:rep usePOT2D:FFGLImagePOTUnknown];
}

- (id)initWithCopiedTextureRect:(GLuint)texture CGLContext:(CGLContextObj)context pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height flipped:(BOOL)isFlipped
{
	CGLLockContext(context);
#if defined(FFGL_ALLOW_NPOT_2D)
	BOOL useNPOT = ffglOpenGLSupportsExtension(context, "GL_ARB_texture_non_power_of_two");
	FFGLImagePOT2DRule POTRule = useNPOT ? FFGLImageUseNPOT2D : FFGLImageUsePOT2D;
#else
	BOOL useNPOT = NO;
	FFGLImagePOT2DRule POTRule = FFGLImageUsePOT2D;
#endif
    // copy to 2D to save doing it when images get used by a renderer.	
	FFGLTextureRep *rep = [[FFGLTextureRep alloc] initCopyingTexture:texture
															  ofType:FFGLImageRepTypeTextureRect
															 context:context
														  imageWidth:width
														 imageHeight:height
														textureWidth:width
													   textureHeight:height
														   isFlipped:isFlipped
															  toType:FFGLImageRepTypeTexture2D
														allowingNPOT:useNPOT
														asPrimaryRep:YES];
	CGLUnlockContext(context);
    return [self initWithCGLContext:context retainedImageRep:rep usePOT2D:POTRule];
}

- (id)initWithCopiedTexture2D:(GLuint)texture CGLContext:(CGLContextObj)context imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight texturePixelsWide:(NSUInteger)textureWidth texturePixelsHigh:(NSUInteger)textureHeight flipped:(BOOL)isFlipped
{
	CGLLockContext(context);
#if defined(FFGL_ALLOW_NPOT_2D)
	BOOL useNPOT = ffglOpenGLSupportsExtension(context, "GL_ARB_texture_non_power_of_two");
	FFGLImagePOT2DRule POTRule = useNPOT ? FFGLImageUseNPOT2D : FFGLImageUsePOT2D;
#else
	BOOL useNPOT = NO;
	FFGLImagePOT2DRule POTRule = FFGLImageUsePOT2D;
#endif
	
	FFGLTextureRep *rep = [[FFGLTextureRep alloc] initCopyingTexture:texture
															  ofType:FFGLImageRepTypeTexture2D
															 context:context
														  imageWidth:imageWidth imageHeight:imageHeight
														textureWidth:textureWidth textureHeight:textureHeight
														   isFlipped:isFlipped
															  toType:FFGLImageRepTypeTexture2D
														allowingNPOT:useNPOT
														asPrimaryRep:YES];
	CGLUnlockContext(context);
    return [self initWithCGLContext:context retainedImageRep:rep usePOT2D:POTRule];
}

- (id)initWithCopiedBuffer:(const void *)buffer CGLContext:(CGLContextObj)context pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes flipped:(BOOL)isFlipped
{
	FFGLBufferRep *rep = [[FFGLBufferRep alloc] initWithCopiedBuffer:buffer
															   width:width height:height
														 bytesPerRow:rowBytes
														 pixelFormat:format
														   isFlipped:isFlipped
														asPrimaryRep:YES];
    return [self initWithCGLContext:context retainedImageRep:rep usePOT2D:FFGLImagePOTUnknown];
}

- (void)releaseResources 
{
	if (_private) {
		// Texture callbacks may not be using CGL macros, so switch to the context and lock it.
		CGLContextObj prevContext;
		ffglSetContext(ffglIPrivate(context), prevContext);
		CGLLockContext(ffglIPrivate(context));
		
		[ffglIPrivate(texture2D) performCallbackPriorToRelease];
		[ffglIPrivate(textureRect) performCallbackPriorToRelease];
		
		// Restore context
		CGLUnlockContext(ffglIPrivate(context));
		ffglRestoreContext(ffglIPrivate(context), prevContext);
		
		CGLReleaseContext(ffglIPrivate(context));
		pthread_mutex_destroy(&ffglIPrivate(conversionLock));
		free(_private);
	}
}

- (void)dealloc {
	[self releaseResources];
	[ffglIPrivate(texture2D) release];
	[ffglIPrivate(textureRect) release];
	[ffglIPrivate(buffer) release];
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
#if defined(FFGL_ALLOW_NPOT_2D)
	if (ffglIPrivate(NPOTRule) == FFGLImagePOTUnknown)
	{
		ffglIPrivate(NPOTRule) = ffglOpenGLSupportsExtension(ffglIPrivate(context), "GL_ARB_texture_non_power_of_two") ? FFGLImageUseNPOT2D : FFGLImageUsePOT2D;
	}
	return ffglIPrivate(NPOTRule) == FFGLImageUseNPOT2D ? YES : NO;
#else
	return NO;
#endif
}

#pragma mark GL_TEXTURE_2D

- (BOOL)lockTexture2DRepresentation {
    pthread_mutex_lock(&ffglIPrivate(conversionLock));
	BOOL result = NO;
    if (ffglIPrivate(texture2D))
    {
		if (ffglIPrivate(texture2D).isFlipped == YES)
		{
			// An FFGLImage may be initted with a flipped texture, but we always lock with it not flipped
			// as plugins don't support flipping
			
			CGLLockContext(ffglIPrivate(context));
			
			FFGLTextureRep *rep = [ffglIPrivate(texture2D) copyAsType:FFGLImageRepTypeTexture2D
														  pixelFormat:nil
															inContext:ffglIPrivate(context)
													   allowingNPOT2D:[self useNPOT2D]
														 asPrimaryRep:YES];

			if (rep != nil)
			{
				// Set the context over release in case the callbacks don't use CGL macros
				CGLContextObj prevContext;
				ffglSetContext(ffglIPrivate(context), prevContext);
				
				[ffglIPrivate(texture2D) performCallbackPriorToRelease];
				
				// Restore the context
				ffglRestoreContext(ffglIPrivate(context), prevContext);
				
				// Swap our right-way-up texture in
				[ffglIPrivate(texture2D) release];
				ffglIPrivate(texture2D) = rep;
				result = YES;
			}
			
			CGLUnlockContext(ffglIPrivate(context));
		}
		else
		{
			result = YES;
		}
    }
    else if (ffglIPrivate(textureRect))
	{
		CGLLockContext(ffglIPrivate(context));		

		ffglIPrivate(texture2D) = [ffglIPrivate(textureRect) copyAsType:FFGLImageRepTypeTexture2D
															pixelFormat:nil
															  inContext:ffglIPrivate(context)
														 allowingNPOT2D:[self useNPOT2D]
														   asPrimaryRep:NO];

		CGLUnlockContext(ffglIPrivate(context));

		if (ffglIPrivate(texture2D))
		{
			result = YES;
		}
	}
	else if (ffglIPrivate(buffer))
	{
		CGLLockContext(ffglIPrivate(context));		
		ffglIPrivate(texture2D) = [ffglIPrivate(buffer) copyAsType:FFGLImageRepTypeTexture2D
													   pixelFormat:nil
														 inContext:ffglIPrivate(context)
													allowingNPOT2D:[self useNPOT2D]
													  asPrimaryRep:NO];
		CGLUnlockContext(ffglIPrivate(context));

		if (ffglIPrivate(texture2D))
		{
			result = YES;
		}
	}
	
	[ffglIPrivate(texture2D) addSubscriber];
    pthread_mutex_unlock(&ffglIPrivate(conversionLock));
    return result;
}



- (void)unlockTexture2DRepresentation {
	pthread_mutex_lock(&ffglIPrivate(conversionLock));
    if ([ffglIPrivate(texture2D) removeSubscriber] == 0
		&& !(ffglIPrivate(texture2D).isPrimaryRep))
	{
		CGLLockContext(ffglIPrivate(context));
		// No need to set the context as a non-primary rep is one of ours using CGLMacros
		[ffglIPrivate(texture2D) release];
		CGLUnlockContext(ffglIPrivate(context));
		ffglIPrivate(texture2D) = nil;
	}
	pthread_mutex_unlock(&ffglIPrivate(conversionLock));
}

- (GLuint)texture2DName
{
    return ffglIPrivate(texture2D).textureInfo->texture;
}

- (NSUInteger)texture2DPixelsWide 
{
    return ffglIPrivate(texture2D).textureInfo->hardwareWidth;
}

- (NSUInteger)texture2DPixelsHigh
{
    return ffglIPrivate(texture2D).textureInfo->hardwareHeight;
}

- (BOOL)texture2DIsFlipped
{
    // currently this will always be NO
    return ffglIPrivate(texture2D).isFlipped;
}

- (FFGLTextureInfo *)_texture2DInfo
{
    return ffglIPrivate(texture2D).textureInfo;
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
		CGLLockContext(ffglIPrivate(context));
		ffglIPrivate(textureRect) = [ffglIPrivate(texture2D) copyAsType:FFGLImageRepTypeTextureRect
															pixelFormat:nil
															  inContext:ffglIPrivate(context)
														 allowingNPOT2D:[self useNPOT2D]
														   asPrimaryRep:NO];
		CGLUnlockContext(ffglIPrivate(context));
		if (ffglIPrivate(textureRect))
		{
			result = YES;
		}
    }
    else if (ffglIPrivate(buffer))
    {
		CGLLockContext(ffglIPrivate(context));
		ffglIPrivate(textureRect) = [ffglIPrivate(buffer) copyAsType:FFGLImageRepTypeTextureRect
														 pixelFormat:nil
														   inContext:ffglIPrivate(context)
													  allowingNPOT2D:[self useNPOT2D]
														asPrimaryRep:NO];
		CGLUnlockContext(ffglIPrivate(context));
		if (ffglIPrivate(textureRect))
		{
			result = YES;
		}
    }
	[ffglIPrivate(textureRect) addSubscriber];
    pthread_mutex_unlock(&ffglIPrivate(conversionLock));
    return result;
}

- (void)unlockTextureRectRepresentation
{
    pthread_mutex_lock(&ffglIPrivate(conversionLock));
	if ([ffglIPrivate(textureRect) removeSubscriber] == 0
		&& !(ffglIPrivate(textureRect).isPrimaryRep))
	{
		CGLLockContext(ffglIPrivate(context));
		// No need to set the context as a non-primary rep is one of ours using CGLMacros
		[ffglIPrivate(textureRect) release];
		CGLUnlockContext(ffglIPrivate(context));
		ffglIPrivate(textureRect) = nil;
	}
	pthread_mutex_unlock(&ffglIPrivate(conversionLock));
}

- (GLuint)textureRectName
{
    return ffglIPrivate(textureRect).textureInfo->texture;
}

- (BOOL)textureRectIsFlipped
{
    return ffglIPrivate(textureRect).isFlipped;
}

#pragma mark Pixel Buffers

- (BOOL)lockBufferRepresentationWithPixelFormat:(NSString *)format {
    BOOL result = NO;
    pthread_mutex_lock(&ffglIPrivate(conversionLock));
	// We don't support converting between different pixel-formats (yet?).
    if (ffglIPrivate(buffer) && ![format isEqualToString:ffglIPrivate(buffer).pixelFormat])
    {
		if (ffglIPrivate(buffer).isFlipped == YES)
		{
			// We may have been initted with a flipped buffer. We turn it the right way up now.
			
			FFGLBufferRep *rep = [ffglIPrivate(buffer) copyAsType:FFGLImageRepTypeBuffer
													  pixelFormat:ffglIPrivate(buffer).pixelFormat
														inContext:NULL
												   allowingNPOT2D:NO
													 asPrimaryRep:YES];
			if (rep != nil)
			{
				// Swap our new buffer in
				[ffglIPrivate(buffer) release];
				ffglIPrivate(buffer) = rep;
				result = YES;
			}
		}
		else
		{
			result = YES;
		}
    }
    else if (ffglIPrivate(textureRect))
    {
		CGLLockContext(ffglIPrivate(context));
		
		ffglIPrivate(buffer) = [ffglIPrivate(textureRect) copyAsType:FFGLImageRepTypeBuffer
														 pixelFormat:format
														   inContext:ffglIPrivate(context)
													  allowingNPOT2D:[self useNPOT2D]
														asPrimaryRep:NO];		
		CGLUnlockContext(ffglIPrivate(context));
		
		if (ffglIPrivate(buffer))
		{
			result = YES;
		}
    }
	else if (ffglIPrivate(texture2D))
	{
		CGLLockContext(ffglIPrivate(context));
		
		ffglIPrivate(buffer) = [ffglIPrivate(texture2D) copyAsType:FFGLImageRepTypeBuffer
													   pixelFormat:format
														 inContext:ffglIPrivate(context)
													allowingNPOT2D:[self useNPOT2D]
													  asPrimaryRep:NO];
		
		CGLUnlockContext(ffglIPrivate(context));
		
		if (ffglIPrivate(buffer))
		{
			result = YES;
		}		
	}
	[ffglIPrivate(buffer) addSubscriber];
    pthread_mutex_unlock(&ffglIPrivate(conversionLock));
    return result;
}

- (void)unlockBufferRepresentation
{
	pthread_mutex_lock(&ffglIPrivate(conversionLock));
    if ([ffglIPrivate(buffer) removeSubscriber] == 0
		&& !(ffglIPrivate(buffer).isPrimaryRep))
	{
		[ffglIPrivate(buffer) release];
		ffglIPrivate(buffer) = nil;
	}
	pthread_mutex_unlock(&ffglIPrivate(conversionLock));
}

- (const void *)bufferBaseAddress
{
    return ffglIPrivate(buffer).baseAddress;
}

- (NSUInteger)bufferBytesPerRow
{
    return ffglIPrivate(imageWidth) * ffglBytesPerPixelForPixelFormat(ffglIPrivate(buffer).pixelFormat);
}

- (NSString *)bufferPixelFormat
{
    return ffglIPrivate(buffer).pixelFormat;
}

- (BOOL)bufferIsFlipped
{
    return ffglIPrivate(buffer).isFlipped;
}
@end
