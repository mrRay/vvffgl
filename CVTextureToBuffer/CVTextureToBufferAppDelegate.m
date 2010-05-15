//
//  CVTextureToBufferAppDelegate.m
//  CVTextureToBuffer
//
//  Created by Tom on 26/02/2010.
//  Copyright 2010 Tom Butterworth. All rights reserved.
//

#import "CVTextureToBufferAppDelegate.h"
#import <OpenGL/CGLMacro.h>


#define kCVTTBTexWidth 640
#define kCVTTBTexHeight 480

@implementation CVTextureToBufferAppDelegate

@synthesize view = _view, performsBufferStage = _doesBuffer, source = _source;

- (void)dealloc
{
	[_timer invalidate];
	if (cgl_ctx != NULL)
	{
		CGLLockContext(cgl_ctx);
		if (_bufferTexture != 0)
			glDeleteTextures(1, &_bufferTexture);
		if (_greenTexture != 0)
			glDeleteTextures(1, &_greenTexture);
		CGLUnlockContext(cgl_ctx);
	}
	free(_buffer);
	CVOpenGLTextureRelease(_textureRef);
	[super dealloc];
}

- (void)awakeFromNib
{			
	cgl_ctx = [[self.view openGLContext] CGLContextObj];
	
	// Create the buffer backing for our green texture
	
	unsigned int rowBytes = kCVTTBTexWidth * 4;
	_greenBufferSource = valloc(kCVTTBTexHeight * rowBytes);
	unsigned int offset = 0;
	
	for (unsigned int y = 0; y < kCVTTBTexHeight; y++) {
		for (unsigned int x = 0; x < kCVTTBTexWidth; x++) {
#if __BIG_ENDIAN__
			_greenBufferSource[offset] = 255;	// alpha
			_greenBufferSource[offset+1] = 10; // red
			_greenBufferSource[offset+2] = 180;  // green
			_greenBufferSource[offset+3] = 55; // blue
			
#else
			_greenBufferSource[offset] = 55;	// blue
			_greenBufferSource[offset+1] = 180; // green
			_greenBufferSource[offset+2] = 10;  // red
			_greenBufferSource[offset+3] = 255; // alpha
#endif
			offset += 4;
		}
	}
			
	// Create our green texture as an alternative source
	CGLLockContext(cgl_ctx);
	
	// Save state
	glPushAttrib(GL_TEXTURE_BIT | GL_ENABLE_BIT);
	glPushClientAttrib(GL_CLIENT_PIXEL_STORE_BIT);
	
	// Make our new texture
	glGenTextures(1, &_greenTexture);
	glBindTexture(GL_TEXTURE_RECTANGLE_ARB, _greenTexture);
	
	// Set up the environment for unpacking
	
	glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);

	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_STORAGE_HINT_APPLE , GL_STORAGE_SHARED_APPLE);
	glTextureRangeAPPLE(GL_TEXTURE_RECTANGLE_ARB, rowBytes * kCVTTBTexHeight, _greenBufferSource);
	
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
	
	glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA8, kCVTTBTexWidth, kCVTTBTexHeight, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, _greenBufferSource);
	
	if (glGetError() != GL_NO_ERROR)
		NSLog(@"Error filling green texture");
	
	// restore state.
	glPopClientAttrib();
	glPopAttrib();
	
	CGLUnlockContext(cgl_ctx);
	
	// Set up QTContext
	if (QTOpenGLTextureContextCreate(kCFAllocatorDefault,
									 cgl_ctx,		
									 [self.view.pixelFormat CGLPixelFormatObj], 
									 NULL,
									 &_QTContext) == noErr)
	{
		_timer = [[NSTimer alloc] initWithFireDate:[NSDate date] interval:1/60 target:self selector:@selector(renderForTimer:) userInfo:nil repeats:YES];
		[[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSModalPanelRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSEventTrackingRunLoopMode];
		[_timer release];
	}
	else {
		NSLog(@"No QTContext");
	}
}

- (NSString *)moviePath
{
	NSString *path;
	@synchronized(self)
	{
		path = _moviePath;
	}
	return path;
}

- (void)setMoviePath:(NSString *)path
{
	QTMovie *newMovie;
	newMovie = [[QTMovie alloc] initWithFile:path error:nil];
	[newMovie setAttribute:[NSNumber numberWithBool:YES] forKey:QTMovieLoopsAttribute];
	@synchronized(self)
	{
		SetMovieVisualContext([_movie quickTimeMovie], NULL);
		[_movie stop];
		[_movie release];
		_movie = newMovie;
		SetMovieVisualContext([_movie quickTimeMovie], _QTContext);
		[_movie play];
	}
}

