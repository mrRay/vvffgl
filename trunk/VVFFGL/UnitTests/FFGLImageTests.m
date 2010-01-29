//
//  FFGLImageTests.m
//  VVFFGL
//
//  Created by Tom on 29/01/2010.
//  Copyright 2010 Tom Butterworth. All rights reserved.
//

#import "FFGLImageTests.h"
#import <OpenGL/CGLMacro.h>

#define kFFGLImageTestWidth 1024
#define kFFGLImageTestHeight 768
#define kFFGLImageTestBytesPerPixel 4
#if __BIG_ENDIAN__
#define kFFPixelFormat FFGLPixelFormatARGB8888
#else
#define kFFPixelFormat FFGLPixelFormatBGRA8888
#endif

static void FFGLImageTestBufferCallback(const void *baseAddress, void *userInfo)
{
	// Do nothing, we free the buffer in tearDown
}

@implementation FFGLImageTests

- (void) setUp
{
    // Called before each test. Create data structures here.

	_pixelBuffer = valloc(kFFGLImageTestBytesPerPixel * kFFGLImageTestWidth * kFFGLImageTestHeight);
	_image = nil;
	_CGLContext = NULL;
	
	CGLPixelFormatAttribute attribs[] =
	{
		kCGLPFAAccelerated,
		kCGLPFAColorSize, 24,
		kCGLPFADepthSize, 16,
		kCGLPFADoubleBuffer,
		0
	};
	
	CGLPixelFormatObj pixelFormatObj;
	GLint numPixelFormats;
	
	CGLChoosePixelFormat (attribs, &pixelFormatObj, &numPixelFormats);
	
	if( pixelFormatObj != NULL ) {
		CGLCreateContext(pixelFormatObj, NULL, &_CGLContext);
		if (_CGLContext != NULL)
		{
			_image = [[FFGLImage alloc] initWithBuffer:_pixelBuffer
											CGLContext:_CGLContext
										   pixelFormat:kFFPixelFormat
											pixelsWide:kFFGLImageTestWidth
											pixelsHigh:kFFGLImageTestHeight
										   bytesPerRow:kFFGLImageTestBytesPerPixel * kFFGLImageTestWidth
											   flipped:NO
									   releaseCallback:FFGLImageTestBufferCallback
										   releaseInfo:NULL];
		
		}
		CGLReleasePixelFormat(pixelFormatObj);
	}
}

- (void) tearDown
{
    // Called after each test. Release data structures here.
	[_image release];
	_image = nil;
	CGLReleaseContext(_CGLContext);
	_CGLContext = nil;
	free(_pixelBuffer);
	_pixelBuffer = NULL;
}

- (void)testImageCreationFromBuffer
{
	STAssertNotNil(_image, @"FFGLImage couldn't be created from a buffer");
}

- (void)test2DTextureCreationFromBuffer
{
	STAssertTrue([_image lockTexture2DRepresentation], @"FFGLImage couldn't lockTexture2DRepresentation");
	[_image unlockTexture2DRepresentation];
}

- (void)testRectTextureCreationFromBuffer
{
	STAssertTrue([_image lockTextureRectRepresentation], @"FFGLImage couldn't lockTextureRectRepresentation");
	[_image unlockTextureRectRepresentation];
}
@end
