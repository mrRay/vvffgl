/*
 *  FFGLInternal.h
 *  VVOpenSource
 *
 *  Created by Tom on 07/10/2009.
 *  Extended functionality for internal use.
 *
 */

#import <OpenGL/OpenGL.h>
#import "FFGLImage.h"
#import "FFGLPlugin.h"
#import "FFGLRenderer.h"

#ifndef NS_RETURNS_RETAINED
#if defined(__clang__)
#define NS_RETURNS_RETAINED __attribute__((ns_returns_retained))
#else
#define NS_RETURNS_RETAINED
#endif
#endif


//Comment lines out to disable them - compilation checks for definition

// This needs some more exploration... helps (a lot) or hinders (a bit), depending on circumstances
//#define FFGL_USE_TEXTURE_POOLS

// Buffer allocation from memory is costly, leave this defined to recycle buffers.
#define FFGL_USE_BUFFER_POOLS

// This causes problems on some cards for some plugins.
#define FFGL_ALLOW_NPOT_2D

// This is used for FFGLImage buffer-to-texture conversions
// It makes a noticable difference with large images.
#define FFGL_USE_TEXTURE_RANGE

extern NSString * const FFGLParameterAttributeIndexKey;

typedef void *FFGLPluginInstance; // According to FF standard, do not modify.

typedef struct FFGLProcessFrameCopyStruct {
    unsigned int        inputFrameCount;
    void**              inputFrames;
    void*               outputFrame;
} FFGLProcessFrameCopyStruct; // According to FF standard, do not modify.

typedef struct FFGLTextureInfo {
    unsigned int        width;
    unsigned int        height;
    unsigned int        hardwareWidth;
    unsigned int        hardwareHeight;
    GLuint              texture;
} FFGLTextureInfo; // According to FF standard, do not modify.

typedef struct FFGLProcessGLStruct {
    unsigned int        inputTextureCount;
    FFGLTextureInfo**   inputTextures;
    GLuint              hostFBO;
} FFGLProcessGLStruct; // According to FF standard, do not modify.

#pragma mark Utility Functions
static inline unsigned int ffglPOTDimension(unsigned int dimension)
{
    unsigned int glSize = 1;
    while (glSize<dimension) glSize<<=1;    
    return glSize;
}

NSUInteger ffglBytesPerPixelForPixelFormat(NSString *format);
bool ffglOpenGLSupportsExtension(CGLContextObj cgl_ctx, const char *extension);
bool ffglGLInfoForPixelFormat(NSString *ffglFormat, GLenum *format, GLenum *type);

#define FFGLLocalized(s) [[NSBundle bundleForClass:[self class]] localizedStringForKey:s value:s table:nil]

#define ffglSetContext(context,prevStore) { \
	prevStore = CGLGetCurrentContext(); \
	if (prevStore != context) \
	{ \
		CGLSetCurrentContext(context); \
	} \
}

#define ffglRestoreContext(context,prevStore) { \
	if (prevStore != context) \
	{ \
		CGLSetCurrentContext(prevStore); \
	} \
}

@interface FFGLPlugin (Instances)
/*
 Plugin properties
 */
- (NSUInteger)_minimumInputFrameCount;
- (NSUInteger)_maximumInputFrameCount;
- (BOOL)_supportsSetTime;
- (BOOL)_prefersFrameCopy;

/*
 Instances
 */
- (FFGLPluginInstance)_newInstanceWithSize:(NSSize)dimensions pixelFormat:(NSString *)format; // GPU renderers can pass in nil for pixelFormat
- (void)_disposeInstance:(FFGLPluginInstance)instance;
- (id)_valueForNonImageParameterKey:(NSString *)key ofInstance:(FFGLPluginInstance)instance;
- (void)_setValue:(NSString *)value forStringParameterAtIndex:(NSUInteger)index ofInstance:(FFGLPluginInstance)instance;
- (void)_setValue:(NSNumber *)value forNumberParameterAtIndex:(NSUInteger)index ofInstance:(FFGLPluginInstance)instance;
- (void)_setTime:(NSTimeInterval)time ofInstance:(FFGLPluginInstance)instance;
- (BOOL)_imageInputAtIndex:(uint32_t)index willBeUsedByInstance:(FFGLPluginInstance)instance;
- (BOOL)_processFrameCopy:(FFGLProcessFrameCopyStruct *)frameInfo forInstance:(FFGLPluginInstance)instance;
- (BOOL)_processFrameInPlace:(void *)buffer forInstance:(FFGLPluginInstance)instance;
- (BOOL)_processFrameGL:(FFGLProcessGLStruct *)frameInfo forInstance:(FFGLPluginInstance)instance;
@end

@interface FFGLRenderer (Subclassing)

/* Subclasses must implement these methods */
- (void)_implementationSetImageInputCount:(NSUInteger)count;
- (BOOL)_implementationReplaceImage:(FFGLImage *)prevImage withImage:(FFGLImage *)newImage forInputAtIndex:(NSUInteger)index;
- (FFGLImage *)_implementationCreateOutput NS_RETURNS_RETAINED;

/* Subclasses should emit output after render using this */
- (void)setOutputImage:(FFGLImage *)image; // using a setter for our public outputImage method makes it play friendly with KVO.
@end

@interface FFGLImage (FFGL)
- (FFGLTextureInfo *)_texture2DInfo;
@end
