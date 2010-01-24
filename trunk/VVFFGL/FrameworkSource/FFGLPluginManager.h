//
//  FFGLPluginManager.h
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//

#import <Cocoa/Cocoa.h>

@class FFGLPlugin;

@interface FFGLPluginManager : NSObject {
@private
    NSMutableArray  *_sources;
    NSMutableArray  *_effects;
    BOOL            _auto;
    BOOL            _libraryLoaded;
    BOOL            _appLoaded;
}
/*
 + (FFGLPluginManager *)sharedManager
 
	Returns the unique instance of FFGLPluginManager.
 */
+ (FFGLPluginManager *)sharedManager;

/*
 - (BOOL)loadsPluginsAutomatically
 
	Plugins available on the user's system as well as any bundled with the application will be loaded automatically if this returns YES.
	The default behaviour is to load plugins automatically.
 */
- (BOOL)loadsPluginsAutomatically;

/*
- (void)setLoadsPluginsAutomatically:(BOOL)autoLoads
 
	Enables or disables automatic loading of plugins.
 */
- (void)setLoadsPluginsAutomatically:(BOOL)autoLoads;

/*
 - (void)loadLibraryPlugins

	Loads any plugins available on the local machine or network. Plugins should be installed in "Graphics/FreeFrame Plug-Ins" in the user's or
	machine's Library folder. Additionally, any plugins installed in "Application Support/FreeFrame" will be loaded.
 */
- (void)loadLibraryPlugins;

/*
 - (void)loadApplicationPlugins
 
	Loads any plugins bundled with the current application (typically in "Contents/PlugIns" within the application's bundle).
 */
- (void)loadApplicationPlugins;

/*
 - (void)loadPluginsFromDirectory:(NSString *)path
 
	Loads plugins from the specified directory.
	path should be a path to a directory containing some FreeFrame plugins.
 */
- (void)loadPluginsFromDirectory:(NSString *)path;

/*
 - (void)loadPluginsFromDirectories:(NSArray *)paths
 
	Loads plugins from the specified directories.
	paths should be a NSArray of NSStrings.
 */
- (void)loadPluginsFromDirectories:(NSArray *)paths;

/*
 - (void)unloadPlugin:(FFGLPlugin *)plugin
 
	Unloads the plugin.
	plugin should be a currently loaded plugin.
 */
- (void)unloadPlugin:(FFGLPlugin *)plugin;

/*
 - (NSArray *)plugins
	
	Returns an array of all FFGLPlugins currently loaded. If loadsPluginsAutomatically returns YES, this method will call
	loadLibraryPlugins and loadApplicationPlugins if they haven't already been called.
 */
- (NSArray *)plugins;

/*
 - (NSArray *)sourcePlugins
 
	 Returns an array of all source type FFGLPlugins currently loaded. If loadsPluginsAutomatically returns YES, this method will call
	 loadLibraryPlugins and loadApplicationPlugins if they haven't already been called.
 */
- (NSArray *)sourcePlugins;

/*
 - (NSArray *)effectPlugins
 
	 Returns an array of all effect type FFGLPlugins currently loaded. If loadsPluginsAutomatically returns YES, this method will call
	 loadLibraryPlugins and loadApplicationPlugins if they haven't already been called.
 */
- (NSArray *)effectPlugins;
@end
