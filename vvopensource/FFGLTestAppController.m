//
//  FFGLTestAppController.m
//  VVOpenSource
//
//  Created by vade on 10/4/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "FFGLTestAppController.h"


@implementation FFGLTestAppController

- (void) applicationDidFinishLaunching:(NSNotification *)notification
{
	NSLog(@"FFGL Test App launched");
	NSLog(@"Building GL context");
	
	NSOpenGLPixelFormatAttribute attributes[] = { NSOpenGLPFAAccelerated, NSOpenGLPFADoubleBuffer, (NSOpenGLPixelFormatAttribute) 0};
	
	NSOpenGLPixelFormat* format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
	
	if(format == nil)
	{
		NSLog(@"OpenGL Context Creation failed - terminating");
		[NSApp terminate];
	}

	ffglRenderContext = [[NSOpenGLContext alloc] initWithFormat:format shareContext:nil];
	
	if(ffglRenderContext == nil)	
	{
		NSLog(@"Pixel Format Creation failed - terminating");
		[NSApp terminate];
	}

	// associate context with view;
	[ffglRenderContext setView:ffglRenderView];
	
	// clear our render context
	[ffglRenderContext makeCurrentContext];
	CGLLockContext([ffglRenderContext CGLContextObj]);
	glClearColor(1.0, 0.0, 0.0, 1.0);
	glClear(GL_COLOR_BUFFER_BIT);
	CGLUnlockContext([ffglRenderContext CGLContextObj]);
	[ffglRenderContext flushBuffer];
}

@end
