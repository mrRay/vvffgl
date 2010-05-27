//
//  RenderView.m
//  VVOpenSource
//
//  Created by Tom on 22/09/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "RenderView.h"
#import <OpenGL/CGLMacro.h>

@implementation RenderView
- (id)initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat *)format
{
    if (self = [super initWithFrame:frameRect pixelFormat:format]) {

    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

@synthesize renderChain = _chain;

- (void)prepareOpenGL 
{
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
	CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
	CGLLockContext(cgl_ctx);
	NSRect		bounds = [self bounds];
	GLfloat 	minX, minY, maxX, maxY;
	
	minX = NSMinX(bounds);
	minY = NSMinY(bounds);
	maxX = NSMaxX(bounds);
	maxY = NSMaxY(bounds);

	if(_needsReshape)
    {
        NSRect		frame = [self frame];
            
        [self update];
            
        if(NSIsEmptyRect([self visibleRect])) 
        {
            glViewport(0, 0, 1, 1);
        } else {
            glViewport(0, 0,  frame.size.width ,frame.size.height);
        }
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(minX, maxX, minY, maxY, -1.0, 1.0);
       
		glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
		
		_needsReshape = NO;
    }
	
	// render everything?
	FFGLImage *image = [_chain output];
	
	// clear everything
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);
	
	/*
	if ([image lockTextureRectRepresentation])
	{
	// draw it
	    glColor4f(1.0, 1.0, 1.0, 1.0);
	    
//		NSLog(@"rendering texture: %u, width: %u, height %u", [image textureRectName], [image texture2DPixelsWide], [image textureRectPixelsHigh]);
	    
	    glActiveTexture(GL_TEXTURE0);
	    glEnable(GL_TEXTURE_RECTANGLE_ARB);
	    
	    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, [image textureRectName]);

	    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, GL_CLAMP);
	    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, GL_CLAMP);
		glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_R, GL_CLAMP);
	    
	    
	    //	glDisable(GL_BLEND);
//		glEnable(GL_BLEND);
//		glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
		NSUInteger w = [image imagePixelsWide];
		NSUInteger h = [image imagePixelsHigh];
		// Calculate origin, using floorf() to remain pixel-aligned
		CGPoint at = CGPointMake(floorf((bounds.size.width / 2.0) - (w / 2.0)), floorf((bounds.size.height / 2.0) - ( h / 2.0)));
	    glBegin(GL_QUADS);
	    glTexCoord2f(0, 0);
	    glVertex2f(at.x, at.y);
	    glTexCoord2f(0, h);
	    glVertex2f(at.x, at.y + h);
	    glTexCoord2f(w, h);
	    glVertex2f(at.x + w, at.y + h);
	    glTexCoord2f(w, 0);
	    glVertex2f(at.x + w, at.y);
	    glEnd();
	    
	    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, 0);
	    glDisable(GL_TEXTURE_RECTANGLE_ARB);
	    
	    [image unlockTextureRectRepresentation];
	} 
	*/
	/*
	if ([image lockTexture2DRepresentation])
	{
	    // draw it
	    glColor4f(1.0, 1.0, 1.0, 1.0);
	    
	    glActiveTexture(GL_TEXTURE0);
	    glEnable(GL_TEXTURE_2D);
	    
	    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
	    
	    glBindTexture(GL_TEXTURE_2D, [image texture2DName]);
	    
	    //	glDisable(GL_BLEND);
	    //		glEnable(GL_BLEND);
	    //		glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
	    float w = [image imagePixelsWide];
		float h = [image imagePixelsHigh];
		float tw = [image texture2DPixelsWide];
		float th = [image texture2DPixelsHigh];
		CGFloat tre = w / tw;
		CGFloat tte = h / th;
		// Calculate origin, using floorf() to remain pixel-aligned
		CGPoint at = CGPointMake(floorf((bounds.size.width / 2.0) - (w / 2.0)), floorf((bounds.size.height / 2.0) - ( h / 2.0)));
	    glBegin(GL_QUADS);
	    glTexCoord2f(0.0, 0.0);
	    glVertex2f(at.x, at.y);
	    glTexCoord2f(0.0, tte);
	    glVertex2f(at.x, at.y + h);
	    glTexCoord2f(tre, tte);
	    glVertex2f(at.x + w, at.y + h);
	    glTexCoord2f(tre, 0.0);
	    glVertex2f(at.x + w, at.y);
	    glEnd();
	    
	    glBindTexture(GL_TEXTURE_2D, 0);
	    glDisable(GL_TEXTURE_2D);
	    [image unlockTexture2DRepresentation];
	}
	
	else if (image != nil) {
        NSLog(@"lockBufferRepresentationWithPixelFormat failed");
    }
 */	
	NSUInteger w = [image imagePixelsWide];
	NSUInteger h = [image imagePixelsHigh];
	// Calculate origin, using floorf() to remain pixel-aligned
	CGPoint at = CGPointMake(floorf((bounds.size.width / 2.0) - (w / 2.0)), floorf((bounds.size.height / 2.0) - ( h / 2.0)));
	[image drawInContext:cgl_ctx inRect:(NSRect){at.x, at.y, w, h} fromRect:(NSRect){0, 0, w, h}];
//	[image drawInContext:cgl_ctx inRect:(NSRect){0, 0, bounds.size.width, bounds.size.height} fromRect:(NSRect){0, 0, w, h}];	
	CGLFlushDrawable(cgl_ctx);	
	CGLUnlockContext(cgl_ctx);
}

@end
