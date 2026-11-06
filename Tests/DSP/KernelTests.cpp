#include "../../EqualizerCar/DSP/Realtime/DSPKernel.hpp"
#include <cassert>
#include <chrono>
#include <iostream>
using namespace ec;
void defaults(Kernel &k) {
    k.set(0,1);
    switch(k.mode) {
    case Bass:k.set(1,8);k.set(2,80);break;
    case Gain:k.set(1,6);break;
    case Compressor:k.set(1,-24);k.set(2,6);k.set(3,.005);k.set(4,.15);break;
    case Limiter:k.set(1,-6);k.set(2,.08);break;
    case SoftClip:k.set(1,.6);break;
    case Saturation:k.set(1,.6);k.set(2,.8);break;
    case Width:k.set(1,.8);break;
    case Collapse:k.set(1,.2);break;
    case Spatial:case Surround:k.set(1,.8);break;
    case Reverb:k.set(1,45);k.set(2,.6);k.set(3,.4);break;
    case VirtualSub:k.set(1,.8);k.set(2,55);break;
    case Exciter:k.set(1,.8);break;
    case Notch:k.set(1,1000);k.set(2,4);k.set(3,-18);break;
    case Hum:k.set(1,50);k.set(2,120);k.set(3,1);break;
    case Crossover:k.set(1,100);break;
    case Stereo3D:k.set(1,.7);k.set(2,.7);break;
    case Transient:k.set(1,8);k.set(2,-6);break;
    case Subsonic:k.set(1,40);break;
    case VocalClarity:case NightMode:k.set(1,.7);break;
    default:break;
    }
}
float rms(const std::vector<float>&x,unsigned start=0) {double sum=0;for(unsigned n=start;n<x.size();n++)sum+=x[n]*x[n];return std::sqrt(sum/(x.size()-start));}
int main() {
 for(double sr:{44100.,48000.,96000.}) {
    int count=int(sr/2);std::vector<float> l(count),r(count),a(count),b(count);
    for(int i=0;i<count;i++) {
        float t=i/sr;
        l[i]=.2f*std::sin(2*M_PI*50*t)+.2f*std::sin(2*M_PI*1000*t)+.1f*std::sin(2*M_PI*6000*t);
        r[i]=.17f*std::sin(2*M_PI*70*t)+.16f*std::sin(2*M_PI*1000*t)+.08f*std::sin(2*M_PI*7000*t);
    }
    for(int mode=0;mode<ModeCount;mode++) {
        Kernel k{Mode(mode)};defaults(k);k.prepare(sr);
        k.process(l.data(),r.data(),a.data(),b.data(),count,2);
        double difference=0;
        for(int i=0;i<count;i++) {assert(std::isfinite(a[i])&&std::isfinite(b[i]));assert(std::abs(a[i])<10);difference+=std::abs(a[i]-l[i]);}
        if(difference/count<.001) {std::cerr<<"No measurable effect: "<<mode<<"\n";return 1;}
        k.set(0,0);k.reset();k.process(l.data(),r.data(),a.data(),b.data(),count,2);
        int offset=mode==Limiter?int(sr*.003):0;
        for(int i=offset;i<count;i++)assert(std::abs(a[i]-l[i-offset])<.00001f);
        k.set(0,1);k.prepare(sr);
        k.process(l.data(),nullptr,a.data(),nullptr,count,1);
        for(float x:a)assert(std::isfinite(x));
    }
    // Car effects: rumble attenuation, presence boost, and reduced loud/quiet contrast.
    auto toneRMS = [&](Mode mode, float parameter, float hz, float amplitude) {
        Kernel effect(mode);effect.set(0,1);effect.set(1,parameter);effect.prepare(sr);
        for(int i=0;i<count;i++)l[i]=r[i]=amplitude*std::sin(2*M_PI*hz*i/sr);
        effect.process(l.data(),r.data(),a.data(),b.data(),count,2);
        return rms(a,count/2);
    };
    float subLow=toneRMS(Subsonic,40,10,.2),subHigh=toneRMS(Subsonic,40,200,.2);
    assert(subLow<subHigh*.01);
    float clarity=toneRMS(VocalClarity,1,2500,.1);
    assert(clarity>toneRMS(VocalClarity,0,2500,.1)*1.8);
    float loud=toneRMS(NightMode,1,1000,.8),quiet=toneRMS(NightMode,1,1000,.04);
    assert(loud/quiet<4); // Input contrast is 20:1.
    // Notch attenuates the selected frequency; compressor ratio is functional.
    for(int i=0;i<count;i++)l[i]=r[i]=.8f*std::sin(2*M_PI*1000*i/sr);
    Kernel notch(Notch);defaults(notch);notch.prepare(sr);notch.process(l.data(),r.data(),a.data(),b.data(),count,2);
    assert(rms(a,count/2)<rms(l,count/2)*.15);
    Kernel compressor(Compressor);defaults(compressor);compressor.prepare(sr);compressor.process(l.data(),r.data(),a.data(),b.data(),count,2);
    assert(rms(a,count/2)<rms(l,count/2)*.4);
    // Limiter respects the ceiling, including a full-scale step and stereo linking.
    std::fill(l.begin(),l.end(),2);std::fill(r.begin(),r.end(),1);
    Kernel limiter(Limiter);defaults(limiter);limiter.prepare(sr);limiter.process(l.data(),r.data(),a.data(),b.data(),count,2);
    for(int i=0;i<count;i++){assert(std::abs(a[i])<=db(-6)+.00001);assert(std::abs(a[i]-2*b[i])<.00001);}
    // Width leaves the mono center unchanged, collapse at zero really produces mono.
    Kernel collapse(Collapse);defaults(collapse);collapse.set(1,0);collapse.prepare(sr);collapse.process(l.data(),r.data(),a.data(),b.data(),count,2);
    for(int i=0;i<count;i++)assert(a[i]==b[i]);
    Kernel width(Width);defaults(width);width.prepare(sr);width.process(l.data(),l.data(),a.data(),b.data(),count,2);
    for(int i=0;i<count;i++)assert(a[i]==l[i]&&b[i]==l[i]);
    // Gain automation is a ramp, not a one-sample jump. Disabled processors return dry audio.
    Kernel gain(Gain);gain.set(0,1);gain.prepare(sr);std::fill(l.begin(),l.end(),.2);gain.set(1,12);
    gain.process(l.data(),l.data(),a.data(),b.data(),count,2);
    float jump=0;for(int i=1;i<count;i++)jump=std::max(jump,std::abs(a[i]-a[i-1]));assert(jump<.003);
    // Bass mono removes low-frequency side content, retaining high-frequency stereo.
    Kernel mono(BassMono);defaults(mono);mono.prepare(sr);
    for(int i=0;i<count;i++){l[i]=.4*std::sin(2*M_PI*20*i/sr);r[i]=-l[i];}
    mono.process(l.data(),r.data(),a.data(),b.data(),count,2);assert(rms(a,count/2)<rms(l,count/2)*.35);
 }
 // Block-size invariance: no resets or per-buffer approximation of the algorithms.
 for(int mode=0;mode<ModeCount;mode++) {
    Kernel one{Mode(mode)},blocks{Mode(mode)};defaults(one);defaults(blocks);one.prepare(48000);blocks.prepare(48000);
    std::vector<float> in(8192),a(8192),b(8192),c(8192),d(8192);
    for(int i=0;i<8192;i++)in[i]=.3*std::sin(i*.027)+.2*std::sin(i*.17);
    one.process(in.data(),in.data(),a.data(),b.data(),8192,2);
    for(int i=0;i<8192;i+=128)blocks.process(in.data()+i,in.data()+i,c.data()+i,d.data()+i,128,2);
    for(int i=0;i<8192;i++)assert(std::abs(a[i]-c[i])<.000001);
 }
 // Live enable/disable must change the running signal without resetting the unit.
 for(int mode=0;mode<ModeCount;mode++) {
    Kernel k{Mode(mode)};defaults(k);k.set(0,0);k.prepare(48000);
    const int n=48000;std::vector<float> l(n),r(n),a(n),b(n),dry(n),dryR(n);
    for(int i=0;i<n;i++) {
        float t=i/48000.f;
        l[i]=.2f*(std::sin(2*M_PI*50*t)+std::sin(2*M_PI*1000*t)+std::sin(2*M_PI*6000*t));
        r[i]=.15f*std::sin(2*M_PI*80*t)+.1f*std::sin(2*M_PI*2300*t);
    }
    k.process(l.data(),r.data(),dry.data(),dryR.data(),n,2);
    k.set(0,1);k.process(l.data(),r.data(),a.data(),b.data(),n,2);
    double difference=0;
    for(int i=n/2;i<n;i++)difference+=std::abs(a[i]-dry[i])+std::abs(b[i]-dryR[i]);
    assert(difference/n>.001);
    k.set(0,0);k.process(l.data(),r.data(),a.data(),b.data(),n,2);
    for(int i=n/2;i<n;i++)assert(std::abs(a[i]-dry[i])<.0001);
 }
 // Spatial processors create side energy from mono while keeping a stable center.
 for(auto mode:{Spatial,Stereo3D}) {
    Kernel k(mode);k.set(0,1);k.set(1,.65);k.set(2,.5);k.prepare(48000);
    std::vector<float> in(48000),a(48000),b(48000);
    for(int i=0;i<48000;i++)in[i]=.1f*std::sin(i*.057)+.1f*std::sin(i*.013);
    k.process(in.data(),in.data(),a.data(),b.data(),48000,2);
    double side=0,dry=0;
    for(int i=24000;i<48000;i++) {
        assert(std::abs((a[i]+b[i])*.5-in[i])<.00001);
        side+=std::pow((a[i]-b[i])*.5,2);dry+=in[i]*in[i];
    }
    assert(std::sqrt(side/dry)>.1);
 }
 // Rapid automation, extreme legal values, and invalid targets must remain finite.
 for(int mode=0;mode<ModeCount;mode++) {
    Kernel k{Mode(mode)};defaults(k);k.prepare(48000);
    std::vector<float> in(128),a(128),b(128);
    for(int block=0;block<200;block++) {
        k.set(0,(block/8)%2);
        if(mode==Notch){k.set(1,block%2?20:20000);k.set(2,block%2?.3:20);}
        if(mode==Crossover)k.set(2,block%2);
        if(mode==Reverb){k.set(2,(block%10)*.1);k.set(3,block%2);}
        for(int i=0;i<128;i++)in[i]=.2*std::sin((i+block*128)*.12);
        k.set(7,NAN);k.process(in.data(),in.data(),a.data(),b.data(),128,2);
        for(float x:a)assert(std::isfinite(x)&&std::abs(x)<10);
    }
 }
 // Nonlinear modes really generate harmonics, not just gain/EQ.
 for(auto mode:{VirtualSub,Saturation,Exciter}) {
    Kernel k(mode);defaults(k);k.prepare(48000);
    std::vector<float> in(48000),a(48000),b(48000);
    double frequency=mode==VirtualSub?50:mode==Exciter?3000:1000;
    for(int i=0;i<48000;i++)in[i]=.4*std::sin(2*M_PI*frequency*i/48000);
    k.process(in.data(),in.data(),a.data(),b.data(),48000,2);
    double re=0,im=0;int harmonic=mode==VirtualSub?2:3;
    for(int i=24000;i<48000;i++){re+=a[i]*std::cos(2*M_PI*frequency*harmonic*i/48000);im+=a[i]*std::sin(2*M_PI*frequency*harmonic*i/48000);}
    assert(std::hypot(re,im)/24000>.001);
 }
 std::cout<<"PASS: "<<ModeCount<<" modes, 44.1/48/96 kHz, mono/stereo, measurable signal difference, bypass, notch, dynamics, peak ceiling, width, bass mono, ramps, block invariance\n";
}
