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

typedef struct FFGLPluginManagerPrivate {
	NSMutableArray  *sources;
	NSMutableArray  *effects;
	BOOL            autoLoads;
	BOOL            libraryLoaded;
	BOOL            appLoaded;
	
}FFGLPluginManagerPrivate;

#define ffglPMPrivate(x) ((FFGLPluginManagerPrivate *)_private)->x

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
    @synchronized([FFGLPluginManager class]) {
        if (_sharedPluginManager == nil) {
            [[self alloc] init]; // assignment not done here but in alloc
        }
    }
    return _sharedPluginManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized([FFGLPluginManager class]) {
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
		_private = malloc(sizeof(FFGLPluginManagerPrivate));
		if (_private == NULL)
		{
			return nil;
		}
        ffglPMPrivate(sources) = [[NSMutableArray alloc] initWithCapacity:4];
        ffglPMPrivate(effects) = [[NSMutableArray alloc] initWithCapacity:4];
        ffglPMPrivate(autoLoads) = YES;
		ffglPMPrivate(libraryLoaded) = NO;
		ffglPMPrivate(appLoaded) = NO;
    }
    return self;
}
#pragma mark Plugin Management

- (BOOL)loadsPluginsAutomatically
{
    BOOL result;
    @synchronized(self) {
        result = ffglPMPrivate(autoLoads);
    }
    return result;
}

- (void)setLoadsPluginsAutomatically:(BOOL)autoLoads
{
    @synchronized(self)
	{
        ffglPMPrivate(autoLoads) = autoLoads;
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
        if (ffglPMPrivate(libraryLoaded) == NO) {
			// Set _libraryLoaded to YES before we do it, to avoid recursion as KVO looks up the old value
			ffglPMPrivate(libraryLoaded) = YES;
            [self loadPluginsFromDirectories:directories];
        }
    }

}

- (void)loadApplicationPlugins
{
    @synchronized(self)
	{
        if (ffglPMPrivate(appLoaded) == NO)
		{
			// Set _appLoaded to YES before we do it, to avoid recursion as KVO looks up the old value
			ffglPMPrivate(appLoaded) = YES;
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
				if (([plugin type] == FFGLPluginTypeSource) && ![ffglPMPrivate(sources) containsObject:plugin])
				{
					[newSources addObject:plugin];
				}
				else if (([plugin type] == FFGLPluginTypeEffect) && ![ffglPMPrivate(effects) containsObject:plugin])
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
			if (([plugin type] == FFGLPluginTypeSource) && ![ffglPMPrivate(sources) containsObject:plugin])
			{
				[self _addSourcePlugins:array];
			}
			else if (([plugin type] == FFGLPluginTypeEffect) && ![ffglPMPrivate(effects) containsObject:plugin])
			{
				[self _addEffectPlugins:array];
			}
		}
	}
}

- (void)_addSourcePlugins:(NSArray *)plugins
{
	NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([ffglPMPrivate(sources) count], [plugins count])];
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"sourcePlugins"];
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"plugins"];
	[ffglPMPrivate(sources) addObjectsFromArray:plugins];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"plugins"];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"sourcePlugins"];
}

- (void)_addEffectPlugins:(NSArray *)plugins
{	
	NSIndexSet *effectsIndexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([ffglPMPrivate(effects) count], [plugins count])];
	NSIndexSet *allPluginsIndexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([ffglPMPrivate(sources) count] + [ffglPMPrivate(effects) count], [plugins count])];
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:effectsIndexSet forKey:@"effectPlugins"];
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:allPluginsIndexSet forKey:@"plugins"];
	[ffglPMPrivate(effects) addObjectsFromArray:plugins];
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
				NSUInteger index = [ffglPMPrivate(sources) indexOfObject:plugin];
				if (index != NSNotFound)
				{
					NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:index];
					[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:@"sourcePlugins"];
					[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:@"plugins"];
					[ffglPMPrivate(sources) removeObjectAtIndex:index];
					[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:@"plugins"];
					[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:@"sourcePlugins"];
				}
			}
			else if(([plugin type] == FFGLPluginTypeEffect))
			{
				NSUInteger index = [ffglPMPrivate(effects) indexOfObject:plugin];
				if (index != NSNotFound)
				{
					NSIndexSet *effectsIndexSet = [NSIndexSet indexSetWithIndex:index];
					NSIndexSet *allPluginsIndexSet = [NSIndexSet indexSetWithIndex:[ffglPMPrivate(sources) count] + index];
					[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:effectsIndexSet forKey:@"effectPlugins"];
					[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:allPluginsIndexSet forKey:@"plugins"];
					[ffglPMPrivate(effects) removeObjectAtIndex:index];
					[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:allPluginsIndexSet forKey:@"plugins"];
					[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:effectsIndexSet forKey:@"effectPlugins"];
				}
			}
		}
	}
}

- (FFGLPlugin *)pluginWithIdentifier:(NSString *)identifier
{
	NSArray *plugins = self.plugins;
	for (FFGLPlugin *next in plugins)
	{
		if ([[[next attributes] objectForKey:FFGLPluginAttributeIdentifierKey] isEqualToString:identifier])
		{
			return next;
		}
	}
	return nil;
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
        if (ffglPMPrivate(autoLoads))
		{
            [self loadLibraryPlugins];
            [self loadApplicationPlugins];
        }
        copy = [[ffglPMPrivate(sources) copy] autorelease];
    }
    return copy;
}

- (NSArray *)effectPlugins
{
    NSArray *copy;
    @synchronized(self)
	{
        if (ffglPMPrivate(autoLoads))
		{
            [self loadLibraryPlugins];
            [self loadApplicationPlugins];
        }
        copy = [[ffglPMPrivate(effects) copy] autorelease];
    }
    return copy;
}
@end
