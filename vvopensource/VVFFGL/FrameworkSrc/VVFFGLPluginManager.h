//
//  VVFFGLPluginManager.h
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//

#import <Cocoa/Cocoa.h>

#import "VVFFGLPlugin.h"

#import "FreeFrame.h"
#import "FFGL.h"



@interface VVFFGLPluginManager : NSObject {
@private
    NSMutableArray *_sources;
    NSMutableArray *_effects;
}
+ (VVFFGLPluginManager *)sharedManager;
- (void)loadLibraryPlugins;
- (void)loadApplicationPlugins;
- (void)loadPluginsFromDirectory:(NSString *)path;
- (void)loadPluginsFromDirectories:(NSArray *)paths;
- (NSArray *)plugins;
- (NSArray *)sourcePlugins;
- (NSArray *)effectPlugins;
@end
