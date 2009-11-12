//
//  FFGLQCPlugIn.h
//  FFGLQC
//
//  Created by Tom on 12/10/2009.
//  Copyright (c) 2009 Tom Butterworth. All rights reserved.
//

#import <Quartz/Quartz.h>
#import <OpenGL/OpenGL.h>
#import <VVFFGL/VVFFGL.h>

@interface FFGLQCPlugIn : QCPlugIn
{
    NSUInteger _settingPluginIndex;
    FFGLPlugin *_plugin;
    BOOL _rendererNeedsRebuild;
    FFGLRenderer *_renderer;
    NSMutableArray *_plugins;
    NSSize _dimensions;
    CGColorSpaceRef _cspace;
    pthread_mutex_t _lock;
}
//@property (assign) NSUInteger settingPluginIndex;
@property (retain) FFGLPlugin *plugin;
@property (assign) BOOL rendererNeedsRebuild;
- (NSArray *)plugins;
/*
Declare here the Obj-C 2.0 properties to be used as input and output ports for the plug-in e.g.
@property double inputFoo;
@property(assign) NSString* outputBar;
You can access their values in the appropriate plug-in methods using self.inputFoo or self.inputBar
*/
@property (assign) id<QCPlugInOutputImageProvider>   outputImage;
@end