- (void)renderForTimer:(NSTimer*)theTimer
{
	GLuint sourceTexture;
	GLuint outputTexture;
	CGSize size;
	GLenum targetGL;
	
	// We use local variables first in case the view is simultaneously drawing from our old resources:
	CVOpenGLTextureRef newTextureRef;
	uint8_t *newBuffer;
	GLuint newBufferTexture;
	
	if (self.source == 0)
	{
		@synchronized(self)
		{
			QTVisualContextTask(_QTContext);
			QTVisualContextCopyImageForTime(_QTContext, kCFAllocatorDefault, NULL, &newTextureRef);
		}
		size = CVImageBufferGetEncodedSize(newTextureRef);
		sourceTexture = CVOpenGLTextureGetName(newTextureRef);
		targetGL = CVOpenGLTextureGetTarget(newTextureRef);
	}
	else
	{
		newTextureRef = NULL;
		size = CGSizeMake(kCVTTBTexWidth, kCVTTBTexHeight);
		sourceTexture = _greenTexture;
		targetGL = GL_TEXTURE_RECTANGLE_ARB;
	}
	
	if (self.performsBufferStage && sourceTexture != 0)
	{
		unsigned int rowBytes = size.width * 4;
		newBuffer = valloc(size.height * rowBytes);
		unsigned int offset = 0;
		
		// Clear the buffer so we can see the effect of change,
		// as valloc will likely return the buffer we just freed
		
		for (unsigned int y = 0; y < size.height; y++) {
			for (unsigned int x = 0; x < size.width; x++) {
#if __BIG_ENDIAN__
				newBuffer[offset] = 255; // alpha
				newBuffer[offset+1] = 0; // red
				newBuffer[offset+2] = 0; // green
				newBuffer[offset+3] = 0; // blue
#else
				newBuffer[offset] = 0; // blue
				newBuffer[offset+1] = 0; // green
				newBuffer[offset+2] = 0; // red
				newBuffer[offset+3] = 255; // alpha
#endif
				offset += 4;
			}
		}
		GLenum error;
		if (newBuffer != NULL)
		{
			CGLLockContext(cgl_ctx);
			// Save state
			glPushAttrib(GL_TEXTURE_BIT | GL_ENABLE_BIT);
			glPushClientAttrib(GL_CLIENT_PIXEL_STORE_BIT);
			
			glEnable(targetGL);
			
			
#pragma mark Problem Section
			/*
			 
			 This stage is where glGetTexImage appears to do nothing with a texture from CoreVideo.
			 
			 */
			
			// Bind our texture
			glBindTexture(targetGL, sourceTexture);
			// Make sure pixel-storage is set up as we need it
			
			glTexParameteri(targetGL, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			glTexParameteri(targetGL, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
			glTexParameteri(targetGL, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri(targetGL, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
			glTexParameteri(targetGL, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
			
			// Get the pixel data
			glGetTexImage(targetGL, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, newBuffer);
			// Check for error
			error = glGetError();
			
			if (error != GL_NO_ERROR)
				NSLog(@"GL Error getting buffer");

			/*
			 
			 Now we create a texture using the buffer we just filled. This stage works fine.
			 
			 */

			// Make our new texture
			
			glGenTextures(1, &newBufferTexture);
			glBindTexture(targetGL, newBufferTexture);
			
			// Set up the environment for unpacking
			
			glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);

			glTexParameteri(targetGL, GL_TEXTURE_STORAGE_HINT_APPLE , GL_STORAGE_SHARED_APPLE);
			glTextureRangeAPPLE(targetGL, rowBytes * size.height, newBuffer);

			glTexParameteri(targetGL, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameteri(targetGL, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTexParameteri(targetGL, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri(targetGL, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
			glTexParameteri(targetGL, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
			
			glTexImage2D(targetGL, 0, GL_RGBA8, size.width, size.height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, newBuffer);
			
			error = glGetError();
			
			// restore state.
			glPopClientAttrib();
			glPopAttrib();
			
			if (error != GL_NO_ERROR)
			{
				glDeleteTextures(1, &newBufferTexture);
				newBufferTexture = 0;
				NSLog(@"Error filling texture");
			}
			CGLUnlockContext(cgl_ctx);
			outputTexture = newBufferTexture;
		}
		else
		{
			NSLog(@"No buffer");
			outputTexture = 0;
		}
		
	}
	else
	{
		newBufferTexture = 0;
		newBuffer = NULL;
		outputTexture = sourceTexture;
	}
	[self.view setTextureName:outputTexture width:size.width height:size.height];
	[self.view drawRect:self.view.bounds];

	// Now the view has our new texture, we can destroy the previous resources
	if (_textureRef != NULL)
	{	
		CVOpenGLTextureRelease(_textureRef);
	}
	_textureRef = newTextureRef;
	if (_bufferTexture != 0)
	{
		glDeleteTextures(1, &_bufferTexture);
	}
	_bufferTexture = newBufferTexture;
	free(_buffer);
	_buffer = newBuffer;
}

@end
