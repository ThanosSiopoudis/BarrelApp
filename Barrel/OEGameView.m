/*
 Copyright (c) 2010, OpenEmu Team

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "OEGameView.h"

#import "OEGameDocument.h"
#import "OECompositionPlugin.h"
#import "OEShaderPlugin.h"

#import "OEGameShader.h"
#import "OEGLSLShader.h"
#import "OECGShader.h"
#import "OEMultipassShader.h"

#import "OEBuiltInShader.h"

#import "OEGameCoreHelper.h"

#import <OpenGL/CGLMacro.h>
#import <IOSurface/IOSurface.h>
#import <OpenGL/CGLIOSurface.h>
#import <Accelerate/Accelerate.h>

#import "snes_ntsc.h"

// TODO: bind vsync. Is it even necessary, why do we want it off at all?

#pragma mark -

#define dfl(a,b) [NSNumber numberWithFloat:a],@b

#if CGFLOAT_IS_DOUBLE
#define CGFLOAT_EPSILON DBL_EPSILON
#else
#define CGFLOAT_EPSILON FLT_EPSILON
#endif

#pragma mark -
#pragma mark Display Link

static CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink,const CVTimeStamp *inNow,const CVTimeStamp *inOutputTime,CVOptionFlags flagsIn,CVOptionFlags *flagsOut,void *displayLinkContext)
{
    return [(__bridge OEGameView *)displayLinkContext displayLinkRenderCallback:inOutputTime];
}

static const GLfloat cg_coords[] =
{
    0, 0,
    1, 0,
    1, 1,
    0, 1
};

static NSString *const _OEDefaultVideoFilterKey      = @"videoFilter";
static NSString *const _OESystemVideoFilterKeyFormat = @"videoFilter.%@";

@interface OEGameView ()

// rendering
@property GLuint             gameTexture;
@property IOSurfaceID        gameSurfaceID;
@property IOSurfaceRef       gameSurfaceRef;
@property GLuint            *rttFBOs;
@property GLuint            *rttGameTextures;
@property NSUInteger         frameCount;
@property GLuint            *multipassTextures;
@property GLuint            *multipassFBOs;

@property snes_ntsc_t       *ntscTable;
@property uint16_t          *ntscSource;
@property uint16_t          *ntscDestination;
@property snes_ntsc_setup_t  ntscSetup;
@property GLuint             ntscTexture;
@property int                ntscBurstPhase;
@property int                ntscMergeFields;

@property CVDisplayLinkRef   gameDisplayLinkRef;
@property SyphonServer      *gameServer;

// QC based filters
@property CIImage           *gameCIImage;
@property QCRenderer        *filterRenderer;
@property CGColorSpaceRef    rgbColorSpace;
@property NSTimeInterval     filterTime;
@property NSTimeInterval     filterStartTime;
@property BOOL               filterHasOutputMousePositionKeys;

- (void)OE_renderToTexture:(GLuint)renderTarget usingTextureCoords:(const GLint *)texCoords inCGLContext:(CGLContextObj)cgl_ctx;
- (void)OE_calculateMultipassSizes:(OEMultipassShader *)multipassShader;
- (void)OE_multipassRender:(OEMultipassShader *)multipassShader usingVertices:(const GLfloat *)vertices inCGLContext:(CGLContextObj)cgl_ctx;
- (void)OE_drawSurface:(IOSurfaceRef)surfaceRef inCGLContext:(CGLContextObj)glContext usingShader:(OEGameShader *)shader;
- (NSEvent *)OE_mouseEventWithEvent:(NSEvent *)anEvent;
- (NSDictionary *)OE_shadersForContext:(CGLContextObj)context;
- (void)OE_refreshFilterRenderer;
@end

@implementation OEGameView

- (NSDictionary *)OE_shadersForContext:(CGLContextObj)context
{
    NSMutableDictionary *shaders = [NSMutableDictionary dictionary];

    for(OEShaderPlugin *plugin in [OEShaderPlugin allPlugins])
        shaders[[plugin name]] = [plugin shaderWithContext:context];

    return shaders;
}

+ (NSOpenGLPixelFormat *)defaultPixelFormat
{
    // choose our pixel formats
    NSOpenGLPixelFormatAttribute attr[] =
    {
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAllowOfflineRenderers,
        0
    };

    return [[NSOpenGLPixelFormat alloc] initWithAttributes:attr];
}

// Warning: - because we are using a superview with a CALayer for transitioning, we have prepareOpenGL called more than once.
// What to do about that?
- (void)prepareOpenGL
{
    [super prepareOpenGL];

    DLog(@"prepareOpenGL");
    // Synchronize buffer swaps with vertical refresh rate
    GLint swapInt = 1;

    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];

    CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
    CGLLockContext(cgl_ctx);

    // GL resources
    glGenTextures(1, &_gameTexture);

    // Resources for render-to-texture pass
    _rttGameTextures = (GLuint *) malloc(OEFramesSaved * sizeof(GLuint));
    _rttFBOs         = (GLuint *) malloc(OEFramesSaved * sizeof(GLuint));

    glGenTextures(OEFramesSaved, _rttGameTextures);
    glGenFramebuffersEXT(OEFramesSaved, _rttFBOs);
    for(NSUInteger i = 0; i < OEFramesSaved; ++i)
    {
        glBindTexture(GL_TEXTURE_2D, _rttGameTextures[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _rttFBOs[i]);
        glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _rttGameTextures[i], 0);
    }

    GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
    if(status != GL_FRAMEBUFFER_COMPLETE_EXT)
        NSLog(@"failed to make complete framebuffer object %x", status);

    // Resources for multipass-rendering
    _multipassTextures = (GLuint *) malloc(OEMultipasses * sizeof(GLuint));
    _multipassFBOs     = (GLuint *) malloc(OEMultipasses * sizeof(GLuint));

    glGenTextures(OEMultipasses, _multipassTextures);
    glGenFramebuffersEXT(OEMultipasses, _multipassFBOs);

    for(NSUInteger i = 0; i < OEMultipasses; ++i)
    {
        glBindTexture(GL_TEXTURE_2D, _multipassTextures[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);

        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _multipassFBOs[i]);
        glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _multipassTextures[i], 0);
    }

    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);

    // Setup resources needed for Blargg's NTSC filter
    _ntscMergeFields = 1;
    _ntscBurstPhase  = 0;
    _ntscTable       = (snes_ntsc_t *) malloc(sizeof(snes_ntsc_t));
    _ntscSetup       = snes_ntsc_composite;
    _ntscSetup.merge_fields = _ntscMergeFields;
    snes_ntsc_init(_ntscTable, &_ntscSetup);

    glGenTextures(1, &_ntscTexture);
    glBindTexture(GL_TEXTURE_2D, _ntscTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
    glBindTexture(GL_TEXTURE_2D, 0);

    _frameCount = 0;

    _filters = [self OE_shadersForContext:cgl_ctx];
    self.gameServer = [[SyphonServer alloc] initWithName:self.gameTitle context:cgl_ctx options:nil];

    CGLUnlockContext(cgl_ctx);

    // filters
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *filter;
    if(filter == nil)
    {
        filter = [defaults objectForKey:_OEDefaultVideoFilterKey];
    }
    [self setFilterName:filter];

    // our texture is in NTSC colorspace from the cores
    _rgbColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);

    _gameSurfaceID = _rootProxy.surfaceID;

    // rendering
    [self setupDisplayLink];
    [self rebindIOSurface];
}

- (void)toggleVSync:(GLint)swapInt
{
    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
}

- (void)setPauseEmulation:(BOOL)paused
{
    if(paused)
        CVDisplayLinkStop(_gameDisplayLinkRef);
    else
        CVDisplayLinkStart(_gameDisplayLinkRef);
}

- (void)setGameTitle:(NSString *)title
{
    if(_gameTitle != title)
    {
        _gameTitle = [title copy];
        [self.gameServer setName:title];
    }
}

- (void)removeFromSuperview
{
    DLog(@"removeFromSuperview");

    CVDisplayLinkStop(_gameDisplayLinkRef);

    [super removeFromSuperview];
}

- (void)clearGLContext
{
    DLog(@"clearGLContext");

    CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
    CGLLockContext(cgl_ctx);

    glDeleteTextures(1, &_gameTexture);
    _gameTexture = 0;

    glDeleteTextures(OEFramesSaved, _rttGameTextures);
    free(_rttGameTextures);
    _rttGameTextures = 0;
    glDeleteFramebuffersEXT(OEFramesSaved, _rttFBOs);
    free(_rttFBOs);
    _rttFBOs = 0;

    glDeleteTextures(OEMultipasses, _multipassTextures);
    free(_multipassTextures);
    _multipassTextures = 0;

    glDeleteFramebuffersEXT(OEMultipasses, _multipassFBOs);
    free(_multipassFBOs);
    _multipassFBOs = 0;

    free(_ntscTable);
    _ntscTable = 0;
    free(_ntscSource);
    _ntscSource = 0;
    free(_ntscDestination);
    _ntscDestination = 0;
    glDeleteTextures(1, &_ntscTexture);
    _ntscTexture = 0;

    CGLUnlockContext(cgl_ctx);
    [super clearGLContext];
}

- (void)setupDisplayLink
{
    if(_gameDisplayLinkRef) [self tearDownDisplayLink];

    CVReturn error = CVDisplayLinkCreateWithActiveCGDisplays(&_gameDisplayLinkRef);
    if(error != kCVReturnSuccess)
    {
        NSLog(@"DisplayLink could notbe created for active displays, error:%d", error);
        _gameDisplayLinkRef = NULL;
        return;
    }

    error = CVDisplayLinkSetOutputCallback(_gameDisplayLinkRef, &MyDisplayLinkCallback, (__bridge void *)self);
	if(error != kCVReturnSuccess)
    {
        NSLog(@"DisplayLink could not link to callback, error:%d", error);
        CVDisplayLinkRelease(_gameDisplayLinkRef);
        _gameDisplayLinkRef = NULL;
        return;
    }

    // Set the display link for the current renderer
    CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
    CGLPixelFormatObj cglPixelFormat = CGLGetPixelFormat(cgl_ctx);

    error = CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(_gameDisplayLinkRef, cgl_ctx, cglPixelFormat);
	if(error != kCVReturnSuccess)
    {
        NSLog(@"DisplayLink could not link to GL Context, error:%d", error);
        CVDisplayLinkRelease(_gameDisplayLinkRef);
        _gameDisplayLinkRef = NULL;
        return;
    }

    CVDisplayLinkStart(_gameDisplayLinkRef);

	if(!CVDisplayLinkIsRunning(_gameDisplayLinkRef))
	{
        CVDisplayLinkRelease(_gameDisplayLinkRef);
        _gameDisplayLinkRef = NULL;

		NSLog(@"DisplayLink is not running - it should be. ");
	}
}

- (void)rebindIOSurface
{
    CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];

    if(_gameSurfaceRef != NULL) CFRelease(_gameSurfaceRef);

    _gameSurfaceRef = IOSurfaceLookup(_gameSurfaceID);

    if(_gameSurfaceRef == NULL) return;

    glEnable(GL_TEXTURE_RECTANGLE_EXT);
    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _gameTexture);
    CGLTexImageIOSurface2D(cgl_ctx, GL_TEXTURE_RECTANGLE_EXT, GL_RGBA8, IOSurfaceGetWidth(_gameSurfaceRef), IOSurfaceGetHeight(_gameSurfaceRef), GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, _gameSurfaceRef, 0);
}

- (void)tearDownDisplayLink
{
    DLog(@"deleteDisplayLink");

    CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
    CGLLockContext(cgl_ctx);

    CVDisplayLinkStop(_gameDisplayLinkRef);

    CVDisplayLinkSetOutputCallback(_gameDisplayLinkRef, NULL, NULL);

    // we really ought to wait.
    while(CVDisplayLinkIsRunning(_gameDisplayLinkRef))
        DLog(@"waiting for displaylink to stop");

    CVDisplayLinkRelease(_gameDisplayLinkRef);
    _gameDisplayLinkRef = NULL;

    CGLUnlockContext(cgl_ctx);
}

- (void)dealloc
{
    [self unbind:@"filterName"];

    DLog(@"OEGameView dealloc");
    [self tearDownDisplayLink];

    [self.gameServer setName:@""];
    [self.gameServer stop];
    self.gameServer = nil;

    self.gameResponder = nil;
    self.rootProxy = nil;

    self.gameCIImage = nil;

    // filters
    self.filters = nil;
    self.filterRenderer = nil;
    self.filterName = nil;

    CGColorSpaceRelease(_rgbColorSpace);
    _rgbColorSpace = NULL;

    if(_gameSurfaceRef != NULL) CFRelease(_gameSurfaceRef);
}

#pragma mark -
#pragma mark Rendering

- (void)reshape
{
    DLog(@"reshape");

    CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
    CGLSetCurrentContext(cgl_ctx);
	CGLLockContext(cgl_ctx);
    
	[self update];

	NSRect mainRenderViewFrame = [self frame];
	glViewport(0, 0, mainRenderViewFrame.size.width, mainRenderViewFrame.size.height);

	CGLUnlockContext(cgl_ctx);
}

- (void)update
{
    DLog(@"update");

    CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
	CGLLockContext(cgl_ctx);

    [super update];

    CGLUnlockContext(cgl_ctx);
}

- (void)drawRect:(NSRect)dirtyRect
{
    [self render];
}

- (void)render
{
    // FIXME: Why not using the timestamps passed by parameters ?
    // rendering time for QC filters..
    _filterTime = [NSDate timeIntervalSinceReferenceDate];

    if(_filterStartTime == 0)
    {
        _filterStartTime = _filterTime;
        _filterTime = 0;
    }
    else _filterTime -= _filterStartTime;

    if(_gameSurfaceRef == NULL) [self rebindIOSurface];

    // get our IOSurfaceRef from our passed in IOSurfaceID from our background process.
    if(_gameSurfaceRef != NULL)
    {
        NSDictionary *options = [NSDictionary dictionaryWithObject:(__bridge id)_rgbColorSpace forKey:kCIImageColorSpace];

        CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];

        [[self openGLContext] makeCurrentContext];

        CGLLockContext(cgl_ctx);

        OEGameShader *shader = [_filters objectForKey:_filterName];

        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();

        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();

        if(shader != nil)
            [self OE_drawSurface:_gameSurfaceRef inCGLContext:cgl_ctx usingShader:shader];
        else
        {
            // Since our filters no longer rely on QC, it may not be around.
            if(_filterRenderer == nil) [self OE_refreshFilterRenderer];

            if(_filterRenderer != nil)
            {
                NSDictionary *arguments = nil;

                NSWindow *gameWindow = [self window];
                NSRect  frame = [self frame];
                NSPoint mouseLocation = [gameWindow mouseLocationOutsideOfEventStream];

                mouseLocation.x /= frame.size.width;
                mouseLocation.y /= frame.size.height;

                arguments = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSValue valueWithPoint:mouseLocation], QCRendererMouseLocationKey,
                             [gameWindow currentEvent], QCRendererEventKey,
                             nil];

                [_filterRenderer setValue:[self gameCIImage] forInputKey:@"OEImageInput"];
                [_filterRenderer renderAtTime:_filterTime arguments:arguments];
            }
        }

        [[self openGLContext] flushBuffer];

        CGLUnlockContext(cgl_ctx);
    }
    else
    {
        // note that a null surface is a valid situation: it is possible that a game document has been opened but the underlying game emulation
        // hasn't started yet
        //NSLog(@"Surface is null");
    }
}

- (void)OE_renderToTexture:(GLuint)renderTarget usingTextureCoords:(const GLint *)texCoords inCGLContext:(CGLContextObj)cgl_ctx
{
    const GLfloat vertices[] =
    {
        -1, -1,
         1, -1,
         1,  1,
        -1,  1
    };

    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _rttFBOs[_frameCount % OEFramesSaved]);

    glBindTexture(GL_TEXTURE_2D, renderTarget);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glEnableClientState( GL_TEXTURE_COORD_ARRAY );
    glTexCoordPointer(2, GL_INT, 0, texCoords );
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer(2, GL_FLOAT, 0, vertices );
    glDrawArrays( GL_TRIANGLE_FAN, 0, 4 );
    glDisableClientState( GL_TEXTURE_COORD_ARRAY );
    glDisableClientState(GL_VERTEX_ARRAY);

    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
    glViewport(0, 0, self.frame.size.width, self.frame.size.height);
}

// calculates the texture size for each pass
- (void)OE_calculateMultipassSizes:(OEMultipassShader *)multipassShader
{
    
}

- (void)OE_multipassRender:(OEMultipassShader *)multipassShader usingVertices:(const GLfloat *)vertices inCGLContext:(CGLContextObj)cgl_ctx
{
    const GLfloat rtt_verts[] =
    {
        -1, -1,
         1, -1,
         1,  1,
        -1,  1
    };
    
    NSArray    *shaders        = [multipassShader shaders];
    NSUInteger  numberOfPasses = [multipassShader numberOfPasses];
    [self OE_calculateMultipassSizes:multipassShader];

    
    // render all passes to FBOs
    for(NSUInteger i = 0; i < numberOfPasses; ++i)
    {        
        BOOL   linearFiltering  = [shaders[i] linearFiltering];
        BOOL   floatFramebuffer = [shaders[i] floatFramebuffer];
        GLuint internalFormat   = floatFramebuffer ? GL_RGBA32F_ARB : GL_RGBA8;
        GLuint dataType         = floatFramebuffer ? GL_FLOAT : GL_UNSIGNED_BYTE;

        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _multipassFBOs[i]);
        glBindTexture(GL_TEXTURE_2D, _multipassTextures[i]);


        if(i == 0)
        {
                glBindTexture(GL_TEXTURE_2D, _rttGameTextures[_frameCount % OEFramesSaved]);
        }
        else
            glBindTexture(GL_TEXTURE_2D, _multipassTextures[i - 1]);

        if(linearFiltering)
        {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        }
        else
        {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        }
    }

    // render to screen
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
    glViewport(0, 0, self.frame.size.width, self.frame.size.height);
    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);
    glDisable(GL_TEXTURE_RECTANGLE_EXT);
    glEnable(GL_TEXTURE_2D);

    if(numberOfPasses == 0)
    {
            glBindTexture(GL_TEXTURE_2D, _rttGameTextures[_frameCount % OEFramesSaved]);
    }
    else
        glBindTexture(GL_TEXTURE_2D, _multipassTextures[numberOfPasses - 1]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glEnableClientState( GL_TEXTURE_COORD_ARRAY );
    glTexCoordPointer(2, GL_FLOAT, 0, cg_coords );
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer(2, GL_FLOAT, 0, vertices );
    glDrawArrays( GL_TRIANGLE_FAN, 0, 4 );
    glDisableClientState( GL_TEXTURE_COORD_ARRAY );
    glDisableClientState(GL_VERTEX_ARRAY);
}

// GL render method
- (void)OE_drawSurface:(IOSurfaceRef)surfaceRef inCGLContext:(CGLContextObj)cgl_ctx usingShader:(OEGameShader *)shader
{
    glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
    glPushAttrib(GL_ALL_ATTRIB_BITS);

    // need to add a clear here since we now draw direct to our context
    glClear(GL_COLOR_BUFFER_BIT);

    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _gameTexture);

    if(![shader isBuiltIn] || [(OEBuiltInShader *)shader type] != OEBuiltInShaderTypeLinear)
    {
        glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    }
    glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    // already disabled
    //    glDisable(GL_BLEND);
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);

    glActiveTexture(GL_TEXTURE0);
    glClientActiveTexture(GL_TEXTURE0);
    glColor4f(1.0, 1.0, 1.0, 1.0);

    // calculate aspect ratio
    NSSize scaled;
    float ratio;

    float halfw = scaled.width;
    float halfh = scaled.height;

    const GLfloat verts[] =
    {
        -halfw, -halfh,
         halfw, -halfh,
         halfw,  halfh,
        -halfw,  halfh
    };


    if([shader isBuiltIn])
    {
        glEnableClientState( GL_TEXTURE_COORD_ARRAY );
        glEnableClientState(GL_VERTEX_ARRAY);
        glVertexPointer(2, GL_FLOAT, 0, verts );
        glDrawArrays( GL_TRIANGLE_FAN, 0, 4 );
        glDisableClientState( GL_TEXTURE_COORD_ARRAY );
        glDisableClientState(GL_VERTEX_ARRAY);
    }
    else if([shader isCompiled])
    {
        if([shader isKindOfClass:[OEMultipassShader class]])
        {

            [self OE_multipassRender:(OEMultipassShader *)shader usingVertices:verts inCGLContext:cgl_ctx];
            ++_frameCount;
        }
        else if([shader isKindOfClass:[OECGShader class]])
        {
            // renders to texture because we need TEXTURE_2D not TEXTURE_RECTANGLE
            
            ++_frameCount;
        }
        else
        {
            glUseProgramObjectARB([(OEGLSLShader *)shader programObject]);

            // set up shader uniforms
            glUniform1iARB([(OEGLSLShader *)shader uniformLocationWithName:"OETexture"], 0);

            glEnableClientState( GL_TEXTURE_COORD_ARRAY );
            glEnableClientState(GL_VERTEX_ARRAY);
            glVertexPointer(2, GL_FLOAT, 0, verts );
            glDrawArrays( GL_TRIANGLE_FAN, 0, 4 );
            glDisableClientState( GL_TEXTURE_COORD_ARRAY );
            glDisableClientState(GL_VERTEX_ARRAY);

            // turn off shader - incase we switch toa QC filter or to a mode that does not use it.
            glUseProgramObjectARB(0);
        }
    }

    glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    glPopAttrib();
    glPopClientAttrib();
}

- (CVReturn)displayLinkRenderCallback:(const CVTimeStamp *)timeStamp
{
    @autoreleasepool
    {
        [self render];
    }
    return kCVReturnSuccess;
}

#pragma mark -
#pragma mark Filters and Compositions

- (QCComposition *)composition
{
    return [[OECompositionPlugin pluginWithName:_filterName] composition];
}

- (void)setFilterName:(NSString *)value
{
    if(_filterName != value)
    {
        DLog(@"setting filter name");
        _filterName = [value copy];

        [self OE_refreshFilterRenderer];
        if(_rootProxy != nil) _rootProxy.drawSquarePixels = [self composition] != nil;
    }
}

- (void)OE_refreshFilterRenderer
{
    // If we have a context (ie we are active) lets make a new QCRenderer...
    // but only if its appropriate

    DLog(@"releasing old filterRenderer");

    _filterRenderer = nil;

    if(_filterName == nil) return;

    OEGameShader *filter = [_filters objectForKey:_filterName];

    [filter compileShaders];
    if([filter isKindOfClass:[OEMultipassShader class]])
    {

        if([(OEMultipassShader *)filter NTSCFilter])
        {
            if([(OEMultipassShader *)filter NTSCFilter] == OENTSCFilterTypeComposite)
                _ntscSetup = snes_ntsc_composite;
            else if([(OEMultipassShader *)filter NTSCFilter] == OENTSCFilterTypeSVideo)
                _ntscSetup = snes_ntsc_svideo;
            else if([(OEMultipassShader *)filter NTSCFilter] == OENTSCFilterTypeRGB)
                _ntscSetup = snes_ntsc_rgb;
            snes_ntsc_init(_ntscTable, &_ntscSetup);
        }
    }

    if([_filters objectForKey:_filterName] == nil && [self openGLContext] != nil)
    {
        CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
        CGLLockContext(cgl_ctx);

        DLog(@"making new filter renderer");

        // This will be responsible for our rendering... weee...
        QCComposition *compo = [self composition];

        if(compo != nil)
            _filterRenderer = [[QCRenderer alloc] initWithCGLContext:cgl_ctx
                                                        pixelFormat:CGLGetPixelFormat(cgl_ctx)
                                                         colorSpace:_rgbColorSpace
                                                        composition:compo];

        if(_filterRenderer == nil)
            NSLog(@"Warning: failed to create our filter QCRenderer");

        if(![[_filterRenderer inputKeys] containsObject:@"OEImageInput"])
            NSLog(@"Warning: invalid Filter composition. Does not contain valid image input key");

        if([[_filterRenderer outputKeys] containsObject:@"OEMousePositionX"] && [[_filterRenderer outputKeys] containsObject:@"OEMousePositionY"])
        {
            DLog(@"filter has mouse output position keys");
            self.filterHasOutputMousePositionKeys = YES;
        }
        else
            self.filterHasOutputMousePositionKeys = NO;


        CGLUnlockContext(cgl_ctx);
    }
}

#pragma mark - Screenshots

- (NSImage *)screenshot
{
    
    return nil;
}

#pragma mark -
#pragma mark Game Core

- (void)setRootProxy:(id<OEGameCoreHelper>)value
{
    if(value != _rootProxy)
    {
        _rootProxy = value;
        [_rootProxy setDelegate:self];
        _rootProxy.drawSquarePixels = [self composition] != nil;
    }
}

#pragma mark -
#pragma mark Responder

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
    // By default, AppKit tries to set the child window containing this view as its main & key window
    // upon first mouse. Since our child window shouldn’t behave like a window, we make its parent
    // window (the visible window from the user point of view) main and key.
    // See https://github.com/OpenEmu/OpenEmu/issues/365
    NSWindow *mainWindow = [[self window] parentWindow];
    if(mainWindow)
    {
        [mainWindow makeMainWindow];
        [mainWindow makeKeyWindow];
        return NO;
    }

    return [super acceptsFirstMouse:theEvent];
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (BOOL)becomeFirstResponder
{
    return YES;
}

- (void)setGameResponder:(OESystemResponder *)value
{
    
}

- (void)setNextResponder:(NSResponder *)aResponder
{
    
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"OEGameViewDidMoveToWindow" object:self];
}

#pragma mark -
#pragma mark Events

- (NSEvent *)OE_mouseEventWithEvent:(NSEvent *)anEvent;
{
  
    return nil;
}

- (void)mouseDown:(NSEvent *)theEvent;
{
}

- (void)rightMouseDown:(NSEvent *)theEvent;
{
}

- (void)otherMouseDown:(NSEvent *)theEvent;
{
}

- (void)mouseUp:(NSEvent *)theEvent;
{

}

- (void)rightMouseUp:(NSEvent *)theEvent;
{

}

- (void)otherMouseUp:(NSEvent *)theEvent;
{

}

- (void)mouseMoved:(NSEvent *)theEvent;
{

}

- (void)mouseDragged:(NSEvent *)theEvent;
{

}

- (void)scrollWheel:(NSEvent *)theEvent;
{

}

- (void)rightMouseDragged:(NSEvent *)theEvent;
{
}

- (void)otherMouseDragged:(NSEvent *)theEvent;
{

}

- (void)mouseEntered:(NSEvent *)theEvent;
{

}

- (void)mouseExited:(NSEvent *)theEvent;
{

}

@end
