//
//  CocoAL.m
//  Argonaut
//
//  Created by user on 12/20/24.
//
//

#import "CocoAL.h"

CocoAL *cocoAlSharedInstance = nil;

@implementation CocoAL
-(id)init {
    // Any possible error
    ALCenum error;
    
    // Initialize the device
    device = alcOpenDevice(NULL);
    if(!device) {
        NSLog(@"CocoAL init: Could not open device");
        return nil;
    }
    
    // Initialize the context
    context = alcCreateContext(device, NULL);
    if(!context) {
        NSLog(@"CocoAL init: Could not create context");
        return nil;
    }
    
    if(!alcMakeContextCurrent(context)) {
        NSLog(@"CocoAL init: Could not make context current");
        return nil;
    }
    
    if ((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"CocoAL init: Could not setup the context: %d", error);
        return nil;
    }
    
    // Initialize audio modifiers
    
    // Orig:
    //    [FocoaMod setDopplerFactor: 3.0]; //exagerate the doppler effect
    // New:
    alDopplerFactor(3.0f);
    if ((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"CocoAL init: Could not set the doppler factor: %d", error);
        return nil;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"Item Loaded" object: self];
    NSLog(@"Initialized OpenAL");
    
    sfxSources = [self genSources:NUM_SFX_SOURCES];
    currentSfxSource = 0;
    
    return self;
}

//set the listiners position in 3D space
-(BOOL)setListenerXPos:(float)xpos
                  yPos:(float)ypos
                  zPos:(float)zpos
                  xVel:(float)xvel
                  yVel:(float)yvel
                  zVel:(float)zvel
              rotation:(float)rot {
    
    ALCenum error;
    xpos *= DISTANCE_FACTOR; ypos *= DISTANCE_FACTOR; zpos *= DISTANCE_FACTOR; xvel *= DISTANCE_FACTOR; yvel *= DISTANCE_FACTOR; zvel *= DISTANCE_FACTOR;

    ALfloat pos[]={xpos, ypos, zpos};
    ALfloat vel[]={xvel, yvel, zvel};
    ALfloat ori[]={0.0f, 0.0f, 0.0f, 0.0, 1.0, 0.0};
//    NSLog(@"Setting listener xpos to xyz=(%f, %f, %f), v=(%f, %f, %f)", pos[0], pos[1], pos[2], vel[0], vel[1], vel[2]);
    
    alListenerfv(AL_POSITION, pos);
    if ((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"setListenerXPos: Set position: %d", error);
        return false;
    }
    alListenerfv(AL_VELOCITY, vel);
    if ((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"setListenerXPos: Set veolocity: %d", error);
        return false;
    }
    alListenerfv(AL_ORIENTATION, ori);
    if ((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"setListenerXPos: Set orientation: %d", error);
        return false;
    }
    
    return true;
}

-(BOOL)playSoundEffect:(CocoALBuffer *)effectBuffer {
    ALCenum error;
    CocoALSourceFixed *source = [self nextFreeSfxSource];
    if (!source) {
        NSLog(@"playSoundEffect: No free sources");
        return false;
    }
    if (![source loadBuffer:effectBuffer]) {
        NSLog(@"playSoundEffect: Could not load buffer");
        return false;
    }
    if (![source setVolume:[effectBuffer getVolume]]) {
        NSLog(@"playSoundEffect: Could not set volume");
        // This error is ignorable.
    }
    // TODO: I think this needs to be a 2d sound effect, so we need to call set2d here

    alSourcePlay([source get]);
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"playSoundEffect: Can't play: %d", error);
        return false;
    }
    return true;
}


