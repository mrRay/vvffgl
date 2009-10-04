//
//  RenderView.m
//  VVOpenSource
//
//  Created by Tom on 22/09/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "RenderView.h"

@implementation RenderView
- (id)initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat *)format
{
    if (self = [super initWithFrame:frameRect pixelFormat:format]) {

    }
    return self;
}

@synthesize renderChain = _chain;

- (void)prepareOpenGL {
    _needsReshape = YES;
}

- (void)reshape {
    _needsReshape = YES;
    [super reshape];
}

- (void)update {
    [super update];
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSOpenGLContext *context = [self openGLContext];
    [context makeCurrentContext];
    if(_needsReshape)
    {
	NSRect		frame = [self frame];
	NSRect		bounds = [self bounds];
	GLfloat 	minX, minY, maxX, maxY;
        
	minX = NSMinX(bounds);
	minY = NSMinY(bounds);
	maxX = NSMaxX(bounds);
	maxY = NSMaxY(bounds);
        
	[self update];
        
	if(NSIsEmptyRect([self visibleRect])) 
	{
	    glViewport(0, 0, 1, 1);
	} else {
	    glViewport(0, 0,  frame.size.width ,frame.size.height);
	}
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(minX, maxX, maxY, minY, -1.0, 1.0);
        
	glClearColor(0.0, 0.0, 0.0, 0.0);
        
	glClear(GL_COLOR_BUFFER_BIT);
	_needsReshape = NO;
    }
    // draw our frame
    [context flushBuffer];
}

@end
