//
//  VVFFGLPluginManager.h
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//

#import <Cocoa/Cocoa.h>


@interface VVFFGLPluginManager : NSObject {
@private
    NSMutableArray *_sources;
    NSMutableArray *_effects;
}
+ (VVFFGLPluginManager *)sharedManager;
- (void)loadLibraryPlugins;
- (void)loadApplicationPlugins;
- (void)loadPluginsFromDirectory:(NSString *)path;
- (NSArray *)plugins;
- (NSArray *)sourcePlugins;
- (NSArray *)effectPlugins;
@end