-(BOOL)playSoundEffectPos:(CocoALBuffer *)effectBuffer
                  xPos:(float)xpos yPos:(float)ypos zPos:(float)zpos xvel:(float)xvel yvel:(float)yvel zvel:(float)zvel {
    ALCenum error;
    // See header for explanation
    xpos *= DISTANCE_FACTOR; ypos *= DISTANCE_FACTOR; zpos *= DISTANCE_FACTOR; xvel *= DISTANCE_FACTOR; yvel *= DISTANCE_FACTOR; zvel *= DISTANCE_FACTOR;

//    NSLog(@"Setting position to (%f, %f, %f) and velocity (%f, %f, %f)", xpos, ypos, zpos, xvel, yvel, zvel);
    CocoALSourceFixed *source = [self nextFreeSfxSource];
    if (!source) {
        NSLog(@"playSoundEffectPos: No free sources");
        return false;
    }
    if (![source loadBuffer:effectBuffer]) {
        NSLog(@"playSoundEffectPos: Could not load buffer");
        return false;
    }
    // If they set a max distance, use it. Otherwise, use the defaults
    // We have to update it each time because we are not allocating a new source each time -- we are reusing from a pool
    if ([effectBuffer getMaxDistance] >= 0.0f) {
        [source setMinDistance:[effectBuffer getMinDistance] maxDistance:[effectBuffer getMaxDistance]];
    } else {
        [source setMinDistance:DEFAULT_MIN_DISTANCE maxDistance:DEFAULT_MAX_DISTANCE];
    }
    
    if (![source setVolume:[effectBuffer getVolume]]) {
        NSLog(@"playSoundEffectPos: Setting volume");
        // This is an ignorable error
    }
    
    alSourcef([source get], AL_REFERENCE_DISTANCE, 1000.0f);
    if ((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"playSoundEffectPos: Set reference distance: %d", error);
        return false;
    }

    if ([effectBuffer get2d]) {
        // Play as a 2d sound by setting position and velocity to 0 (relative to self)
        [source set2d];
    } else {
        // This is a regular, 3d sound, so we need to set position and velocity
        ALfloat pos[]={xpos, ypos, zpos};
        ALfloat vel[]={xvel, yvel, zvel};
        
        alSourcefv([source get], AL_POSITION, pos);
        if ((error = alGetError()) != AL_NO_ERROR) {
            NSLog(@"playSoundEffectPos: Set position: %d", error);
            return false;
        }
        alSourcefv([source get], AL_VELOCITY, vel);
        if ((error = alGetError()) != AL_NO_ERROR) {
            NSLog(@"playSoundEffectPos: Set veolocity: %d", error);
            return false;
        }
    }
    alSourcePlay([source get]);
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"playSoundEffectPos: Can't play: %d", error);
        return false;
    }
    return true;
}

-(CocoALSourceFixed *)nextFreeSfxSource {
    for (int i = 0; i < NUM_SFX_SOURCES; i++) {
        // The sfx source to check. If it is not playing, then it's free
        uint x = (currentSfxSource + i) % NUM_SFX_SOURCES;
        if (![sfxSources[x] isPlaying]) {
            // The next sound will probably come before this sound ends, so update the currentSfxSource to 1 past the current one
            currentSfxSource = (x+1)%NUM_SFX_SOURCES;
            return sfxSources[x];
        }
    }
    NSLog(@"Found NO available sfx source");
    return nil;
}

-(CocoALBuffer *)genBuffer:(NSString *)inputFilename {
    CocoALBuffer **buffers = [self genBuffers:1 inputFilenames:@[inputFilename]];
    CocoALBuffer *ret = buffers[0];
    free(buffers);

    return ret;
}

-(CocoALBuffer **)genBuffers:(uint)count inputFilenames:(NSArray *)inputFilenames {
    ALCenum error;
    // Use c-style allocation because OpenAL requires it
    ALuint *buffers = (ALuint *)malloc(sizeof(ALuint) * count);
    alGenBuffers(count, buffers);
    if ((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"Could not generate buffers: %d", error);
        free(buffers);
        return nil;
    }
    
    CocoALBuffer **ret = (CocoALBuffer **)malloc(sizeof(CocoALBuffer *) * count);
    for(int i = 0; i < count; i ++) {
        ret[i] = [[CocoALBuffer alloc] initWithBuffer:buffers[i]];
        [ret[i] loadAudioFile: [inputFilenames objectAtIndex:i]];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"Item Loaded" object: self];

    }
    free(buffers);
    
    return ret;
}

-(CocoALSourceFixed *)genSource {
    return [self genSources:1][0];
}
-(CocoALSourceFixed *)genSourceWithBuffer:(CocoALBuffer *)buffer {
    CocoALSourceFixed *source = [self genSource];
    [source loadBuffer:buffer];
    return source;
}
-(CocoALSourceFixed **)genSourcesWithBuffers:(uint)count buffers:(CocoALBuffer **)buffers {
    CocoALSourceFixed **sources = [self genSources:count];
    for(int i = 0; i < count; i++) {
        [sources[i] loadBuffer:buffers[i]];
    }
    return sources;
}
-(CocoALSourceFixed **)genSources:(uint)count {
    ALCenum error;
    ALuint sources[count];
    alGenSources(count, sources);
    if ((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"Could not generate sources: %d", error);
        return nil;
    }
    
    CocoALSourceFixed **ret = (CocoALSourceFixed **)malloc(sizeof(CocoALSourceFixed *) * count);
    for (int i = 0; i < count; i++) {
        ret[i] = [[CocoALSourceFixed alloc] initWithSource:sources[i]];
    }

    return ret;
}


