/*
 *  FFGLPluginInstances.h
 *  VVOpenSource
 *
 *  Created by Tom on 26/07/2009.
 *
 */

#import "FFGLPlugin.h"
#import <OpenGL/OpenGL.h>

extern NSString * const FFGLParameterAttributeIndexKey;

typedef uint32_t FFGLPluginInstance;

typedef struct FFGLProcessFrameCopyStruct {
    unsigned int    inputFrameCount;
    void**          inputFrames;
    void*           outputFrame;
} FFGLProcessFrameCopyStruct;

typedef struct FFGLProcessGLStruct {
    unsigned int    inputTextureCount;
    void**          inputTextures;
    GLuint          hostFBO;
} FFGLProcessGLStruct;

@interface FFGLPlugin (Instances)
/* 
 Here we add methods FFGLRenderer uses to deal with instance-related stuff in FFGLPlugin. This header is not
 exported in the framework, it is private for FFGLPlugin and FFGLRenderer and subclasses.
 */

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
- (void)_processFrameCopy:(FFGLProcessFrameCopyStruct *)frameInfo forInstance:(FFGLPluginInstance)instance;
- (void)_processFrameInPlace:(void *)buffer forInstance:(FFGLPluginInstance)instance;
- (void)_processFrameGL:(FFGLProcessGLStruct *)frameInfo forInstance:(FFGLPluginInstance)instance;
@end