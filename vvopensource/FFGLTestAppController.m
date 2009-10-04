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

	// resize window notification
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateRenderView:) name:NSViewFrameDidChangeNotification object:ffglRenderView];
	
	// add a basic NSTimer renderer for our main thread, no need to get fancy for now.
	ffglRenderTimer = [NSTimer timerWithTimeInterval:(1.0/60.0) target:self selector:@selector(render) userInfo:nil repeats:YES];
	[ffglRenderTimer retain];
	[[NSRunLoop currentRunLoop] addTimer:ffglRenderTimer forMode:NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:ffglRenderTimer forMode:NSModalPanelRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:ffglRenderTimer forMode:NSEventTrackingRunLoopMode];

	// for shits and giggles lets make sure we have some plugins in our plugin manager
	NSLog(@"Loaded source plugins: %@, loaded effect plugins: %@", [ffglManager sourcePlugins], [ffglManager effectPlugins]);

}

- (void) render
{
	//NSLog(@"render callback");
}

- (void) updateRenderView:(NSNotification *) notification
{
	[ffglRenderContext makeCurrentContext];
	CGLLockContext(	[ffglRenderContext CGLContextObj]);
	[ffglRenderContext update];
	
	NSRect	mainRenderViewFrame = [ffglRenderView frame];
	
	glViewport(0, 0, mainRenderViewFrame.size.width, mainRenderViewFrame.size.height);
	glClear(GL_COLOR_BUFFER_BIT);
	
	[ffglRenderContext flushBuffer];
	CGLUnlockContext([ffglRenderContext CGLContextObj]);
}


@end