+(id)SharedInstance {
    if (cocoAlSharedInstance == nil) {
        cocoAlSharedInstance = [[CocoAL alloc] init];
    }
    return cocoAlSharedInstance;
}

+(ALuint *)loadAudioDataAsPcm:(NSString *)inputFilename
            outDataSize:(ALsizei *)outDataSize
            outDataFormat:(ALenum *)outDataFormat
            outSampleRate:(ALsizei*)outSampleRate
{
    OSStatus                        err = noErr;
    SInt64                          theFileLengthInFrames = 0;
    AudioStreamBasicDescription     theFileFormat;
    UInt32                          thePropertySize = sizeof(theFileFormat);
    ExtAudioFileRef                 extRef = NULL;
    ALuint*                           theData = NULL;
    AudioStreamBasicDescription     theOutputFormat;
    
    // Convert the input file
    CFURLRef inFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)inputFilename, 0, false);

    
    // Open a file with ExtAudioFileOpen()
    err = ExtAudioFileOpenURL(inFileURL, &extRef);
    if(err) {
        printf("MyGetOpenALAudioData: ExtAudioFileOpenURL FAILED, Error = %i/%ld\n", err, err);
        if (extRef) {ExtAudioFileDispose(extRef);}
        return theData;
    }
    
    // Get the audio data format
    err = ExtAudioFileGetProperty(extRef, kExtAudioFileProperty_FileDataFormat, &thePropertySize, &theFileFormat);
    
    if(err) { printf("MyGetOpenALAudioData: ExtAudioFileGetProperty(kExtAudioFileProperty_FileDataFormat) FAILED, Error = %ld\n", err);
        if (extRef) {ExtAudioFileDispose(extRef);}
        return theData;
    }
    if (theFileFormat.mChannelsPerFrame > 2)  { printf("MyGetOpenALAudioData - Unsupported Format, channel count is greater than stereo\n");
        if (extRef) {ExtAudioFileDispose(extRef);}
        return theData;
        
    }
    
    // Set the client format to 16 bit signed integer (native-endian) data
    // Maintain the channel count and sample rate of the original source format
    theOutputFormat.mSampleRate = theFileFormat.mSampleRate;
    theOutputFormat.mChannelsPerFrame = theFileFormat.mChannelsPerFrame;
    
    theOutputFormat.mFormatID = kAudioFormatLinearPCM;
    theOutputFormat.mBytesPerPacket = 2 * theOutputFormat.mChannelsPerFrame;
    theOutputFormat.mFramesPerPacket = 1;
    theOutputFormat.mBytesPerFrame = 2 * theOutputFormat.mChannelsPerFrame;
    theOutputFormat.mBitsPerChannel = 16;
    theOutputFormat.mFormatFlags = kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;
    
    // Set the desired client (output) data format
    err = ExtAudioFileSetProperty(extRef, kExtAudioFileProperty_ClientDataFormat, sizeof(theOutputFormat), &theOutputFormat);
    if(err) { printf("MyGetOpenALAudioData: ExtAudioFileSetProperty(kExtAudioFileProperty_ClientDataFormat) FAILED, Error = %ld\n", err);
        if (extRef) {ExtAudioFileDispose(extRef);}
        return theData;
    }
    
    // Get the total frame count
    thePropertySize = sizeof(theFileLengthInFrames);
    err = ExtAudioFileGetProperty(extRef, kExtAudioFileProperty_FileLengthFrames, &thePropertySize, &theFileLengthInFrames);
    if(err) { printf("MyGetOpenALAudioData: ExtAudioFileGetProperty(kExtAudioFileProperty_FileLengthFrames) FAILED, Error = %ld\n", err);
        if (extRef) {ExtAudioFileDispose(extRef);}
        return theData;
    }
    
    // Read all the data into memory
    UInt32 theFramesToRead = (UInt32)theFileLengthInFrames;
    UInt32 dataSize = theFramesToRead * theOutputFormat.mBytesPerFrame;;
    theData = (ALuint *)malloc(dataSize);
    if (theData)
    {
        AudioBufferList     theDataBuffer;
        theDataBuffer.mNumberBuffers = 1;
        theDataBuffer.mBuffers[0].mDataByteSize = dataSize;
        theDataBuffer.mBuffers[0].mNumberChannels = theOutputFormat.mChannelsPerFrame;
        theDataBuffer.mBuffers[0].mData = theData;
        
        // Read the data into an AudioBufferList
        err = ExtAudioFileRead(extRef, &theFramesToRead, &theDataBuffer);
        if(err == noErr)
        {
            // success
            *outDataSize = (ALsizei)dataSize;
            *outDataFormat = (theOutputFormat.mChannelsPerFrame > 1) ? AL_FORMAT_STEREO16 : AL_FORMAT_MONO16;
            *outSampleRate = (ALsizei)theOutputFormat.mSampleRate;
        }
        else
        {
            // failure
            free (theData);
            theData = NULL; // make sure to return NULL
            printf("MyGetOpenALAudioData: ExtAudioFileRead FAILED, Error = %ld\n", err);
            if (extRef) {ExtAudioFileDispose(extRef);}
            return theData;
        }
    }
    
    // Dispose the ExtAudioFileRef, it is no longer needed
    if (extRef) {ExtAudioFileDispose(extRef);}
    return theData;
}

