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

extern NSString * const FFGLParameterAttributeIndexKey;

typedef uint32_t FFGLPluginInstance;

typedef struct FFGLProcessFrameCopyStruct {
    unsigned int        inputFrameCount;
    void**              inputFrames;
    void*               outputFrame;
} FFGLProcessFrameCopyStruct;

typedef struct FFGLTextureInfo {
    unsigned int        width;
    unsigned int        height;
    unsigned int        hardwareWidth;
    unsigned int        hardwareHeight;
    GLuint              texture;
} FFGLTextureInfo;

typedef struct FFGLProcessGLStruct {
    unsigned int        inputTextureCount;
    FFGLTextureInfo**   inputTextures;
    GLuint              hostFBO;
} FFGLProcessGLStruct;

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
- (FFGLPluginInstance)_newInstanceWithBounds:(NSRect)bounds pixelFormat:(NSString *)format; // GPU renderers can pass in nil for pixelFormat
- (void)_disposeInstance:(FFGLPluginInstance)instance;
- (id)_valueForNonImageParameterKey:(NSString *)key ofInstance:(FFGLPluginInstance)instance;
- (void)_setValue:(id)value forNonImageParameterKey:(NSString *)key ofInstance:(FFGLPluginInstance)instance;
- (void)_setTime:(NSTimeInterval)time ofInstance:(FFGLPluginInstance)instance;
- (BOOL)_processFrameCopy:(FFGLProcessFrameCopyStruct *)frameInfo forInstance:(FFGLPluginInstance)instance;
- (BOOL)_processFrameInPlace:(void *)buffer forInstance:(FFGLPluginInstance)instance;
- (BOOL)_processFrameGL:(FFGLProcessGLStruct *)frameInfo forInstance:(FFGLPluginInstance)instance;
@end


@interface FFGLRenderer (Subclassing)
/* This method is provided by FFGLRenderer for subclasses to use when calling FFGLPlugin's instance methods */
- (FFGLPluginInstance)_instance;

/* Subclasses must implement these methods */
- (BOOL)_implementationSetImage:(FFGLImage *)image forInputAtIndex:(NSUInteger)index;
- (BOOL)_implementationRender;

/* Subclasses should emit output after render using this */
- (void)setOutputImage:(FFGLImage *)image; // using a setter for our public outputImage method makes it play friendly with KVO.
@end

@interface FFGLImage (FFGL)
- (FFGLTextureInfo *)_texture2DInfo;
@end