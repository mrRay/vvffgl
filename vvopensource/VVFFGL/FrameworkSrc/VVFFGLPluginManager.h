//
//  VVFFGLPluginManager.h
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//

#import <Cocoa/Cocoa.h>

/*
 Maybe TODO - comment any ideas on (f)utility, plus any more...
    - allow plugins to be unloaded
    - watch directories for changes and load/unload plugins to match - no need to restart app to add new plugins.
    - notifications
 */

@class VVFFGLPlugin;

@interface VVFFGLPluginManager : NSObject {
@private
    NSMutableArray  *_sources;
    NSMutableArray  *_effects;
    BOOL            _auto;
    BOOL            _libraryLoaded;
    BOOL            _appLoaded;
}
+ (VVFFGLPluginManager *)sharedManager;
- (BOOL)loadsPluginsAutomatically; // Loads library and app plugins. Default is YES, set to NO before any of the ...Plugins methods are called if wanted.
- (void)setLoadsPluginsAutomatically:(BOOL)autoLoads;
- (void)loadLibraryPlugins;
- (void)loadApplicationPlugins;
- (void)loadPluginsFromDirectory:(NSString *)path;
- (void)loadPluginsFromDirectories:(NSArray *)paths;
- (void)unloadPlugin:(VVFFGLPlugin *)plugin;
- (NSArray *)plugins;
- (NSArray *)sourcePlugins;
- (NSArray *)effectPlugins;
@end