-(void)dealloc {
    NSLog(@"Deallocating OpenAL (should only happen on quit)");
    context=alcGetCurrentContext();
    device=alcGetContextsDevice(context);
    alcMakeContextCurrent(NULL);
    alcDestroyContext(context);
    alcCloseDevice(device);
    [super dealloc];
}
@end

@implementation CocoALSourceFixed
-(id)initWithSource:(ALuint)s {
    source = s;
    return self;
}

-(BOOL)setMinDistance:(float)minDistance maxDistance:(float)maxDistance {
    ALCenum error;

    // TODO: I do not know what the OpenAL version of min distance is
//    ALfloat currentMinDistance;
//    alGetSourcef(source, AL_???MIN???_DISTANCE, &currentMinDistance);
//    if((error = alGetError()) != AL_NO_ERROR) {
//        NSLog(@"setMinDistance: Could not set min distance: %d", error);
//        return false;
//    }
//    NSLog(@"Setting min distance (%f => %f)", currentMinDistance, minDistance);

    alSourcef(source, AL_MAX_DISTANCE, maxDistance*DISTANCE_FACTOR);
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"setMinDistance: Could not set max distance: %d", error);
        return false;
    }
    return true;
}

-(BOOL)setLooping:(BOOL)to {
    ALCenum error;

    if (to) {
        alSourcei(source, AL_LOOPING, AL_TRUE);
    } else {
        alSourcei(source, AL_LOOPING, AL_FALSE);
    }
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"Could not set looping: %d", error);
        return false;
    }
    
    // Success
    return true;
}

-(BOOL) stopPlaying {
    ALCenum error;
    alSourceRewind(source);
    
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"Error in stopPlaying: %d", error);
        return false;
    }
    
    // Success
    return true;
}

-(BOOL) setVolume:(float)to {
    ALCenum error;
    // The game uses 255.0f for volume, probably because FMOD does this
    to = to / MAX_VOLUME;
    if (to < 0.0f) {
        to = 0.0f;
    }
    if (to > 1.0f) {
        to = 1.0f;
    }
    alSourcef(source, AL_GAIN, to);
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"setVolume: Error setting volume to %f: %d", to, error);
        return false;
    }
    return true;
}

-(BOOL) setFrequency:(float)to {
    ALCenum error;
    // The original frequency was set to 44100, so here, set the multiplier based on this frequency
    
    alSourcef(source, AL_PITCH, to/ORIG_FMOD_FREQUENCY);
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"setVolume: Error setting frequency to %f: %d", to, error);
        return false;
    }
    return true;
}

-(BOOL) isPlaying {
    ALCenum error;

    ALint value;
    alGetSourcei(source,AL_SOURCE_STATE, &value);
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"isPlaying: Error getting state: %d", error);
        return false;
    }
    
    return value == AL_PLAYING;
}

-(BOOL) play {
    ALCenum error;
    if(![self setVolume:MAX_VOLUME]) {
        NSLog(@"play: Error setting volume");
        return false;
    }
    alSourceStop(source);
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"play: Error stopping: %d", error);
        return false;
    }
    alSourcePlay(source);
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"play: Error playing: %d", error);
        return false;
    }
        
    // Success
    return true;
}

//-(BOOL)queueBuffers:(ALuint *) buffers num:(uint)num {
//    ALCenum error;
//    alSourceQueueBuffers(source, num, buffers);
//    
//    if((error = alGetError()) != AL_NO_ERROR) {
//        NSLog(@"Error in queueBuffers: %d", error);
//        return false;
//    }
//    
//    // Success
//    return true;
//}

