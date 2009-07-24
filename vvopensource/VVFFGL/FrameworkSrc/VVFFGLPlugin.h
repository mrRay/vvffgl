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
- (NSString *)identifier;
- (NSDictionary *)attributes; // Alternatively we could have methods to directly access each attribute?
@end
