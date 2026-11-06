#import "../../EqualizerCar/DSP/Realtime/ECProcessingAudioUnit.h"
#include "../../EqualizerCar/DSP/Realtime/DSPKernel.hpp"
#include <cassert>
#include <iostream>

int main() { @autoreleasepool {
    [ECProcessingAudioUnit registerComponents];
    for(double rate:{44100.,48000.}) for(unsigned channels:{1u,2u}) for(unsigned mode=0;mode<ec::ModeCount;mode++) {
        NSError *error=nil;
        AudioComponentDescription d={kAudioUnitType_Effect,0x45630000u+mode,'EqCr',0,0};
        AVAudioUnitEffect *node=[[AVAudioUnitEffect alloc] initWithAudioComponentDescription:d];
        assert([node.AUAudioUnit isKindOfClass:ECProcessingAudioUnit.class]);
        ECProcessingAudioUnit *unit=(ECProcessingAudioUnit *)node.AUAudioUnit;
        AVAudioFormat *format=[[AVAudioFormat alloc] initStandardFormatWithSampleRate:rate channels:channels];
        assert([unit.inputBusses[0] setFormat:format error:&error]);
        assert([unit.outputBusses[0] setFormat:format error:&error]);
        [unit setDSPParameter:0 value:0];
        // Hosts are allowed to cache the block before allocating resources.
        AUInternalRenderBlock render=unit.internalRenderBlock;
        assert([unit allocateRenderResourcesAndReturnError:&error]);
        AVAudioPCMBuffer *output=[[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:512];
        output.frameLength=512;
        AudioTimeStamp time={};time.mFlags=kAudioTimeStampSampleTimeValid;
        AudioUnitRenderActionFlags flags=0;
        AURenderPullInputBlock pull=^AUAudioUnitStatus(AudioUnitRenderActionFlags *f,const AudioTimeStamp *t,AUAudioFrameCount frames,NSInteger bus,AudioBufferList *audio) {
            for(unsigned ch=0;ch<audio->mNumberBuffers;ch++) {
                float *samples=(float *)audio->mBuffers[ch].mData;
                for(unsigned n=0;n<frames;n++)samples[n]=.1f*(ch+1);
            }
            return noErr;
        };
        assert(render(&flags,&time,512,0,output.mutableAudioBufferList,nullptr,pull)==noErr);
        int latency=mode==ec::Limiter?int(rate*.003):0;
        for(unsigned ch=0;ch<channels;ch++) for(int n=latency;n<512;n++)assert(std::abs(output.floatChannelData[ch][n]-.1f*(ch+1))<1e-5);
        [unit deallocateRenderResources];
        // Route format changes must not invalidate the cached render block.
        assert([unit allocateRenderResourcesAndReturnError:&error]);
        assert(render(&flags,&time,512,0,output.mutableAudioBufferList,nullptr,pull)==noErr);
        [unit deallocateRenderResources];
    }
    // The full render chain must stay connected, produce audio, and respect the FINAL ceiling.
    for(double rate:{44100.,48000.}) {
        NSError *error=nil;
        AVAudioEngine *engine=[[AVAudioEngine alloc] init];
        AVAudioFormat *format=[[AVAudioFormat alloc] initStandardFormatWithSampleRate:rate channels:2];
        __block double phase=0;
        AVAudioSourceNode *source=[[AVAudioSourceNode alloc] initWithFormat:format renderBlock:^OSStatus(BOOL *silent,const AudioTimeStamp *time,AVAudioFrameCount frames,AudioBufferList *audio) {
            for(unsigned n=0;n<frames;n++) {
                float value=.25f*std::sin(phase)+.08f*std::sin(phase*7);
                for(unsigned c=0;c<audio->mNumberBuffers;c++)((float *)audio->mBuffers[c].mData)[n]=value;
                phase+=2*M_PI*110/rate;
            }
            *silent=NO;return noErr;
        }];
        [engine attachNode:source];AVAudioNode *previous=source;
        // Input gain, bass, dynamics, saturation, stereo, room, output gain, final limiter.
        for(auto mode:{ec::Gain,ec::Bass,ec::Compressor,ec::Multiband,ec::Saturation,ec::Spatial,ec::Reverb,ec::Gain,ec::Limiter}) {
            AudioComponentDescription d={kAudioUnitType_Effect,0x45630000u+mode,'EqCr',0,0};
            AVAudioUnitEffect *node=[[AVAudioUnitEffect alloc] initWithAudioComponentDescription:d];
            ECProcessingAudioUnit *unit=(ECProcessingAudioUnit *)node.AUAudioUnit;
            [unit setDSPParameter:0 value:1];
            if(mode==ec::Gain)[unit setDSPParameter:1 value:6];
            if(mode==ec::Bass){[unit setDSPParameter:1 value:8];[unit setDSPParameter:2 value:80];}
            if(mode==ec::Compressor){[unit setDSPParameter:1 value:-18];[unit setDSPParameter:2 value:3];[unit setDSPParameter:3 value:.012];[unit setDSPParameter:4 value:.18];}
            if(mode==ec::Saturation){[unit setDSPParameter:1 value:.35];[unit setDSPParameter:2 value:.65];}
            if(mode==ec::Spatial)[unit setDSPParameter:1 value:.7];
            if(mode==ec::Reverb){[unit setDSPParameter:1 value:20];[unit setDSPParameter:2 value:.5];[unit setDSPParameter:3 value:.5];}
            if(mode==ec::Limiter){[unit setDSPParameter:1 value:-3];[unit setDSPParameter:2 value:.08];}
            [engine attachNode:node];[engine connect:previous to:node format:format];previous=node;
        }
        [engine connect:previous to:engine.mainMixerNode format:format];
        assert([engine enableManualRenderingMode:AVAudioEngineManualRenderingModeOffline format:format maximumFrameCount:512 error:&error]);
        assert([engine startAndReturnError:&error]);
        AVAudioPCMBuffer *buffer=[[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:512];
        double energy=0;
        for(int block=0;block<100;block++) {
            AVAudioEngineManualRenderingStatus status=[engine renderOffline:512 toBuffer:buffer error:&error];
            assert(status==AVAudioEngineManualRenderingStatusSuccess);
            for(unsigned c=0;c<2;c++)for(unsigned n=0;n<buffer.frameLength;n++) {
                float x=buffer.floatChannelData[c][n];assert(std::isfinite(x));assert(std::abs(x)<=ec::db(-3)+.0001);energy+=x*x;
            }
        }
        assert(energy>1);[engine stop];
    }
    // File-format conversion and resume after a stopped engine use the same mixer boundary as the app.
    for(double rate:{44100.,48000.}) for(unsigned channels:{1u,2u}) {
        NSError *error=nil;
        AVAudioEngine *engine=[AVAudioEngine new];
        AVAudioPlayerNode *player=[AVAudioPlayerNode new];
        AVAudioMixerNode *input=[AVAudioMixerNode new];
        AVAudioFormat *fileFormat=[[AVAudioFormat alloc] initStandardFormatWithSampleRate:rate channels:channels];
        AVAudioFormat *dspFormat=[[AVAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
        AudioComponentDescription d={kAudioUnitType_Effect,0x45630000u+ec::Saturation,'EqCr',0,0};
        AVAudioUnitEffect *effect=[[AVAudioUnitEffect alloc] initWithAudioComponentDescription:d];
        [engine attachNode:player]; [engine attachNode:input]; [engine attachNode:effect];
        [engine connect:player to:input format:fileFormat];
        [engine connect:input to:effect format:dspFormat];
        [engine connect:effect to:engine.mainMixerNode format:dspFormat];
        assert([engine enableManualRenderingMode:AVAudioEngineManualRenderingModeOffline format:dspFormat maximumFrameCount:512 error:&error]);
        AVAudioPCMBuffer *source=[[AVAudioPCMBuffer alloc] initWithPCMFormat:fileFormat frameCapacity:8192];
        source.frameLength=8192;
        for(unsigned c=0;c<channels;c++)for(unsigned n=0;n<8192;n++)source.floatChannelData[c][n]=.2f*std::sin(2*M_PI*440*n/rate);
        AVAudioPCMBuffer *output=[[AVAudioPCMBuffer alloc] initWithPCMFormat:dspFormat frameCapacity:512];
        for(int restart=0;restart<3;restart++) {
            [player scheduleBuffer:source completionHandler:nil];
            assert([engine startAndReturnError:&error]);
            assert(engine.running);
            [player play];
            double energy=0;
            for(int block=0;block<8;block++) {
                assert([engine renderOffline:512 toBuffer:output error:&error]==AVAudioEngineManualRenderingStatusSuccess);
                for(unsigned n=0;n<output.frameLength;n++)energy+=output.floatChannelData[0][n]*output.floatChannelData[0][n];
            }
            assert(energy>1);
            [player stop]; [engine stop];
        }
    }
    std::cout<<"PASS: real registered AU instances, 26 modes, mono/stereo, 44.1/48 kHz, bypass render, resource reallocation, full AVAudioEngine offline chain and output protection\n";
} }