-(ALuint)get {
    return source;
}

-(BOOL)loadBuffer:(CocoALBuffer *)buffer {
    ALCenum error;
    alSourcei(source, AL_BUFFER, [buffer get]);
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"loadBuffer: Could not load buffer %d into source %d: %i", [buffer get], source, error);
        return false;
    }
    return true;
}

// Play this sound on top of the listener, similar to FMOD's FSOUND_2D flag
-(BOOL)set2d {
    // Any possible error
    ALCenum error;

    // TODO: For some reason, crystals can have different frequencies in the main game timetimes, but I don't know where to find that in the original source code
    alSourcei(source, AL_SOURCE_RELATIVE, AL_TRUE);
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"set2d: relative true: %d", error);
        return false;
    }
    alSource3f(source, AL_POSITION, 0.0f, 0.0f, 0.0f);
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"set2d: position: %d", error);
        return false;
    }
    alSource3f(source, AL_VELOCITY, 0.0f, 0.0f, 0.0f);
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"set2d: velocity: %d", error);
        return false;
    }

    // Success
    return true;
}

-(BOOL)playBuffer:(ALuint)buffer {
    // Any possible error
    ALCenum error;
    
    [self stopPlaying];
    [self setVolume:MAX_VOLUME];
    
    alSourcei(source, AL_BUFFER, buffer);
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"playBuffer: Could not load buffer %d into source %d: %i", buffer, source, error);
        return false;
    }
    
    alSourcePlay(source);
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"playBuffer: Could not play buffer: %i", error);
        return false;
    }
    
    NSLog(@"Playing buffer %d", buffer);

    // Success
    return true;
}
-(void)dealloc {
    ALCenum error;
    alDeleteSources(1, &source);
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"dealloc: Could not delete source %d: %d", source, error);
    }
    [super dealloc];
}
@end

@implementation CocoALBuffer
-(ALuint)get {
    return buffer;
}

-(id)initWithBuffer:(ALuint)b {
    buffer = b;
    minDistance = -1.0f;
    maxDistance = -1.0f;
    set2d = false;
    volume = MAX_VOLUME;
    return self;
}
        
        -(void)setMinDistance:(float)min maxDistance:(float)max {
            minDistance = min;
            maxDistance = max;
        }

        -(ALfloat)getMinDistance {
            return minDistance;
        }
-(ALfloat)getMaxDistance {
    return maxDistance;
}
-(ALfloat)getVolume {
    return volume;
}
-(BOOL)get2d {
    return set2d;
}
-(void)set2d {
    set2d = true;
}

-(void)setVolume:(float)to {
    volume = to;
}

-(ALuint)loadAudioFile:(NSString *)inputFilename {
    // Any possible error
    ALCenum error;
    
    // Convert the data
    ALsizei *dataSize =     (ALsizei *)malloc(sizeof(ALsizei));
    ALenum *dataFormat = (ALenum *)malloc(sizeof(ALenum));
    ALsizei *sampleRate = (ALsizei *)malloc(sizeof(ALsizei));
    ALuint *data = [CocoAL loadAudioDataAsPcm:inputFilename outDataSize:dataSize outDataFormat:dataFormat outSampleRate:sampleRate];
    
    if (data == NULL) {
        NSLog(@"loadAudioFileIntoNextFreeBuffer: Could not load audio data");
        free(dataSize);
        free(dataFormat);
        free(sampleRate);
        return -1;
    }
    
    // Clear the error buffer
    alGetError();
    
    // Load the data into the buffer
    alBufferData(buffer, *dataFormat, data, *dataSize, *sampleRate);
    
    free(dataSize);
    free(dataFormat);
    free(sampleRate);
    free(data);
    
    if((error = alGetError()) != AL_NO_ERROR) {
        NSLog(@"Could not load buffer data: %d", error);
        return -1;
    } else {
        // It was successful
        return buffer;
    }
}

-(void)dealloc {
    alDeleteBuffers(1, &buffer);
    ALCenum error = alGetError();
    if(error == AL_INVALID_OPERATION) {
        // TODO: Do we really care about leaking memory here?
        NSLog(@"dealloc: Could not deallocate buffer %d because it is in use. This is a memory leak!", buffer);
    } else if(error != AL_NO_ERROR) {
        NSLog(@"dealloc: Could not delete buffer %d: %d", buffer, error);
    }
    [super dealloc];
}

@end