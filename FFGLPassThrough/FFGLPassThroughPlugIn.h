//
//  FFGLPassThroughPlugIn.h
//  FFGLPassThrough
//
//  Created by Tom on 29/10/2009.
//  Copyright (c) 2009 Tom Butterworth. All rights reserved.
//

#import <Quartz/Quartz.h>

@interface FFGLPassThroughPlugIn : QCPlugIn
{
    CGColorSpaceRef _cspace;
}

/*
Declare here the Obj-C 2.0 properties to be used as input and output ports for the plug-in e.g.
@property double inputFoo;
@property(assign) NSString* outputBar;
You can access their values in the appropriate plug-in methods using self.inputFoo or self.inputBar
*/
@property (assign) id <QCPlugInInputImageSource> inputImage;
@property (assign) id <QCPlugInOutputImageProvider> outputImage;
@end
