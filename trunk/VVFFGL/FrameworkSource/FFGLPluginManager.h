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
    void *_private; 
}
/*
 + (FFGLPluginManager *)sharedManager
 
	Returns the unique instance of FFGLPluginManager.
 */
+ (FFGLPluginManager *)sharedManager;

/*
 @property (readwrite, assign) BOOL loadsPluginsAutomatically
 
	Plugins available on the user's system as well as any bundled with the application will be loaded automatically if this is YES.
	The default behaviour is to load plugins automatically.
 */
@property (readwrite, assign) BOOL loadsPluginsAutomatically;

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
 - (void)loadPluginAtPath:(NSString *)path
 
	Loads the specified plugin.
	path should be the path to a FreeFrame plugin.
 */
- (void)loadPluginAtPath:(NSString *)path;
/*
 - (void)unloadPlugin:(FFGLPlugin *)plugin
 
	Unloads the plugin.
	plugin should be a currently loaded plugin.
 */
- (void)unloadPlugin:(FFGLPlugin *)plugin;

/*
 @property (readonly) NSArray *plugins
	
	Returns an array of all FFGLPlugins currently loaded. If loadsPluginsAutomatically returns YES, this method will call
	loadLibraryPlugins and loadApplicationPlugins if they haven't already been called.
 */
@property (readonly) NSArray *plugins;

/*
 @property (readonly) NSArray *sourcePlugins
 
	 Returns an array of all source type FFGLPlugins currently loaded. If loadsPluginsAutomatically returns YES, this method will call
	 loadLibraryPlugins and loadApplicationPlugins if they haven't already been called.
 */
@property (readonly) NSArray *sourcePlugins;

/*
 @property (readonly) NSArray *effectPlugins
 
	 Returns an array of all effect type FFGLPlugins currently loaded. If loadsPluginsAutomatically returns YES, this method will call
	 loadLibraryPlugins and loadApplicationPlugins if they haven't already been called.
 */
@property (readonly) NSArray *effectPlugins;
@end
