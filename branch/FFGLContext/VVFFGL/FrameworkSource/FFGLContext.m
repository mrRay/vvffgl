//
//  FFGLContext.m
//  VVFFGL
//
//  Created by Tom on 12/11/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "FFGLContext.h"
#import <libkern/OSAtomic.h>
#import "FFGLInternal.h"
#import "FFGLPool.h"

#if defined(FFGL_USE_BUFFER_POOLS)

static const void *FFGLContextBufferCreate(const void *userInfo)
{
	return valloc(*(size_t *)userInfo);
}

static void FFGLContextBufferDestroy(const void *baseAddress, const void* context)
{
    free((void *)baseAddress);
}

#endif

struct FFGLContextPrivate
{
	CGLContextObj	context;
	NSString		*pixelFormat;
	NSSize			size;
	size_t			bytesPerBuffer;
	FFGLPoolRef		pool;
	OSSpinLock		poolLock;
};

@implementation FFGLContext

- (id)initWithCGLContext:(CGLContextObj)context pixelFormat:(NSString *)pixelFormat size:(NSSize)size
{
    if (self = [super init]) {
        _priv = malloc(sizeof(FFGLContextPrivate));
		if (_priv)
		{
#if defined(FFGL_USE_PRIVATE_CONTEXT)
			CGLContextObj cgl_ctx;
			CGLCreateContext(CGLGetPixelFormat(context), context, &cgl_ctx);
			GLint paramValue = 1;
			CGLSetParameter(cgl_ctx, kCGLCPSwapInterval, &paramValue);
			_priv->context = cgl_ctx;
#else
			CGLRetainContext(context);
			_priv->context = context;
#endif
			_priv->pixelFormat = [pixelFormat retain];
			_priv->size.width = size.width;
			_priv->size.height = size.height;
			_priv->pool = NULL;
			_priv->poolLock = OS_SPINLOCK_INIT;
			if (_priv->context == NULL)
			{
				[self release];
				return nil;
			}
#if defined(FFGL_USE_PRIVATE_CONTEXT)
			CGLContextObj previousContext = CGLGetCurrentContext();
			CGLSetCurrentContext(cgl_ctx);
			CGLLockContext(cgl_ctx);
			// set up viewport/projection matrices and coordinate system for FBO target.
			// Not sure if we want our own dimensions or _textureWidth, _textureHeight here?
			// Guessing this is right with our dimensions.
			glViewport(0, 0, size.width, size.height);
			CGLUnlockContext(cgl_ctx);
			CGLSetCurrentContext(previousContext);
#endif
		}
		else
		{
			[self release];
			return nil;
		}
    }
    return self;
}

- (void)releaseResources
{
	if (_priv)
	{
		CGLReleaseContext(_priv->context);
		[_priv->pixelFormat release];
		free(_priv);
	}
}

- (void)dealloc
{
	[self releaseResources];
	[super dealloc];
}

- (void)finalize
{
	[self releaseResources];
	[super finalize];
}

#if defined(FFGL_USE_BUFFER_POOLS)
- (FFGLPoolRef)_bufferPool
{
	OSSpinLockLock(&_priv->poolLock);
	if (_priv->pool == NULL)
	{
		size_t bytesPerRow;
#if __BIG_ENDIAN__
		if ([_priv->pixelFormat isEqualToString:FFGLPixelFormatRGB565]) { bytesPerRow = 2 * _priv->size.width; }
		else if ([_priv->pixelFormat isEqualToString:FFGLPixelFormatRGB888]) { bytesPerRow = 3 * _priv->size.width; }
		else if ([_priv->pixelFormat isEqualToString:FFGLPixelFormatARGB8888]) { bytesPerRow = 4 * _priv->size.width; }
#else
		if ([_priv->pixelFormat isEqualToString:FFGLPixelFormatBGR565]) { bytesPerRow = 2 * _priv->size.width; }
		else if ([_priv->pixelFormat isEqualToString:FFGLPixelFormatBGR888]) { bytesPerRow = 3 * _priv->size.width; }
		else if ([_priv->pixelFormat isEqualToString:FFGLPixelFormatBGRA8888]) { bytesPerRow = 4 * _priv->size.width; }
#endif
		else {
			[NSException raise:@"FFGLContextException" format:@"Unexpected pixel format."];
		}
		_priv->bytesPerBuffer = bytesPerRow * _priv->size.height;
		FFGLPoolCallBacks callbacks = {FFGLContextBufferCreate, FFGLContextBufferDestroy};
		_priv->pool = FFGLPoolCreate(&callbacks, 10, &_priv->bytesPerBuffer);
	}
	OSSpinLockUnlock(&_priv->poolLock);
	return _priv->pool;
}
#endif /* FFGL_USE_BUFFER_POOLS */

- (CGLContextObj)CGLContextObj
{
	return _priv->context;
}

- (NSString *)pixelFormat
{
	return _priv->pixelFormat;
}

- (NSSize)size
{
	return _priv->size;
}
@end
