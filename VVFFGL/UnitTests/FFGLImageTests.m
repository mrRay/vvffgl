//
//  FFGLImageTests.m
//  VVFFGL
//
//  Created by Tom on 29/01/2010.
//  Copyright 2010 Tom Butterworth. All rights reserved.
//

#import "FFGLImageTests.h"
#import <OpenGL/CGLMacro.h>
#import "FFGLGLState.h"

#define kFFGLImageTestWidth 100
#define kFFGLImageTestHeight 33
#define kFFGLImageTestBytesPerPixel 4
#define kFFPixelFormat FFGLPixelFormatBGRA8888

static void FFGLImageTestBufferCallback(const void *baseAddress, void *userInfo)
{
	// Do nothing, we free the buffer in tearDown
}

void FFGLImageTestTextureReleaseCallback(GLuint name, CGLContextObj cgl_ctx, void *userInfo) {
	// Destroy or recycle your texture and any associated resources.
	[(FFGLImage *)userInfo unlockTexture2DRepresentation];
	[(FFGLImage *)userInfo release];
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
	GLStateRef before = GLStateCreateForContext(_CGLContext);
	STAssertTrue([_image lockTexture2DRepresentation], @"FFGLImage couldn't lockTexture2DRepresentation");
	GLStateRef after = GLStateCreateForContext(_CGLContext);
	STAssertTrue(GLStatesAreEqual(before, after), @"OpenGL state changed after call to lockTexture2DRepresentation");
	[_image unlockTexture2DRepresentation];
	GLStateRelease(before);
	GLStateRelease(after);
}

- (void)testRectTextureCreationFromBuffer
{
	GLStateRef before = GLStateCreateForContext(_CGLContext);
	STAssertTrue([_image lockTextureRectRepresentation], @"FFGLImage couldn't lockTextureRectRepresentation");
	GLStateRef after = GLStateCreateForContext(_CGLContext);
	STAssertTrue(GLStatesAreEqual(before, after), @"OpenGL state changed after call to lockTextureRectRepresentation");
	[_image unlockTextureRectRepresentation];
	GLStateRelease(before);
	GLStateRelease(after);
}

- (void)test2DToRectTextureCopy
{
	if ([_image lockTexture2DRepresentation])
	{
		[_image retain];
		FFGLImage *copied = [[[FFGLImage alloc] initWithTexture2D:[_image texture2DName]
													   CGLContext:_CGLContext
												  imagePixelsWide:[_image imagePixelsWide]
												  imagePixelsHigh:[_image imagePixelsHigh]
												texturePixelsWide:[_image texture2DPixelsWide]
												texturePixelsHigh:[_image texture2DPixelsHigh]
														  flipped:[_image texture2DIsFlipped]
												  releaseCallback:FFGLImageTestTextureReleaseCallback
													  releaseInfo:_image] autorelease];
		GLStateRef before = GLStateCreateForContext(_CGLContext);
		STAssertTrue([copied lockTextureRectRepresentation], @"FFGLImage couldn't lockTextureRectRepresentation from texture2D");
		GLStateRef after = GLStateCreateForContext(_CGLContext);
		GLenum *changed = malloc(GLStatesGetChangedEnumArrayMaximumCount() * sizeof(GLenum));
		unsigned int changeCount;
		GLStatesUnequalStates(before, after, changed, &changeCount);
		for (int i = 0; i < changeCount; i++) {
			STAssertFalse(YES, @"OpenGL state 0x%x changed after call to lockTextureRectRepresentation.", changed[i]);
		}
		free(changed);
		GLStateRelease(before);
		GLStateRelease(after);
	}
}

