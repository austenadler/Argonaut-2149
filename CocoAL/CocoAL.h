//
//  CocoAL.h
//  Argonaut
//
//  Created by user on 12/20/24.
//
//

#import <Foundation/Foundation.h>
#import <OpenAL/al.h>
#import <OpenAL/alc.h>
#include <CoreFoundation/CoreFoundation.h>
#include <AudioToolbox/AudioToolbox.h>

// The pool size for ad-hoc sources for sound effects
#define NUM_SFX_SOURCES 30

#define DEFAULT_MIN_DISTANCE 0.0f
#define DEFAULT_MAX_DISTANCE 1000.0f
// The original max volume sent to FMOD in the previous version of the code
#define MAX_VOLUME 255.0f
// The original frequency sent to FMOD in the previous version of the code
#define ORIG_FMOD_FREQUENCY 44100
// I don't see a way to set a global distance factor like FMOD's FSOUND_3D_SetDistanceFactor, so we will multiply it manually
#define DISTANCE_FACTOR 3.0f

// An OpenAL source that frees the resource when deallocated
@interface CocoALBuffer : NSObject {
    ALuint buffer;
    float minDistance, maxDistance, volume;
    bool set2d;
}
-(id)initWithBuffer:(ALuint)b;
-(ALuint)get;
-(ALuint)loadAudioFile:(NSString *)inputFilename;
-(void)setMinDistance:(float)minDistance maxDistance:(float)maxDistance;
-(ALfloat)getMinDistance;
-(ALfloat)getMaxDistance;
-(ALfloat)getVolume;
-(BOOL)get2d;
-(void)set2d;
-(void)setVolume:(float)to;
@end

// An OpenAL source that frees the resource when deallocated
@interface CocoALSourceFixed : NSObject {
    ALuint source;
}
-(id)initWithSource:(ALuint)s;
-(ALuint)get;
-(BOOL)setMinDistance:(float)minDistance maxDistance:(float)maxDistance;
-(BOOL)playBuffer:(ALuint)buffer;
-(BOOL)setLooping:(BOOL)to;
-(BOOL)stopPlaying;
-(BOOL)isPlaying;
-(BOOL)setVolume:(float)to;
-(BOOL)setFrequency:(float)to;
-(BOOL)play;
//-(BOOL)queueBuffers:(ALuint *) buffers num:(uint)num;
-(BOOL)loadBuffer:(CocoALBuffer *)buffer;
-(BOOL)set2d;
@end

@interface CocoAL : NSObject {
    ALCdevice *device;
    ALCcontext *context;
    CocoALSourceFixed **sfxSources;
    uint currentSfxSource;
}
-(id)init;
+(CocoAL *)SharedInstance;

-(CocoALBuffer **)genBuffers:(uint)count inputFilenames:(NSArray *)inputFilenames;
-(CocoALBuffer *)genBuffer:(NSString *)inputFilename;
-(CocoALSourceFixed **)genSources:(uint)count;

//-(CocoALBuffer *)genBuffer:(NSString *)inputFilename;
-(CocoALSourceFixed **)genSourcesWithBuffers:(uint)count buffers:(CocoALBuffer **)buffers;
-(CocoALSourceFixed *)genSourceWithBuffer:(CocoALBuffer *)buffer;

// Get the next free sfx source
-(CocoALSourceFixed *)nextFreeSfxSource;

+(ALuint *)loadAudioDataAsPcm:(NSString *)inputFilename
                   outDataSize:(ALsizei *)outDataSize
                 outDataFormat:(ALenum *)outDataFormat
                outSampleRate:(ALsizei*)outSampleRate;

-(BOOL)setListenerXPos:(float)xpos
                  yPos:(float)ypos
                  zPos:(float)zpos
                  xVel:(float)xvel
                  yVel:(float)yvel
                  zVel:(float)zvel
              rotation:(float)rot;
-(BOOL)playSoundEffect:(CocoALBuffer *)effectBuffer;
-(BOOL)playSoundEffectPos:(CocoALBuffer *)effectBuffer
                  xPos:(float)xpos yPos:(float)ypos zPos:(float)zpos xvel:(float)xvel yvel:(float)yvel zvel:(float)zvel;
@end