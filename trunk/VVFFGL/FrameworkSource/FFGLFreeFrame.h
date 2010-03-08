/*
 *  FFGLFreeFrame.h
 *
 *  Created by Tom Butterworth on 28/10/2009.
 *
 */

#include <stdint.h>

#define FF_SUCCESS		0U
#define FF_FAIL			0xFFFFFFFF
#define FF_TRUE			1U
#define FF_FALSE		0U
#define FF_SUPPORTED		1U
#define FF_UNSUPPORTED		0U

typedef enum {
    FF_GETINFO			= 0,
    FF_INITIALISE		= 1,
    FF_DEINITIALISE		= 2,
    FF_PROCESSFRAME		= 3,
    FF_GETNUMPARAMETERS		= 4,
    FF_GETPARAMETERNAME		= 5,
    FF_GETPARAMETERDEFAULT	= 6,
    FF_GETPARAMETERDISPLAY	= 7,
    FF_SETPARAMETER		= 8,
    FF_GETPARAMETER		= 9,
    FF_GETPLUGINCAPS		= 10,
    FF_INSTANTIATE		= 11,
    FF_DEINSTANTIATE		= 12,
    FF_GETEXTENDEDINFO		= 13,
    FF_PROCESSFRAMECOPY		= 14,
    FF_GETPARAMETERTYPE		= 15,
    FF_GETINPUTSTATUS		= 16,
    FF_PROCESSOPENGL		= 17,
    FF_INSTANTIATEGL		= 18,
    FF_DEINSTANTIATEGL		= 19,
    FF_SETTIME			= 20
} FFFunctionCode;


typedef union FFMixed {
    uint32_t	UIntValue;
    void*	PointerValue;
} FFMixed;


#define FF_CAP_16BITVIDEO	    0U
#define FF_CAP_24BITVIDEO	    1U
#define FF_CAP_32BITVIDEO	    2U
#define FF_CAP_PROCESSFRAMECOPY	    3U
#define FF_CAP_PROCESSOPENGL	    4U
#define FF_CAP_SETTIME		    5U
#define FF_CAP_MINIMUMINPUTFRAMES   10U
#define FF_CAP_MAXIMUMINPUTFRAMES   11U
#define FF_CAP_COPYORINPLACE	    15U

#define FF_CAP_PREFER_NONE	    0U
#define FF_CAP_PREFER_INPLACE	    1U
#define FF_CAP_PREFER_COPY	    2U
#define	FF_CAP_PREFER_BOTH	    3U

typedef enum {
    FF_TYPE_BOOLEAN		= 0,
    FF_TYPE_EVENT		= 1,
    FF_TYPE_RED			= 2,
    FF_TYPE_GREEN		= 3,
    FF_TYPE_BLUE		= 4,
    FF_TYPE_XPOS		= 5,
    FF_TYPE_YPOS		= 6,
    FF_TYPE_STANDARD		= 10,
    FF_TYPE_ALPHA		= 11,
    FF_TYPE_TEXT		= 100
} FFParameterType;

typedef enum {
    FF_PLUGIN_EFFECT		= 0,
    FF_PLUGIN_SOURCE		= 1
} FFPluginType;

typedef struct FFPluginInfoStruct {
    uint32_t		APIMajorVersion;
    uint32_t		APIMinorVersion;
    char		PluginUniqueID[4];
    char		PluginName[16];
    uint32_t		PluginType;
} FFPluginInfoStruct;

typedef enum {
    FF_ORIENTATION_TL		= 1,
    FF_ORIENTATION_BL		= 2
} FFVideoOrientation;

typedef struct FFVideoInfoStruct {
    uint32_t		FrameWidth;
    uint32_t		FrameHeight;
    uint32_t		BitDepth;
    uint32_t		Orientation;
} FFVideoInfoStruct;

typedef struct FFSetParameterStruct {
    uint32_t		ParameterNumber;
    FFMixed		NewParameterValue;
} FFSetParameterStruct;

typedef struct FFPluginExtendedInfoStruct {
    uint32_t		PluginMajorVersion;
    uint32_t		PluginMinorVersion;
    char*		Description;
    char*		About;
    uint32_t		FreeFrameExtendedDataSize;
    void*		FreeFrameExtendedDataBlock;
} FFPluginExtendedInfoStruct;

typedef struct FFProcessFrameCopyStruct {
    uint32_t		numInputFrames;
    void**		ppInputFrames;
    void*		pOutputFrame;
} FFProcessFrameCopyStruct;

typedef struct FFGLTextureStruct {
    uint32_t		Width;
    uint32_t		Height;
    uint32_t		HardwareWidth;
    uint32_t		HardwareHeight;
    uint32_t		Handle;
} FFGLTextureStruct;

typedef struct FFGLViewportStruct {
    uint32_t		X;
    uint32_t		Y;
    uint32_t		Width;
    uint32_t		Height;
} FFGLViewportStruct;

typedef struct FFProcessOpenGLStruct {
    uint32_t		numInputTextures;
    FFGLTextureStruct**	ppInputTextures;
    uint32_t		HostFBO;
} FFProcessOpenGLStruct;

typedef void* FFInstanceID;

FFMixed plugMain(FFFunctionCode functionCode, FFMixed inputValue, FFInstanceID instanceID);
typedef FFMixed (*FF_Main_FuncPtr)(FFFunctionCode functionCode, FFMixed inputValue, FFInstanceID instanceID);
