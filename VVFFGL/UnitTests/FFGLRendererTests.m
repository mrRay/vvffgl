//
//  FFGLRendererTests.m
//  VVFFGL
//
//  Created by Tom on 30/01/2010.
//  Copyright 2010 Tom Butterworth. All rights reserved.
//

#import "FFGLRendererTests.h"
#import "FFGLGLState.h"

#define kFFGLTestWidth 1024
#define kFFGLTestHeight 768
#define kFFGLTestBytesPerPixel 4
#if __BIG_ENDIAN__
#define kFFPixelFormat FFGLPixelFormatARGB8888
#else
#define kFFPixelFormat FFGLPixelFormatBGRA8888
#endif

@implementation FFGLRendererTests
- (void) setUp
{
    // Called before each test. Create data structures here.
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
		CGLReleasePixelFormat(pixelFormatObj);
		NSArray *plugins = [[FFGLPluginManager sharedManager] sourcePlugins];
		FFGLPlugin *next, *source;
		source = nil;
		for (next in plugins) {
			if ([next mode] == FFGLPluginModeGPU && ![[[next attributes] objectForKey:FFGLPluginAttributeNameKey] isEqualToString:@"Feedback"])
			{
				source = next;
				break;
			}
		}

		if (source)
		{
			_renderer = [[FFGLRenderer alloc] initWithPlugin:source
													 context:_CGLContext
												 pixelFormat:kFFPixelFormat
												  outputHint:FFGLRendererHintNone
														size:NSMakeSize(kFFGLTestWidth, kFFGLTestHeight)];
		}
	}
}

- (void) tearDown
{
    // Called after each test. Release data structures here.
	[_renderer release];
	_renderer = nil;
	CGLReleaseContext(_CGLContext);
	_CGLContext = nil;
}

- (void)testInstantiation
{
	STAssertNotNil(_renderer, @"Couldn't create FFGLRenderer instance (maybe you have no plugins installed).");
}

- (void)testRenderingStatePreservation
{
	GLStateRef before = GLStateCreateForContext(_CGLContext);
	STAssertTrue([_renderer renderAtTime:0.0], @"FFGLRenderer renderAtTime failed");
	GLStateRef after = GLStateCreateForContext(_CGLContext);
	STAssertTrue(GLStatesAreEqual(before, after), @"OpenGL state changed after call to renderAtTime:");
	GLStateRelease(before);
	GLStateRelease(after);
}
@end
