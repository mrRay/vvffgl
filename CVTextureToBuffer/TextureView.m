//
//  TextureView.m
//  CVTextureToBuffer
//
//  Created by Tom on 01/03/2010.
//  Copyright 2010 Tom Butterworth. All rights reserved.
//

#import "TextureView.h"
#import <OpenGL/CGLMacro.h>

@implementation TextureView


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

- (void)setTextureName:(GLint)texName width:(float)texWidth height:(float)texHeight
{
	@synchronized(self)
	{
		_tex = texName;
		_width = texWidth;
		_height = texHeight;
	}
}

- (void)drawRect:(NSRect)dirtyRect
{
	CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
	CGLLockContext(cgl_ctx);
	NSRect		bounds = [self bounds];
	GLfloat 	minX, minY, maxX, maxY;
	
	if(_needsReshape)
    {
		minX = NSMinX(bounds);
		minY = NSMinY(bounds);
		maxX = NSMaxX(bounds);
		maxY = NSMaxY(bounds);
		
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
	
	// clear everything
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);
	
	@synchronized(self)
	{
	
		if (_tex != 0)
		{
			// draw it
			glColor4f(1.0, 1.0, 1.0, 1.0);
			
			glEnable(GL_TEXTURE_RECTANGLE_ARB);
			 
			glBindTexture(GL_TEXTURE_RECTANGLE_ARB, _tex);
			 
			glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, GL_CLAMP);
			glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, GL_CLAMP);
			glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_R, GL_CLAMP);
			
			// Calculate origin, using floorf() to remain pixel-aligned
			CGPoint at = CGPointMake(floorf((bounds.size.width / 2.0) - (_width / 2.0)), floorf((bounds.size.height / 2.0) - (_height / 2.0)));
			glBegin(GL_QUADS);
			glTexCoord2f(0, 0);
			glVertex2f(at.x, at.y);
			glTexCoord2f(0, _height);
			glVertex2f(at.x, at.y + _height);
			glTexCoord2f(_width, _height);
			glVertex2f(at.x + _width, at.y + _height);
			glTexCoord2f(_width, 0);
			glVertex2f(at.x + _width, at.y);
			glEnd();
			
			glBindTexture(GL_TEXTURE_RECTANGLE_ARB, 0);
			glDisable(GL_TEXTURE_RECTANGLE_ARB);
		}

		CGLFlushDrawable(cgl_ctx);
	}
	CGLUnlockContext(cgl_ctx);
}

@end
