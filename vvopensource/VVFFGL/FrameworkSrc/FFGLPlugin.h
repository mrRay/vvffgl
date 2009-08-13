//
//  FFGLPlugin.h
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//

#import <Cocoa/Cocoa.h>

typedef NSUInteger FFGLPluginType;
enum {
    FFGLPluginEffectType = 0,
    FFGLPluginSourceType = 1
};

extern NSString * const FFGLPluginBufferPixelFormatARGB8888;
extern NSString * const FFGLPluginBufferPixelFormatBGRA8888;
extern NSString * const FFGLPluginBufferPixelFormatRGB888;
extern NSString * const FFGLPluginBufferPixelFormatBGR888;
extern NSString * const FFGLPluginBufferPixelFormatRGB565;
extern NSString * const FFGLPluginBufferPixelFormatBGR565;

typedef NSUInteger FFGLPluginMode;
enum {
    FFGLPluginModeCPU = 0,
    FFGLPluginModeGPU = 1
};

extern NSString * const FFGLPluginAttributeNameKey;
extern NSString * const FFGLPluginAttributeVersionKey;
extern NSString * const FFGLPluginAttributeDescriptionKey;
extern NSString * const FFGLPluginAttributeAuthorKey;
extern NSString * const FFGLPluginAttributePathKey;

extern NSString * const FFGLParameterAttributeTypeKey;
extern NSString * const FFGLParameterAttributeNameKey;
extern NSString * const FFGLParameterAttributeDefaultValueKey; // For Boolean, Point, Number, String & Color types.
extern NSString * const FFGLParameterAttributeMinimumValueKey; // For Point & Number types.
extern NSString * const FFGLParameterAttributeMaximumValueKey; // For Point & Number types.
extern NSString * const FFGLParameterAttributeRequiredKey; // A NSNumber with a BOOL value.

extern NSString * const FFGLParameterTypeBoolean; // A NSNumber with a BOOL value.
extern NSString * const FFGLParameterTypeEvent; // A NSNumber with a BOOL value.
//extern NSString * const FFGLParameterTypePoint; // This isn't supported by FF, which passes x & y as seperate parameters, but maybe we can synthesize it?
extern NSString * const FFGLParameterTypeNumber; // A NSNumber.
extern NSString * const FFGLParameterTypeString; // A NSString.
//extern NSString * const FFGLParameterTypeColor; // This isn't supported by FF, which passes r, g, b & a as seperate parameters, but maybe we can synthesize it?
extern NSString * const FFGLParameterTypeImage; // TODO: !

typedef struct FFGLPluginData FFGLPluginData; // Private

@interface FFGLPlugin : NSObject <NSCopying>{
@private
    FFGLPluginData *_pluginData;
}
- (id)initWithPath:(NSString *)path;
- (FFGLPluginType)type;
- (FFGLPluginMode)mode;
- (NSArray *)supportedBufferPixelFormats;
- (NSString *)identifier; // Maybe move this into the attributes dict?
- (NSDictionary *)attributes;
- (NSArray *)parameterKeys;
- (NSDictionary *)attributesForParameterWithKey:(NSString *)key;
@end
