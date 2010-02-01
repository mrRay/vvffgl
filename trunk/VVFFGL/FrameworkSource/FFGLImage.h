//
//  FFGLImage.h
//  VVOpenSource
//
//  Created by Tom on 04/10/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>

/*
 typedef void (*FFGLImageTextureReleaseCallback)(GLuint name, CGLContextObj cgl_ctx, void *userInfo)
 
	A texture release callback takes the form:

		void myTextureReleaseCallback(GLuint name, CGLContextObj cgl_ctx, void *userInfo) {
			// Destroy or recycle your texture and any associated resources.
		}
 */
typedef void (*FFGLImageTextureReleaseCallback)(GLuint name, CGLContextObj cgl_ctx, void *userInfo);

/*
 typedef void (*FFGLImageBufferReleaseCallback)(const void *baseAddress, void *userInfo)
 
	A buffer release callback takes the form:
 
		void myBufferReleaseCallback(const void *baseAddress, void* userInfo) {
			// free or recycle memory and any associated resources
		}
 
 */
typedef void (*FFGLImageBufferReleaseCallback)(const void *baseAddress, void *userInfo);

@interface FFGLImage : NSObject {
@private
	void *_private;
}
/*
 - (id)initWithTexture2D:(GLuint)texture CGLContext:(CGLContextObj)context imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight texturePixelsWide:(NSUInteger)textureWidth texturePixelsHigh:(NSUInteger)textureHeight flipped:(BOOL)isFlipped releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseInfo:(void *)userInfo
 
    Creates a new FFGLImage with the provided texture. The texture should remain valid and its content unchanged (FFGLImages are immutable) until the function at callback is called.
	texture should be the name of an existing texture of type GL_TEXTURE_2D
	context is the CGLContext associated with the texture
	imageWidth is the horizontal dimension of the image
	imageHeight is the vertical dimension of the image
	textureWidth is the horizontal dimension of the texture. If the texture is larger than the image, the image's lower-left (or top-right, if flipped) corner should be at texture cooridinate 0,0.
	textureHeight is the vertical dimension of the texture. If the texture is larger than the image, the image's lower-left (or top-right, if flipped) corner should be at texture cooridinate 0,0.
	isFlipped indicates the vertical orientation of the image. In some circumstances flipped textures will be copied to a new unflipped texture. To avoid this, pass in textures which are not flipped.
	callback is the function which will be called when the texture is no longer required by the FFGLImage. This function should delete or recycle the texture and any associated resources. It receives as
	its arguments the CGLContext, texture name and userInfo passed in at init.
 */
- (id)initWithTexture2D:(GLuint)texture CGLContext:(CGLContextObj)context imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight texturePixelsWide:(NSUInteger)textureWidth texturePixelsHigh:(NSUInteger)textureHeight flipped:(BOOL)isFlipped releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseInfo:(void *)userInfo;

/*
 - (id)initWithTextureRect:(GLuint)texture CGLContext:(CGLContextObj)context pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height flipped:(BOOL)isFlipped releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseInfo:(void *)userInfo
 
    Creates a new FFGLImage with the provided texture. The texture should remain valid and its content unchanged (FFGLImages are immutable) until the function at callback is called.
	texture should be the name of an existing texture of type GL_TEXTURE_RECTANGLE_ARB
	context is the CGLContext associated with the texture
	width is the horizontal dimension of the image (and texture)
	height is the vertical dimension of the image (and texture)
	isFlipped indicates the vertical orientation of the image.
	callback is the function which will be called when the texture is no longer required by the FFGLImage. This function should delete or recycle the texture and any associated resources. It receives as
	its arguments the CGLContext, texture name and userInfo passed in at init.
	userInfo is a pointer to any user data to be passed to the callback function. May be NULL.
 */
- (id)initWithTextureRect:(GLuint)texture CGLContext:(CGLContextObj)context pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height flipped:(BOOL)isFlipped releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseInfo:(void *)userInfo;

/*
 - (id)initWithBuffer:(void *)buffer pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes flipped:(BOOL)isFlipped 
 releaseCallback:(FFGLImageBufferReleaseCallback)callback releaseInfo:(void *)userInfo
 
    Creates a new FFGLImage with the provided buffer. The buffer should remain valid and its content unchanged (FFGLImages are immutable) until the function at callback is called.
    Note that due to limitations in FreeFrame plugins, if there are padding pixels in the buffer (ie if rowBytes != ((the number of bytes per pixel for format) * width)),
    the buffer will be copied at init. In this case the function provided in callback will be called immediately.
	buffer should be the address of the pixel data in memory
	context is the CGLContext to be used for texture operations on the image
	format describes the pixel format of the buffer. It should be one of:
		FFGLPixelFormatARGB8888
		FFGLPixelFormatBGRA8888
		FFGLPixelFormatRGB888
		FFGLPixelFormatBGR888
		FFGLPixelFormatRGB565
		FFGLPixelFormatBGR565
	width is the horizontal dimension of the image
	height is the vertical dimension of the image
	rowBytes is the number of bytes in a row of pixels
	isFlipped indicates the vertical orientation of the image. Flipped images may require an un-flipped copy to be made at init.
	callback is the function which will be called when the buffer is no longer required by the FFGLImage. This function should free or recycle the memory and any associated resources. It receives as
	its arguments the buffer address and userInfo passed in at init.
	userInfo is a pointer to any user data to be passed to the callback function. May be nil.
 */
