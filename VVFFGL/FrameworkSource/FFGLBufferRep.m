//
//  FFGLBufferRep.m
//  VVFFGL
//
//  Created by Tom on 11/02/2010.
//

#import "FFGLBufferRep.h"
#import "FFGLTextureRep.h"
#import <OpenGL/CGLMacro.h>

static void FFGLBufferRepBufferRelease(const void *baseAddress, void* context) {
    free((void *)baseAddress);
}

static void FFGLBufferRepBufferRepReleaseForTexture(const void *baseAddress, void *userInfo)
{
	[(FFGLBufferRep *)userInfo release];
}

@implementation FFGLBufferRep

- (id)copyAsType:(FFGLImageRepType)type pixelFormat:(NSString *)pixelFormat inContext:(CGLContextObj)context allowingNPOT2D:(BOOL)useNPOT asPrimaryRep:(BOOL)isPrimary
{
	FFGLTextureRep *rep2D, *repRect;
	switch (type)
	{
		case FFGLImageRepTypeBuffer:
			// Easy-peasy
			if ([_pixelFormat isEqualToString:pixelFormat])
			{
				return [[FFGLBufferRep alloc] initWithCopiedBuffer:_buffer
															 width:_width
															height:_height
													   bytesPerRow:_rowBytes
													   pixelFormat:_pixelFormat
														 isFlipped:_isFlipped
													  asPrimaryRep:isPrimary];
			}
			// We don't support pixel-format conversion
			return nil;
			break;
		case FFGLImageRepTypeTexture2D:
			rep2D = nil;
			// We need to always produce non-flipped 2D textures (for FreeFrame plugins), so...
			
			// Have a try with our buffer straight to a 2D texture
			rep2D = [[FFGLTextureRep alloc] initFromBuffer:_buffer
												   context:context
													 width:_width
													height:_height
											   bytesPerRow:_rowBytes
											   pixelFormat:_pixelFormat
												 isFlipped:_isFlipped
													toType:FFGLImageRepTypeTexture2D
												  callback:FFGLBufferRepBufferRepReleaseForTexture
												  userInfo:[self retain]
											  allowingNPOT:useNPOT
											  asPrimaryRep:isPrimary];
			
			if (rep2D == nil)
			{
				// initFromBuffer:.. may have failed for a 2D POT texture. We create an intermediary rect texture in that case
				
				FFGLTextureRep *temp = [[FFGLTextureRep alloc] initFromBuffer:_buffer
																	  context:context
																		width:_width
																	   height:_height
																  bytesPerRow:_rowBytes
																  pixelFormat:_pixelFormat
																	isFlipped:_isFlipped
																	   toType:FFGLImageRepTypeTextureRect
																	 callback:NULL
																	 userInfo:NULL
																 allowingNPOT:useNPOT
																 asPrimaryRep:isPrimary];
				
				FFGLTextureInfo *texInfo = temp.textureInfo;
				
				rep2D = [[FFGLTextureRep alloc] initCopyingTexture:texInfo->texture
															ofType:FFGLImageRepTypeTextureRect
														   context:context
														imageWidth:texInfo->width
													   imageHeight:texInfo->height
													  textureWidth:texInfo->hardwareWidth
													 textureHeight:texInfo->hardwareHeight
														 isFlipped:temp.isFlipped
															toType:FFGLImageRepTypeTexture2D
													  allowingNPOT:useNPOT
													  asPrimaryRep:isPrimary];
				[temp release];
			}
			if (rep2D.isFlipped)
			{
				// We may still be flipped, but a texture-copy will fix that
				FFGLTextureRep *temp = rep2D;
				FFGLTextureInfo *texInfo = temp.textureInfo;
				
				rep2D = [[FFGLTextureRep alloc] initCopyingTexture:texInfo->texture
															ofType:FFGLImageRepTypeTexture2D
														   context:context
														imageWidth:_width
													   imageHeight:_height
													  textureWidth:texInfo->hardwareWidth
													 textureHeight:texInfo->hardwareHeight
														 isFlipped:temp.isFlipped
															toType:FFGLImageRepTypeTexture2D
													  allowingNPOT:useNPOT
													  asPrimaryRep:isPrimary];
				[temp release];
			}
			return rep2D;
			break;
		case FFGLImageRepTypeTextureRect:
			// simple as we don't care about flippedness
			repRect = [[FFGLTextureRep alloc] initFromBuffer:_buffer
													 context:context
													   width:_width
													  height:_height
												 bytesPerRow:_rowBytes
												 pixelFormat:_pixelFormat
												   isFlipped:_isFlipped
													  toType:FFGLImageRepTypeTextureRect
													callback:FFGLBufferRepBufferRepReleaseForTexture
													userInfo:[self retain]
												allowingNPOT:useNPOT
												asPrimaryRep:isPrimary];
			return repRect;
			break;
		default:
			break;
	}
	return nil;
}

- (id)initWithBuffer:(const void *)source width:(NSUInteger)width height:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes pixelFormat:(NSString *)pixelFormat isFlipped:(BOOL)flipped callback:(FFGLImageBufferReleaseCallback)callback userInfo:(void *)userInfo asPrimaryRep:(BOOL)isPrimary
{
	if (self = [super initAsType:FFGLImageRepTypeBuffer isFlipped:flipped asPrimaryRep:isPrimary])
	{
		_buffer = source;
		_width = width;
		_height = height;
		_rowBytes = rowBytes;
		_pixelFormat = [pixelFormat retain];
		_userInfo = userInfo;
		_callback = callback;
	}
	return self;
}

