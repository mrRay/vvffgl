//
//  FFGLPluginManager.m
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//

#import "FFGLPluginManager.h"
#import "FFGLPlugin.h"

/*
 Maybe TODO - comment any ideas on (f)utility, plus any more...
 - watch directories for changes and load/unload plugins to match - no need to restart app to add new plugins.
 - notifications
 - use nicer locks
 */

static FFGLPluginManager *_sharedPluginManager = nil;

@interface FFGLPluginManager (Private)
// Primitives for adding plugins
// Check for duplicates in _sources/_effects BEFORE using these
- (void)_addSourcePlugins:(NSArray *)plugins;
- (void)_addEffectPlugins:(NSArray *)plugins;
@end
@implementation FFGLPluginManager

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey
{
	BOOL automatic;
    if ([theKey isEqualToString:@"plugins"]
		|| [theKey isEqualToString:@"sourcePlugins"]
		|| [theKey isEqualToString:@"effectPlugins"]) {
		automatic=NO;
    } else {
		automatic=[super automaticallyNotifiesObserversForKey:theKey];
    }
    return automatic;
}

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
    if (self = [super init])
	{
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
    @synchronized(self)
	{
        _auto = autoLoads;
    }
}

- (void)loadLibraryPlugins
{
	NSMutableArray *directories = [NSMutableArray arrayWithCapacity:4];
    NSArray *graphicsDirectories = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
    NSString *path;
    for (path in graphicsDirectories)
	{
        // TODO: Decide where the common plug-in location should be. Probably not the following, think I made it up?
        [directories addObject:[path stringByAppendingPathComponent:@"Graphics/Free Frame Plug-Ins"]];
		// modul8 uses "FreeFrame Plug-Ins", as did the old Apple QC PlugIn example.
		[directories addObject:[path stringByAppendingPathComponent:@"Graphics/FreeFrame Plug-Ins"]];
    }
	NSArray *appSupportDirectories = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSAllDomainsMask, YES);
	for (path in appSupportDirectories)
	{
		// modul8 also uses "FreeFrame" in "Application Support"
		[directories addObject:[path stringByAppendingPathComponent:@"FreeFrame"]];
    }
    @synchronized(self)
	{
        if (_libraryLoaded == NO) {
			// Set _libraryLoaded to YES before we do it, to avoid recursion as KVO looks up the old value
			_libraryLoaded = YES;
            [self loadPluginsFromDirectories:directories];
        }
    }

}

- (void)loadApplicationPlugins
{
    @synchronized(self)
	{
        if (_appLoaded == NO)
		{
			// Set _appLoaded to YES before we do it, to avoid recursion as KVO looks up the old value
			_appLoaded = YES;
            [self loadPluginsFromDirectory:[[NSBundle mainBundle] builtInPlugInsPath]];
        }
    }
}

- (void)loadPluginsFromDirectories:(NSArray *)paths
{
    for (NSString *path in paths)
	{
        [self loadPluginsFromDirectory:path];
    }
}

- (void)loadPluginsFromDirectory:(NSString *)path
{
    @synchronized(self)
	{
        NSArray *contents;
		NSMutableArray *newSources, *newEffects;
		newSources = [NSMutableArray arrayWithCapacity:10];
		newEffects = [NSMutableArray arrayWithCapacity:10];
        NSString *file;
		FFGLPlugin *plugin;
		
        contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
		
		// So far spotted in the wild: .bundle, .frf. If we find others, we could skip this check altogether. .plugin is an Apple-defined extension
		// which gets its own pretty icon, but nobody making FF plugins seems to be using it.
				
		contents = [contents pathsMatchingExtensions:[NSArray arrayWithObjects:@"frf", @"bundle", @"plugin", nil]];
		
		// Rather than call loadPluginAtPath: for each path we load them in bulk to avoid manic KVO messaging
		
        for (file in contents) {
			plugin = [[[FFGLPlugin alloc] initWithPath:[path stringByAppendingPathComponent:file]] autorelease];
			if (plugin != nil)
			{
				if (([plugin type] == FFGLPluginTypeSource) && ![_sources containsObject:plugin])
				{
					[newSources addObject:plugin];
				}
				else if (([plugin type] == FFGLPluginTypeEffect) && ![_effects containsObject:plugin])
				{
					[newEffects addObject:plugin];
				}
			}
        }
		[self _addSourcePlugins:newSources];
		[self _addEffectPlugins:newEffects];		
    }    
}

- (void)loadPluginAtPath:(NSString *)path
{
	FFGLPlugin *plugin = [[[FFGLPlugin alloc] initWithPath:path] autorelease];
	if (plugin != nil)
	{
		NSArray *array = [NSArray arrayWithObject:plugin];
		@synchronized(self)
		{
			if (([plugin type] == FFGLPluginTypeSource) && ![_sources containsObject:plugin])
			{
				[self _addSourcePlugins:array];
			}
			else if (([plugin type] == FFGLPluginTypeEffect) && ![_effects containsObject:plugin])
			{
				[self _addEffectPlugins:array];
			}
		}
	}
}

- (void)_addSourcePlugins:(NSArray *)plugins
{
	NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([_sources count], [plugins count])];
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"sourcePlugins"];
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"plugins"];
	[_sources addObjectsFromArray:plugins];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"plugins"];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"sourcePlugins"];
}

- (void)_addEffectPlugins:(NSArray *)plugins
{	
	NSIndexSet *effectsIndexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([_effects count], [plugins count])];
	NSIndexSet *allPluginsIndexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([_sources count] + [_effects count], [plugins count])];
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:effectsIndexSet forKey:@"effectPlugins"];
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:allPluginsIndexSet forKey:@"plugins"];
	[_effects addObjectsFromArray:plugins];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:allPluginsIndexSet forKey:@"plugins"];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:effectsIndexSet forKey:@"effectPlugins"];
}

- (void)unloadPlugin:(FFGLPlugin *)plugin
{
    @synchronized(self)
	{
		if (plugin != nil)
		{
			if (([plugin type] == FFGLPluginTypeSource))
			{
				NSUInteger index = [_sources indexOfObject:plugin];
				if (index != NSNotFound)
				{
					NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:index];
					[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:@"sourcePlugins"];
					[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:@"plugins"];
					[_sources removeObjectAtIndex:index];
					[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:@"plugins"];
					[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:@"sourcePlugins"];
				}
			}
			else if(([plugin type] == FFGLPluginTypeEffect))
			{
				NSUInteger index = [_effects indexOfObject:plugin];
				if (index != NSNotFound)
				{
					NSIndexSet *effectsIndexSet = [NSIndexSet indexSetWithIndex:index];
					NSIndexSet *allPluginsIndexSet = [NSIndexSet indexSetWithIndex:[_sources count] + index];
					[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:effectsIndexSet forKey:@"effectPlugins"];
					[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:allPluginsIndexSet forKey:@"plugins"];
					[_effects removeObjectAtIndex:index];
					[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:allPluginsIndexSet forKey:@"plugins"];
					[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:effectsIndexSet forKey:@"effectPlugins"];
				}
			}
		}
	}
}

- (NSArray *)plugins
{
    return [[self sourcePlugins] arrayByAddingObjectsFromArray:[self effectPlugins]];        
}

- (NSArray *)sourcePlugins
{
    NSArray *copy;
    @synchronized(self)
	{
        if (_auto)
		{
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
    @synchronized(self)
	{
        if (_auto)
		{
            [self loadLibraryPlugins];
            [self loadApplicationPlugins];
        }
        copy = [[_effects copy] autorelease];
    }
    return copy;
}
@end