- (id)initWithBuffer:(const void *)buffer CGLContext:(CGLContextObj)context pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes flipped:(BOOL)isFlipped releaseCallback:(FFGLImageBufferReleaseCallback)callback releaseInfo:(void *)userInfo;


/*
 - (id)initWithCopiedTextureRect:(GLuint)texture CGLContext:(CGLContextObj)context pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height flipped:(BOOL)isFlipped

	Creates a new FFGLImage by copying the provided texture.
	texture should be the name of an existing texture of type GL_TEXTURE_RECTANGLE_ARB
	context is the CGLContext associated with the texture
	width is the horizontal dimension of the image (and texture)
	height is the vertical dimension of the image (and texture)
	isFlipped indicates the vertical orientation of the image. 
 */
- (id)initWithCopiedTextureRect:(GLuint)texture CGLContext:(CGLContextObj)context pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height flipped:(BOOL)isFlipped;

/*
 - (id)initWithCopiedTexture2D:(GLuint)texture CGLContext:(CGLContextObj)context imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight texturePixelsWide:(NSUInteger)textureWidth texturePixelsHigh:(NSUInteger)textureHeight flipped:(BOOL)isFlipped

	Creates a new FFGLImage by copying the provided texture.
	texture should be the name of an existing texture of type GL_TEXTURE_2D
	context is the CGLContext associated with the texture
	imageWidth is the horizontal dimension of the image
	imageHeight is the vertical dimension of the image
	textureWidth is the horizontal dimension of the texture. If the texture is larger than the image, the image's lower-left (or top-right, if flipped) corner should be at texture cooridinate 0,0.
	textureHeight is the vertical dimension of the texture. If the texture is larger than the image, the image's lower-left (or top-right, if flipped) corner should be at texture cooridinate 0,0.
	isFlipped indicates the vertical orientation of the image.
 */
- (id)initWithCopiedTexture2D:(GLuint)texture CGLContext:(CGLContextObj)context imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight texturePixelsWide:(NSUInteger)textureWidth texturePixelsHigh:(NSUInteger)textureHeight flipped:(BOOL)isFlipped;

/*
 - (id)initWithCopiedBuffer:(const void *)buffer CGLContext:(CGLContextObj)context pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes flipped:(BOOL)isFlipped
 
	Creates a new FFGLImage by copying the provided buffer.
	buffer should be the address of the pixel data in memory
	context is the CGLContext to be used for texture operations on the image
	format describes the pixel format of the buffer. It should be one of:
		FFGLPixelFormatARGB8888
		FFGLPixelFormatBGRA8888
		FFGLPixelFormatRGB888
		FFGLPixelFormatBGR888
		FFGLPixelFormatRGB565
		FFGLPixelFormatBGR565
	width is the horizontal dimension of the image
	height is the vertical dimension of the image
	rowBytes is the number of bytes in a row of pixels
	isFlipped inidcates the vertical orientation of the image.
 */
- (id)initWithCopiedBuffer:(const void *)buffer CGLContext:(CGLContextObj)context pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes flipped:(BOOL)isFlipped;

@property (readonly) NSUInteger imagePixelsWide;
@property (readonly) NSUInteger imagePixelsHigh;

/*
 lockTexture2DRepresentation
 
	Indicates that you require access to a GL_TEXTURE_2D representation of the image. If none already exists it will be created from an existing representation if possible.
	You must call this method before using the GL_TEXTURE_2D representation even if the FFGLImage was created from a GL_TEXTURE_2D texture.
	Any resulting texture may have dimensions beyond the dimensions of the FFGLImage. Check the size of the texture using texture2DPixelsWide and texture2DPixelsHigh.
    This representation will remain valid until a call to unlockTexture2DRepresentation.
    Returns YES if a texture representation exists or was created, NO otherwise. You should check the returned value before attempting to use the texture.
 */
- (BOOL)lockTexture2DRepresentation;

/*
 - (void)unlockTexture2DRepresentation
 
	Indicates that you are finished using the GL_TEXTURE_2D representation of the image.
 */
- (void)unlockTexture2DRepresentation;