- (void)testBufferToTextureToBuffer
{
	uint8_t *originalBuffer = valloc(kFFGLImageTestBytesPerPixel * kFFGLImageTestWidth * kFFGLImageTestHeight);
	unsigned int offset = 0;
	for (unsigned int y = 0; y < kFFGLImageTestHeight; y++) {
		for (unsigned int x = 0; x < kFFGLImageTestWidth; x++) {
			originalBuffer[offset] = 55;	// blue
			originalBuffer[offset+1] = 180; // green
			originalBuffer[offset+2] = 10;  // red
			originalBuffer[offset+3] = 255; // alpha
			offset += kFFGLImageTestBytesPerPixel;
		}
	}
	FFGLImage *original = [[FFGLImage alloc] initWithBuffer:originalBuffer
												 CGLContext:_CGLContext
												pixelFormat:kFFPixelFormat
												 pixelsWide:kFFGLImageTestWidth
												 pixelsHigh:kFFGLImageTestHeight
												bytesPerRow:kFFGLImageTestWidth * kFFGLImageTestBytesPerPixel
													flipped:NO
											releaseCallback:NULL
												releaseInfo:NULL];
	
	STAssertTrue([original lockTexture2DRepresentation], @"Couldn't lockTexture2DRepresentation");

	
	NSString *formats[4] = {
		FFGLPixelFormatARGB8888,
		FFGLPixelFormatBGRA8888,
		FFGLPixelFormatRGB888,
		FFGLPixelFormatBGR888
	};
	unsigned int pixelByteArray[4] = { 4,4,3,3 };
	unsigned int rIndex[4] = { 1,2,0,2 };
	unsigned int gIndex[4] = { 2,1,1,1 };
	unsigned int bIndex[4] = { 3,0,2,0 };
	
	for (int i = 0; i < 4; i++) {
		FFGLImage *copy = [[FFGLImage alloc] initWithTexture2D:[original texture2DName]
													CGLContext:_CGLContext
											   imagePixelsWide:[original imagePixelsWide]
											   imagePixelsHigh:[original imagePixelsHigh]
											 texturePixelsWide:[original texture2DPixelsWide]
											 texturePixelsHigh:[original texture2DPixelsHigh]
													   flipped:[original texture2DIsFlipped]
											   releaseCallback:NULL
												   releaseInfo:NULL];
		STAssertTrue([copy lockBufferRepresentationWithPixelFormat:formats[i]], @"Couldn't lockBufferRepresentation for pixel-format %@", formats[i]);
		uint8_t *copiedBuffer = (uint8_t *)[copy bufferBaseAddress];
		STAssertTrue([copy imagePixelsWide] == kFFGLImageTestWidth, @"Width changed.");
		STAssertTrue([copy imagePixelsHigh] == kFFGLImageTestHeight, @"Height changed.");
		STAssertTrue([copy bufferBytesPerRow] == kFFGLImageTestWidth * pixelByteArray[i], @"Bytes per pixel not as expected");
		unsigned int copyOffset = 0;
		unsigned int origOffset = 0;
		BOOL changed = NO;
		for (unsigned int y = 0; y < kFFGLImageTestHeight; y++) {
			for (unsigned int x = 0; x < kFFGLImageTestWidth; x++) {
				if (copiedBuffer[copyOffset + bIndex[i]] != originalBuffer[origOffset]
					|| copiedBuffer[copyOffset + gIndex[i]] != originalBuffer[origOffset + 1]
					|| copiedBuffer[copyOffset + rIndex[i]] != originalBuffer[origOffset + 2])
				{
					changed = YES;
				}
				copyOffset += pixelByteArray[i];
				origOffset += kFFGLImageTestBytesPerPixel;
			}
		}
		STAssertFalse(changed, @"Buffer changed for format %@. First pixel R was %u is %u G was %u is %u B was %u is %u A was %u ", formats[i],
					  (unsigned int)originalBuffer[2], (unsigned int)copiedBuffer[rIndex[i]],
					  (unsigned int)originalBuffer[1], (unsigned int)copiedBuffer[gIndex[i]],
					  (unsigned int)originalBuffer[0], (unsigned int)copiedBuffer[bIndex[i]],
					  (unsigned int)originalBuffer[3]);
		[copy unlockBufferRepresentation];
		[copy release];
	}

	[original unlockTexture2DRepresentation];
	[original release];
	free(originalBuffer);
}
@end
