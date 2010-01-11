//
//  FFGLPluginManager.m
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//

#import "FFGLPluginManager.h"
#import "FFGLPlugin.h"

static FFGLPluginManager *_sharedPluginManager = nil;

static NSInteger FFGLPluginManagerSortPlugins(FFGLPlugin *first, FFGLPlugin *second, void *context)
{
    NSString *a = [[first attributes] objectForKey:FFGLPluginAttributeNameKey];
    NSString *b = [[second attributes] objectForKey:FFGLPluginAttributeNameKey];
    return [a compare:b];
}

@implementation FFGLPluginManager
#pragma mark Singleton Instance
+ (FFGLPluginManager*)sharedManager
{
    @synchronized(self) {
        if (_sharedPluginManager == nil) {
            [[self alloc] init]; // assignment not done here but in alloc
        }
    }
    return _sharedPluginManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (_sharedPluginManager == nil) {
            _sharedPluginManager = [super allocWithZone:zone];
            return _sharedPluginManager;  // assignment and return on first allocation
        }
    }
    return nil; //on subsequent allocation attempts return nil
}


- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain
{
    return self;
}

- (NSUInteger)retainCount
{
    return UINT_MAX;  //denotes an object that cannot be released
}

- (void)release
{
    //do nothing
}

- (id)autorelease
{
    return self;
}

- (id)init
{
    if (self = [super init]) {
        _sources = [[NSMutableArray alloc] initWithCapacity:4];
        _effects = [[NSMutableArray alloc] initWithCapacity:4];
        _auto = YES;
    }
    return self;
}
#pragma mark Plugin Management

- (BOOL)loadsPluginsAutomatically
{
    BOOL result;
    @synchronized(self) {
        result = _auto;
    }
    return result;
}

- (void)setLoadsPluginsAutomatically:(BOOL)autoLoads
{
    @synchronized(self) {
        _auto = autoLoads;
    }
}

- (void)loadLibraryPlugins
{
	NSMutableArray *directories = [NSMutableArray arrayWithCapacity:4];
    NSArray *graphicsDirectories = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
    NSString *path;
    for (path in graphicsDirectories) {
        // TODO: Decide where the common plug-in location should be. Probably not the following, think I made it up?
        [directories addObject:[path stringByAppendingPathComponent:@"Graphics/Free Frame Plug-Ins"]];
		// modul8 uses "FreeFrame Plug-Ins", as did the old Apple QC PlugIn example.
		[directories addObject:[path stringByAppendingPathComponent:@"Graphics/FreeFrame Plug-Ins"]];
    }
	NSArray *appSupportDirectories = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSAllDomainsMask, YES);
	for (path in appSupportDirectories) {
		// modul8 also uses "FreeFrame" in "Application Support"
		[directories addObject:[path stringByAppendingPathComponent:@"FreeFrame"]];
    }
    @synchronized(self) {
        if (_libraryLoaded == NO) {
            [self loadPluginsFromDirectories:directories];
            _libraryLoaded = YES;
        }
    }

}

- (void)loadApplicationPlugins
{
    @synchronized(self) {
        if (_appLoaded == NO) {
            [self loadPluginsFromDirectory:[[NSBundle mainBundle] builtInPlugInsPath]];
            _appLoaded = YES;
        }
    }
}

- (void)loadPluginsFromDirectories:(NSArray *)paths
{
    for (NSString *path in paths) {
        [self loadPluginsFromDirectory:path];
    }
}

- (void)loadPluginsFromDirectory:(NSString *)path
{
    @synchronized(self) {
        NSArray *contents;
        NSString *file;
        FFGLPlugin *plugin;
        contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
        for (file in contents) {
            // So far spotted in the wild: .bundle, .frf. If we find others, we could skip this check altogether. .plugin is an Apple-defined extension
            // which gets its own pretty icon and can't be opened as a folder in the Finder, but nobody making FF plugins seems to be using it, but they should!
            if([[file pathExtension] isEqualToString:@"frf"] || [[file pathExtension] isEqualToString:@"bundle"]
               || [[file pathExtension] isEqualToString:@"plugin"]) {
                plugin = [[[FFGLPlugin alloc] initWithPath:[path stringByAppendingPathComponent:file]] autorelease];
                if (plugin != nil) {
                    if (([plugin type] == FFGLPluginTypeSource) && ![_sources containsObject:plugin]) {
                        [_sources addObject:plugin];  
                    } else if(([plugin type] == FFGLPluginTypeEffect) && ![_effects containsObject:plugin]) {
                        [_effects addObject:plugin];
                    }
                }
            }
        }
	[_sources sortUsingFunction:FFGLPluginManagerSortPlugins context:NULL];
	[_effects sortUsingFunction:FFGLPluginManagerSortPlugins context:NULL];
    }    
}

- (void)unloadPlugin:(FFGLPlugin *)plugin
{
    @synchronized(self) {
        [([plugin type] == FFGLPluginTypeSource ? _sources : _effects) removeObject:plugin];        
    }
}

- (NSArray *)plugins
{
    return [[self sourcePlugins] arrayByAddingObjectsFromArray:[self effectPlugins]];        
}

- (NSArray *)sourcePlugins
{
    NSArray *copy;
    @synchronized(self) {
        if (_auto) {
            [self loadLibraryPlugins];
            [self loadApplicationPlugins];
        }
        copy = [[_sources copy] autorelease];
    }
    return copy;
}

- (NSArray *)effectPlugins
{
    NSArray *copy;
    @synchronized(self) {
        if (_auto) {
            [self loadLibraryPlugins];
            [self loadApplicationPlugins];
        }
        copy = [[_effects copy] autorelease];
    }
    return copy;
}
@end
