//
//  vvFFGLPlugin.h
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
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

typedef NSUInteger VVFFGLPluginMode;
enum {
    VVFFGLPluginModeCPU = 0,
    VVFFGLPluginModeGPU = 1
};

extern NSString * const VVFFGLPluginAttributeNameKey;
extern NSString * const VVFFGLPluginAttributeVersionKey;
extern NSString * const VVFFGLPluginAttributeDescriptionKey;
extern NSString * const VVFFGLPluginAttributeAuthorKey;
extern NSString * const VVFFGLPluginAttributePathKey;

extern NSString * const VVFFGLParameterAttributeTypeKey;
extern NSString * const VVFFGLParameterAttributeNameKey;
extern NSString * const VVFFGLParameterAttributeDefaultValueKey; // For Boolean, Point, Number, String & Color types.
extern NSString * const VVFFGLParameterAttributeMinimumValueKey; // For Point & Number types.
extern NSString * const VVFFGLParameterAttributeMaximumValueKey; // For Point & Number types.
extern NSString * const VVFFGLParameterAttributeRequiredKey; // A NSNumber with a BOOL value.

extern NSString * const VVFFGLParameterTypeBoolean; // A NSNumber with a BOOL value.
extern NSString * const VVFFGLParameterTypeEvent; // A NSNumber with a BOOL value.
//extern NSString * const VVFFGLParameterTypePoint; // This isn't supported by FF, which passes x & y as seperate parameters, but maybe we can synthesize it?
extern NSString * const VVFFGLParameterTypeNumber; // A NSNumber.
extern NSString * const VVFFGLParameterTypeString; // A NSString.
//extern NSString * const VVFFGLParameterTypeColor; // This isn't supported by FF, which passes r, g, b & a as seperate parameters, but maybe we can synthesize it?
extern NSString * const VVFFGLParameterTypeImage; // TODO: !

typedef struct VVFFGLPluginData VVFFGLPluginData; // Private

@interface VVFFGLPlugin : NSObject <NSCopying>{
@private
    VVFFGLPluginData *_pluginData;
}
- (id)initWithPath:(NSString *)path;
- (VVFFGLPluginType)type;
- (VVFFGLPluginMode)mode;
- (NSArray *)supportedBufferPixelFormats;
- (NSString *)identifier;
- (NSDictionary *)attributes;
- (NSArray *)parameterKeys;
- (NSDictionary *)attributesForParameterWithKey:(NSString *)key;
@end
