//
//  FFGLComplianceTests.m
//  VVFFGL
//
//  Created by Tom on 24/01/2011.
//  Copyright 2011 Tom Butterworth. All rights reserved.
//

#import "FFGLComplianceTests.h"
#import "FFGLFreeFrame.h"

@implementation FFGLComplianceTests
- (void)testConformsToSpec
{
	STAssertTrue(sizeof(FFMixed) == sizeof(void *), nil);
	STAssertTrue(sizeof(FFFunctionCode) == 4, nil);
	STAssertTrue(sizeof(FFInstanceID) == sizeof(void *), nil);
	
	STAssertTrue(offsetof(FFPluginInfoStruct, APIMajorVersion) == 0, nil);
	STAssertTrue(offsetof(FFPluginInfoStruct, APIMinorVersion) == 4, nil);
	STAssertTrue(offsetof(FFPluginInfoStruct, PluginUniqueID) == 8, nil);
	STAssertTrue(offsetof(FFPluginInfoStruct, PluginName) == 12, nil);
	STAssertTrue(offsetof(FFPluginInfoStruct, PluginType) == 28, nil);
	
	STAssertTrue(offsetof(FFVideoInfoStruct, FrameWidth) == 0, nil);
	STAssertTrue(offsetof(FFVideoInfoStruct, FrameHeight) == 4, nil);
	STAssertTrue(offsetof(FFVideoInfoStruct, BitDepth) == 8, nil);
	STAssertTrue(offsetof(FFVideoInfoStruct, Orientation) == 12, nil);
	
	STAssertTrue(offsetof(FFSetParameterStruct, ParameterNumber) == 0, nil);
	STAssertTrue(offsetof(FFSetParameterStruct, NewParameterValue) == 4, nil);
	
	STAssertTrue(offsetof(FFPluginExtendedInfoStruct, PluginMajorVersion) == 0, nil);
	STAssertTrue(offsetof(FFPluginExtendedInfoStruct, PluginMinorVersion) == 4, nil);
	STAssertTrue(offsetof(FFPluginExtendedInfoStruct, Description) == 8, nil);
	STAssertTrue(offsetof(FFPluginExtendedInfoStruct, About) == 12, nil);
	STAssertTrue(offsetof(FFPluginExtendedInfoStruct, FreeFrameExtendedDataSize) == 16, nil);
	STAssertTrue(offsetof(FFPluginExtendedInfoStruct, FreeFrameExtendedDataBlock) == 20, nil);
	
	STAssertTrue(offsetof(FFProcessFrameCopyStruct, numInputFrames) == 0, nil);
	STAssertTrue(offsetof(FFProcessFrameCopyStruct, ppInputFrames) == 4, nil);
	STAssertTrue(offsetof(FFProcessFrameCopyStruct, pOutputFrame) == 8, nil);

	STAssertTrue(offsetof(FFGLTextureStruct, Width) == 0, nil);
	STAssertTrue(offsetof(FFGLTextureStruct, Height) == 4, nil);
	STAssertTrue(offsetof(FFGLTextureStruct, HardwareWidth) == 8, nil);
	STAssertTrue(offsetof(FFGLTextureStruct, HardwareHeight) == 12, nil);
	STAssertTrue(offsetof(FFGLTextureStruct, Handle) == 16, nil);
	
	STAssertTrue(offsetof(FFGLViewportStruct, X) == 0, nil);
	STAssertTrue(offsetof(FFGLViewportStruct, Y) == 4, nil);
	STAssertTrue(offsetof(FFGLViewportStruct, Width) == 8, nil);
	STAssertTrue(offsetof(FFGLViewportStruct, Height) == 12, nil);
	
	STAssertTrue(offsetof(FFProcessOpenGLStruct, numInputTextures) == 0, nil);
	STAssertTrue(offsetof(FFProcessOpenGLStruct, ppInputTextures) == 4, nil);
	STAssertTrue(offsetof(FFProcessOpenGLStruct, HostFBO) == 8, nil);
}
@end
