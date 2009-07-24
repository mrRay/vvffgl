//
//  vvFFGLPlugin.h
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef struct VVFFGLPluginData VVFFGLPluginData;

@interface VVFFGLPlugin : NSObject {
@private
    CFBundleRef _bundle;
    VVFFGLPluginData *_pluginData;
}
- (id)initWithPath:(NSString *)path;
@end
