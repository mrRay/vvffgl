//
//  vvFFGLPlugin.h
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef NSUInteger VVFFGLPluginType;
enum {
    VVFFGLPluginEffectType = 0,
    VVFFGLPluginSourceType = 1
};

extern NSString * const VVFFGLPluginBufferPixelFormatARGB8888;
extern NSString * const VVFFGLPluginBufferPixelFormatBGRA8888;
extern NSString * const VVFFGLPluginBufferPixelFormatRGB888;
extern NSString * const VVFFGLPluginBufferPixelFormatBGR888;
extern NSString * const VVFFGLPluginBufferPixelFormatRGB565;
extern NSString * const VVFFGLPluginBufferPixelFormatBGR565;


// Just now we expose this, but we could have it private and accept any input and handle conversion to/from GL ourselves, or
// keep it, do that and provide this so clients can determine the most efficient input to provide us...
// Also if you can think of a more descriptive name for it, do...
typedef NSUInteger VVFFGLPluginMode;
enum {
    VVFFGLPluginModeCPU = 0,
    VVFFGLPluginModeGPU = 1
};

extern NSString * const VVFFGLPluginAttributesNameKey;
extern NSString * const VVFFGLPluginAttributesVersionKey;
extern NSString * const VVFFGLPluginAttributesDescriptionKey;
extern NSString * const VVFFGLPluginAttributesAuthorKey;

typedef struct VVFFGLPluginData VVFFGLPluginData; // Private

@interface VVFFGLPlugin : NSObject {
@private
    VVFFGLPluginData *_pluginData;
}
- (id)initWithPath:(NSString *)path;
- (VVFFGLPluginType)type;
- (VVFFGLPluginMode)mode;
- (NSArray *)supportedBufferPixelFormats;
- (NSString *)identifier;
- (NSDictionary *)attributes; // Alternatively we could have methods to directly access each attribute?
@end
