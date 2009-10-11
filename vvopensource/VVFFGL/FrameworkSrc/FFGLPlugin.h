//
//  FFGLPlugin.h
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//

#import <Cocoa/Cocoa.h>

typedef NSUInteger FFGLPluginType;
enum {
    FFGLPluginTypeEffect = 0,
    FFGLPluginTypeSource = 1
};

extern NSString * const FFGLPixelFormatARGB8888;
extern NSString * const FFGLPixelFormatBGRA8888;
extern NSString * const FFGLPixelFormatRGB888;
extern NSString * const FFGLPixelFormatBGR888;
extern NSString * const FFGLPixelFormatRGB565;
extern NSString * const FFGLPixelFormatBGR565;

typedef NSUInteger FFGLPluginMode;
enum {
    FFGLPluginModeCPU = 0,
    FFGLPluginModeGPU = 1
};

extern NSString * const FFGLPluginAttributeNameKey;
extern NSString * const FFGLPluginAttributeVersionKey;
extern NSString * const FFGLPluginAttributeDescriptionKey;
extern NSString * const FFGLPluginAttributeIdentifierKey;
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
- (NSDictionary *)attributes;
- (NSArray *)parameterKeys;
- (NSDictionary *)attributesForParameterWithKey:(NSString *)key;
@end
