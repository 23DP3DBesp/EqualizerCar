#import "ECProcessingAudioUnit.h"
#include "DSPKernel.hpp"
#include <memory>

namespace {
struct StereoABL { UInt32 count; AudioBuffer buffers[2]; };
struct RenderStorage {
    ec::Kernel kernel;
    std::array<std::vector<float>,2> input;
    StereoABL abl{};
    unsigned channels=2, maxFrames=4096;
    bool allocated=false;
    explicit RenderStorage(ec::Mode mode):kernel(mode) {}
};
}
@implementation ECProcessingAudioUnit {
    AUAudioUnitBusArray *_inputs;
    AUAudioUnitBusArray *_outputs;
    std::shared_ptr<RenderStorage> _storage;
}
+ (void)registerComponents {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        for (unsigned mode=0;mode<ec::ModeCount;mode++) {
            AudioComponentDescription d={kAudioUnitType_Effect, 0x45630000u+mode, 'EqCr',0,0};
            [AUAudioUnit registerSubclass:self asComponentDescription:d name:@"EqualizerCar: DSP" version:1];
        }
    });
}
- (instancetype)initWithComponentDescription:(AudioComponentDescription)d options:(AudioComponentInstantiationOptions)options error:(NSError **)error {
    self=[super initWithComponentDescription:d options:options error:error];
    if(self) {
        _storage=std::make_shared<RenderStorage>(ec::Mode(d.componentSubType-0x45630000u));
        AVAudioFormat *format=[[AVAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
        AUAudioUnitBus *input=[[AUAudioUnitBus alloc] initWithFormat:format error:error];
        AUAudioUnitBus *output=[[AUAudioUnitBus alloc] initWithFormat:format error:error];
        if(!input || !output) return nil;
        input.maximumChannelCount=2; output.maximumChannelCount=2;
        _inputs=[[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput busses:@[input]];
        _outputs=[[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses:@[output]];
        self.maximumFramesToRender=4096;
    }
    return self;
}
- (AUAudioUnitBusArray *)inputBusses { return _inputs; }
- (AUAudioUnitBusArray *)outputBusses { return _outputs; }
- (BOOL)canProcessInPlace { return YES; }
- (NSTimeInterval)latency { return _storage->kernel.latency(); }
- (BOOL)shouldChangeToFormat:(AVAudioFormat *)format forBus:(AUAudioUnitBus *)bus {
    return format.commonFormat==AVAudioPCMFormatFloat32 && !format.isInterleaved && format.channelCount>=1 && format.channelCount<=2 && format.sampleRate>=8000 && format.sampleRate<=192000;
}
- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)error {
    AVAudioFormat *input=_inputs[0].format,*output=_outputs[0].format;
    if(![input isEqual:output] || ![self shouldChangeToFormat:input forBus:_inputs[0]]) {
        if(error) *error=[NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FormatNotSupported userInfo:nil];
        return NO;
    }
    if(![super allocateRenderResourcesAndReturnError:error]) return NO;
    _storage->channels=input.channelCount;
    _storage->maxFrames=self.maximumFramesToRender;
    for(auto &channel:_storage->input) channel.assign(self.maximumFramesToRender,0);
    _storage->kernel.prepare(input.sampleRate);
    _storage->allocated=true;
    return YES;
}
- (void)deallocateRenderResources { _storage->allocated=false; [super deallocateRenderResources]; }
- (void)reset { _storage->kernel.reset(); }
- (void)setDSPParameter:(NSUInteger)index value:(float)value { _storage->kernel.set(unsigned(index),value); }
- (AUInternalRenderBlock)internalRenderBlock {
    auto storage=_storage;
    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags *flags,const AudioTimeStamp *time,AUAudioFrameCount frames,NSInteger bus,AudioBufferList *output,const AURenderEvent *events,AURenderPullInputBlock pull) {
        if(!pull || !storage->allocated) return kAudioUnitErr_NoConnection;
        if(frames>storage->maxFrames) return kAudioUnitErr_TooManyFramesToProcess;
        storage->abl.count=storage->channels;
        for(unsigned c=0;c<storage->channels;c++) storage->abl.buffers[c]={1,UInt32(frames*sizeof(float)),storage->input[c].data()};
        auto *input=reinterpret_cast<AudioBufferList *>(&storage->abl);
        auto result=pull(flags,time,frames,0,input);
        if(result!=noErr) return result;
        if(output->mNumberBuffers!=storage->channels) return kAudioUnitErr_FormatNotSupported;
        for(unsigned c=0;c<storage->channels;c++) {
            if(!input->mBuffers[c].mData) return kAudioUnitErr_NoConnection;
            if(!output->mBuffers[c].mData) output->mBuffers[c].mData=input->mBuffers[c].mData;
            output->mBuffers[c].mDataByteSize=frames*sizeof(float);
        }
        storage->kernel.process(static_cast<float *>(input->mBuffers[0].mData),storage->channels>1?static_cast<float *>(input->mBuffers[1].mData):nullptr,
            static_cast<float *>(output->mBuffers[0].mData),storage->channels>1?static_cast<float *>(output->mBuffers[1].mData):nullptr,frames,storage->channels);
        // Nonlinear processors may have a tail even when the input was marked silent.
        *flags &= ~kAudioUnitRenderAction_OutputIsSilence;
        return noErr;
    };
}
@end
