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

// This needs some more exploration... helps (a lot) or hinders (a bit), depending on circumstances
//#define FFGL_USE_TEXTURE_POOLS 1
// Buffer allocation from memory is costly, leave this defined to recycle buffers.
#define FFGL_USE_BUFFER_POOLS 1

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

bool ffglOpenGLSupportsExtension(CGLContextObj cgl_ctx, const char *extension);

#define FFGLLocalized(s) [[NSBundle bundleForClass:[self class]] localizedStringForKey:s value:s table:nil]

@interface FFGLPlugin (Instances)
/*
 Plugin properties
 */
- (NSUInteger)_minimumInputFrameCount; // TODO: may not need this, could go
- (NSUInteger)_maximumInputFrameCount; // TODO: beth ditto
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
- (BOOL)_implementationRender;

/* Subclasses should emit output after render using this */
- (void)setOutputImage:(FFGLImage *)image; // using a setter for our public outputImage method makes it play friendly with KVO.
@end

@interface FFGLImage (FFGL)
- (FFGLTextureInfo *)_texture2DInfo;
@end