/*
 @property (readonly) GLuint texture2DName
 
	Returns the name of the GL_TEXTURE_2D texture for the image. Only call this method after a call to lockTexture2DRepresentation has returned YES.
 */
@property (readonly) GLuint texture2DName;

/*
 @property (readonly) NSUInteger texture2DPixelsWide
 
	Returns the width of the GL_TEXTURE_2D texture, which may be greater than the image dimensions.
	Only call this method after a call to lockTexture2DRepresentation has returned YES.
 */
@property (readonly) NSUInteger texture2DPixelsWide;

/*
 @property (readonly) NSUInteger texture2DPixelsHigh
 
	Returns the height of the GL_TEXTURE_2D texture, which may be greater than the image dimensions.
	Only call this method after a call to lockTexture2DRepresentation has returned YES.
 */
@property (readonly) NSUInteger texture2DPixelsHigh;

/*
 @property (readonly) BOOL texture2DIsFlipped
 
	 Returns a BOOL indicating the vertical orientation of the GL_TEXTURE_2D texture.
	 Only call this method after a call to lockTexture2DRepresentation has returned YES.
 */
@property (readonly) BOOL texture2DIsFlipped;

/*
 -(BOOL)lockTextureRectRepresentation
    Creates a GL_TEXTURE_RECTANGLE_ARB representation of the image if none already exists. This will remain valid until a call to unlockTextureRectRepresentation.
    Returns YES if a texture representation exists or was created, NO otherwise. You should check the returned value before attempting to use the texture.
	Any GL_TEXTURE_RECTANGLE_ARB created will have pixel dimensions to match the FFGLImage.
 */
- (BOOL)lockTextureRectRepresentation;

/*
 - (void)unlockTextureRectRepresentation
 
	Indicates that you are finished using the GL_TEXTURE_RECTANGLE_ARB representation of the image.
 */
- (void)unlockTextureRectRepresentation;

/*
 @property (readonly) GLuint textureRectName
 
	Returns the name of the GL_TEXTURE_RECTANGLE_ARB texture for the image. Only call this method after a call to lockTextureRectRepresentation has returned YES.
 */
@property (readonly) GLuint textureRectName;

/*
 @property (readonly) BOOL textureRectIsFlipped
 
	Returns a BOOL indicating the vertical orientation of the GL_TEXTURE_RECTANGLE_ARB texture.
	Only call this method after a call to lockTextureRectRepresentation has returned YES.
 */
@property (readonly) BOOL textureRectIsFlipped;

/*
 - (BOOL)lockBufferRepresentationWithPixelFormat:(NSString *)format
    Creates a buffer representation of the image if none already exists. This will remain valid until a call to unlockBufferRepresentation.
    Returns YES if a buffer representation exists or was created, NO otherwise. You should check the returned value before attempting to use the buffer.
	Any buffer created will have pixel dimensions to match the FFGLImage.
    Note that this will fail (return NO) if you attempt to lock a buffer representation when one is already locked in another format, or if the FFGLImage
    was created from a buffer in another format, or if a buffer in the requested format could not be created from an existing texture representation, or
    for other reasons.
	format is a string representing the desired pixel-format, which should be one of:
		FFGLPixelFormatARGB8888
		FFGLPixelFormatBGRA8888
		FFGLPixelFormatRGB888
		FFGLPixelFormatBGR888
		FFGLPixelFormatRGB565
		FFGLPixelFormatBGR565
 */
- (BOOL)lockBufferRepresentationWithPixelFormat:(NSString *)format;

/*
 - (void)unlockBufferRepresentation
 
 Indicates that you are finished using the buffer representation of the image.
 */
- (void)unlockBufferRepresentation;

/*
 @property (readonly) const void *bufferBaseAddress
 
	Returns the address of the pixel data in memory.
	Only call this method after a call to lockBufferRepresentationWithPixelFormat: has returned YES.
 */
@property (readonly) const void *bufferBaseAddress;

/*
 @property (readonly) NSUInteger bufferBytesPerRow
 
	Returns the number of bytes per row of pixel data for the pixel buffer.
	Only call this method after a call to lockBufferRepresentationWithPixelFormat: has returned YES.
 */
@property (readonly) NSUInteger bufferBytesPerRow;

/*
 @property (readonly) NSString *bufferPixelFormat
 
	Returns the pixel format of the pixel buffer.
	Only call this method after a call to lockBufferRepresentationWithPixelFormat: has returned YES.
*/
@property (readonly) NSString *bufferPixelFormat;

/*
 @property (readonly) BOOL bufferIsFlipped
 
	Returns a BOOL indicating the vertical orientation of the pixel buffer.
	Only call this method after a call to lockBufferRepresentationWithPixelFormat: has returned YES.
*/
@property (readonly) BOOL bufferIsFlipped;
@end
