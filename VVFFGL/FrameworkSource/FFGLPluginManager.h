//
//  FFGLPluginManager.h
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//

#import <Cocoa/Cocoa.h>

@class FFGLPlugin;


///	Loads plugins from disk, instantiates plugins for you to work with.
/*!
An instance of FFGLPluginManager is automatically created when you call the singleton method "sharedManager", which returns a pointer to it.  The general workflow is to use the main isntance of FFGLPluginManager to load plugins from a directory on disk- the loaded plugins may then be accessed, browsed, etc.
*/
@interface FFGLPluginManager : NSObject {
@private
    void *_private; 
}
/*!
	Returns the unique instance of FFGLPluginManager.
 */
+ (FFGLPluginManager *)sharedManager;

/*!
	Plugins available on the user's system as well as any bundled with the application will be loaded automatically if this is YES.  The default behaviour is to load plugins automatically.
 */
@property (readwrite, assign) BOOL loadsPluginsAutomatically;

/*!
	Loads any plugins available on the local machine or network. Plugins should be installed in "Graphics/FreeFrame Plug-Ins" in the user's or machine's Library folder. Additionally, any plugins installed in "Application Support/FreeFrame" will be loaded.
 */
- (void)loadLibraryPlugins;

/*!
	Loads any plugins bundled with the current application (typically in "Contents/PlugIns" within the application's bundle).
 */
- (void)loadApplicationPlugins;

/*!
	Loads plugins from the specified directory.
	@param path should be a path to a directory containing some FreeFrame plugins.
 */
- (void)loadPluginsFromDirectory:(NSString *)path;

/*!
	Loads plugins from the specified directories.
	@param paths should be a NSArray of NSStrings.
 */
- (void)loadPluginsFromDirectories:(NSArray *)paths;

/*!
	Loads the specified plugin.
	@param path should be the path to a FreeFrame plugin.
 */
- (void)loadPluginAtPath:(NSString *)path;

/*!
	Unloads the plugin.
	@param plugin should be a currently loaded plugin.
 */
- (void)unloadPlugin:(FFGLPlugin *)plugin;

/*!
	Returns the first instance of a FFGLPlugin with a matching identifier, or nil if none exists. You can obtain the identifier for a plugin by querying the FFGLPluginAttributeIdentifierKey of the plugins attributes dictionary. Note that there is no centralised control for plugin identifiers, and two FFGLPlugins may have the same identifier and may or may not be instances of the same plugin. If loadsPluginsAutomatically returns YES, this method will call loadLibraryPlugins and loadApplicationPlugins if they haven't already been called.
 */
- (FFGLPlugin *)pluginWithIdentifier:(NSString *)identifier;

/*!
	Returns an array of all FFGLPlugins currently loaded. If loadsPluginsAutomatically returns YES, this method will call loadLibraryPlugins and loadApplicationPlugins if they haven't already been called.
 */
@property (readonly) NSArray *plugins;

/*!
	 Returns an array of all source type FFGLPlugins currently loaded. If loadsPluginsAutomatically returns YES, this method will call loadLibraryPlugins and loadApplicationPlugins if they haven't already been called.
 */
@property (readonly) NSArray *sourcePlugins;

/*!
	 Returns an array of all effect type FFGLPlugins currently loaded. If loadsPluginsAutomatically returns YES, this method will call loadLibraryPlugins and loadApplicationPlugins if they haven't already been called.
 */
@property (readonly) NSArray *effectPlugins;
@end