- (id)initWithCopiedBuffer:(const void *)source width:(NSUInteger)width height:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes pixelFormat:(NSString *)pixelFormat isFlipped:(BOOL)flipped asPrimaryRep:(BOOL)isPrimary
{
    NSUInteger bpp = ffglBytesPerPixelForPixelFormat(pixelFormat);
	if (source == NULL
		|| width == 0
		|| height == 0
		|| rowBytes == 0
		|| bpp == 0)
	{
		[self release];
		return nil;
	}
	

	// FF plugins don't support pixel buffers where image width != row width.
	// We could just fiddle the reported image width, but this would give wrong results if the plugin takes borders into account.
	// We also flip buffers the right way up because we don't support upside down buffers - though FF plugins do...
	// In these cases we make a new buffer with no padding.
	unsigned int i;
	int newRowBytes = width * bpp;
	void *newBuffer = valloc(newRowBytes * height);
	if (newBuffer == NULL)
	{
		[self release];
		return nil;
	}
	const void *s = source;
	void *d = newBuffer + (flipped ? newRowBytes * (height - 1) : 0);
	int droller = flipped ? -newRowBytes : newRowBytes;
	for (i = 0; i < height; i++) {
		memcpy(d, s, newRowBytes);
		s+=rowBytes;
		d+=droller;
	}
	return [self initWithBuffer:newBuffer
						  width:width
						 height:height
					bytesPerRow:newRowBytes
					pixelFormat:pixelFormat
					  isFlipped:NO
					   callback:FFGLBufferRepBufferRelease userInfo:NULL
				   asPrimaryRep:isPrimary];
	
}

- (id)initFromNonFlippedTexture:(GLuint)texture ofType:(FFGLImageRepType)repType context:(CGLContextObj)cgl_ctx imageWidth:(NSUInteger)width imageHeight:(NSUInteger)height textureWidth:(NSUInteger)textureWidth textureHeight:(NSUInteger)textureHeight toPixelFormat:(NSString *)pixelFormat allowingNPOT:(BOOL)useNPOT asPrimaryRep:(BOOL)isPrimary
{
	GLenum targetGL;
	if (repType == FFGLImageRepTypeTexture2D)
	{
		// If our source has POT dimensions beyond its bounds, we fail.
		// the caller should first create a rect texture then convert from that
		if (textureWidth != width
			|| textureHeight != height
			)
		{
			[self release];
			return nil;
		}
		else
		{
			targetGL = GL_TEXTURE_2D;
		}
	}
	else if (repType == FFGLImageRepTypeTextureRect)
	{
		targetGL = GL_TEXTURE_RECTANGLE_ARB;
	}
	else
	{
		[self release];
		return nil;
	}
	
	GLenum format, type;
	unsigned int bytesPerPixel;
	if (ffglGLInfoForPixelFormat(pixelFormat, &format, &type, &bytesPerPixel) == NO)
	{
		[self release];
		return nil;
	}
	unsigned int rowBytes = textureWidth * bytesPerPixel;
	GLvoid *buffer = valloc(rowBytes * textureHeight);
	if (buffer == NULL)
	{
		[self release];
		return nil;
	}
		
	// Save state
	glPushAttrib(GL_TEXTURE_BIT | GL_ENABLE_BIT);
	glPushClientAttrib(GL_CLIENT_PIXEL_STORE_BIT);
	
	glActiveTexture(GL_TEXTURE0);

	// Bind our texture
	glEnable(targetGL);
	glBindTexture(targetGL, texture);
	
	// Make sure pixel-storage is set up as we need it
	glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
	glPixelStorei(GL_PACK_ROW_LENGTH, 0);
	glPixelStorei(GL_PACK_IMAGE_HEIGHT, 0);
	glPixelStorei(GL_PACK_ALIGNMENT, 1);
	glPixelStorei(GL_PACK_LSB_FIRST, GL_FALSE);
	glPixelStorei(GL_PACK_SKIP_IMAGES, 0);
	glPixelStorei(GL_PACK_SKIP_PIXELS, 0);
	glPixelStorei(GL_PACK_SKIP_ROWS, 0);
	glPixelStorei(GL_PACK_SWAP_BYTES, GL_FALSE);
	
	// Get the pixel data
	glGetTexImage(targetGL, 0, format, type, buffer);
	
	// Check for error
	GLenum error = glGetError();
	
	// Restore state
	glPopClientAttrib();
	glPopAttrib();
		
	if (error != GL_NO_ERROR)
	{
		free(buffer);
		[self release];
		return nil;
	}
	
	return [self initWithBuffer:buffer
						  width:width
						 height:height
					bytesPerRow:rowBytes
					pixelFormat:pixelFormat
					  isFlipped:NO
					   callback:FFGLBufferRepBufferRelease
					   userInfo:NULL
				   asPrimaryRep:isPrimary];
}
- (void)performCallbackPriorToRelease
{
	if (_callback != NULL)
	{
		_callback(_buffer, _userInfo);
		_callback = NULL;
	}	
}

- (void)finalize
{
	[self performCallbackPriorToRelease];
	[super finalize];
}

- (void)dealloc
{
	[self performCallbackPriorToRelease];
	[_pixelFormat release];
	[super dealloc];
}

- (const void *)baseAddress
{
	return _buffer;
}

- (NSUInteger)imageWidth
{
	return _width;
}

- (NSUInteger)imageHeight
{
	return _height;
}

- (NSUInteger)rowBytes
{
	return _rowBytes;
}
- (NSString *)pixelFormat
{
	return _pixelFormat;
}
-(BOOL)conformsToFreeFrame
{
	if (_isFlipped == YES
	|| _rowBytes != ffglBytesPerPixelForPixelFormat(_pixelFormat) * _width)
	{
		return NO;
	}
	else
	{
		return YES;
	}
}
@end
