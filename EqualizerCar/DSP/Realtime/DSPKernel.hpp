#pragma once
#include <array>
#include <atomic>
#include <algorithm>
#include <cmath>
#include <vector>

namespace ec {
enum Mode { Bass, Treble, Loudness, Gain, Compressor, Limiter, Multiband,
    SoftClip, Width, Spatial, Surround, Reverb, VirtualSub, Exciter, Phase,
    Notch, Hum, Crossover, Stereo3D, Saturation, Transient, Collapse, BassMono,
    Subsonic, VocalClarity, NightMode, ModeCount };
inline float clamp(float x,float a,float b) { return std::isfinite(x) ? std::max(a,std::min(b,x)) : a; }
inline float db(float x) { return std::pow(10.f,x/20.f); }
struct Biquad {
    double b0=1,b1=0,b2=0,a1=0,a2=0,z1=0,z2=0;
    float tick(float x) { double y=b0*x+z1; z1=b1*x-a1*y+z2; z2=b2*x-a2*y; return float(y); }
    void clear() { z1=z2=0; }
    void configure(int kind, double hz, double q, double gain, double sr) {
        const double w=2*3.141592653589793*std::clamp(hz,10.,sr*.45)/sr;
        const double c=std::cos(w), sn=std::sin(w), A=std::pow(10.,gain/40.);
        const double alpha=sn/(2*std::max(q,.1)), root=2*std::sqrt(A)*alpha;
        double n0=1,n1=0,n2=0,d0=1,d1=0,d2=0;
        switch(kind) {
        case 0: n0=(1-c)/2;n1=1-c;n2=n0;d0=1+alpha;d1=-2*c;d2=1-alpha;break;
        case 1: n0=(1+c)/2;n1=-(1+c);n2=n0;d0=1+alpha;d1=-2*c;d2=1-alpha;break;
        case 2: n0=1+alpha*A;n1=-2*c;n2=1-alpha*A;d0=1+alpha/A;d1=-2*c;d2=1-alpha/A;break;
        case 3: n0=A*((A+1)-(A-1)*c+root);n1=2*A*((A-1)-(A+1)*c);n2=A*((A+1)-(A-1)*c-root);
            d0=(A+1)+(A-1)*c+root;d1=-2*((A-1)+(A+1)*c);d2=(A+1)+(A-1)*c-root;break;
        case 4: n0=A*((A+1)+(A-1)*c+root);n1=-2*A*((A-1)+(A+1)*c);n2=A*((A+1)+(A-1)*c-root);
            d0=(A+1)-(A-1)*c+root;d1=2*((A-1)-(A+1)*c);d2=(A+1)-(A-1)*c-root;break;
        }
        b0=n0/d0;b1=n1/d0;b2=n2/d0;a1=d1/d0;a2=d2/d0;
    }
};

// UI writes lock-free targets. Render owns all histories and performs no allocations or locks.
class Kernel {
public:
    const Mode mode;
    std::array<std::atomic<float>,8> targets{};
    explicit Kernel(Mode m): mode(m) {
        static_assert(std::atomic<float>::is_always_lock_free);
        for(auto &v:targets) v.store(0);
    }
    void set(unsigned i,float v) { if(i<8 && std::isfinite(v)) targets[i].store(v,std::memory_order_relaxed); }
    float get(unsigned i) const { return i<8 ? targets[i].load(std::memory_order_relaxed) : 0; }
    double latency() const { return mode==Limiter ? double(lookahead)/sr : 0; }
    void prepare(double sampleRate) {
        sr=sampleRate; smooth=1-std::exp(-1.f/float(.020*sr)); lookahead=std::max(1,int(sr*.003));
        bool needsDelay=mode==Limiter||mode==Spatial||mode==Surround||mode==Reverb||mode==Stereo3D;
        capacity=needsDelay ? int(sr*.2)+4 : 1;
        for(auto &ch:delay) for(auto &line:ch) line.assign(capacity,0);
        reset();
    }
    void reset() {
        for(unsigned i=0;i<8;i++) p[i]=get(i);
        for(auto &ch:filter) for(auto &f:ch) f.clear();
        for(auto &ch:delay) for(auto &line:ch) std::fill(line.begin(),line.end(),0);
        low={}; upper={}; env={}; gain={1,1,1}; damping={}; previous={}; aa={}; fast=slow=0; cursor=0; tickCounter=0;
        coefficients();
    }
    void process(const float *left,const float *right,float *outL,float *outR,unsigned frames,unsigned channels) {
        std::array<float,8> dest;
        for(unsigned i=0;i<8;i++) dest[i]=get(i);
        if(mode!=Limiter && p[0]<.000001f && dest[0]==0) {
            if(!dormant) { reset(); dormant=true; }
            p=dest;
            for(unsigned n=0;n<frames;n++) {
                outL[n]=std::isfinite(left[n])?left[n]:0;
                if(channels>1) outR[n]=std::isfinite(right[n])?right[n]:0;
            }
            return;
        }
        dormant=false;
        bool moving=false,changed=false;
        for(unsigned i=0;i<8;i++) {
            moving |= std::abs(dest[i]-p[i]) > .000001f*std::max(1.f,std::abs(dest[i]));
            changed |= dest[i]!=p[i];
        }
        if(!moving && changed) { p=dest; coefficients(); }
        for(unsigned n=0;n<frames;n++) {
            if(moving) {
                for(unsigned i=0;i<8;i++) p[i]+=(dest[i]-p[i])*smooth;
                if((tickCounter++ & 31)==0) coefficients();
            }
            float in[2]={std::isfinite(left[n])?left[n]:0,0};
            in[1]=channels>1 && right ? (std::isfinite(right[n])?right[n]:0) : in[0];
            float wet[2]={in[0],in[1]}, dry[2]={in[0],in[1]};
            float enabled=clamp(p[0],0,1);
            // Limiter retains its latency even when bypassed. Other disabled processors sleep.
            if(enabled<.000001f && dest[0]==0 && mode!=Limiter) { outL[n]=in[0]; if(channels>1) outR[n]=in[1]; continue; }
            switch(mode) {
            case Bass: case Treble: case Notch:
                for(int c=0;c<2;c++) wet[c]=filter[c][0].tick(in[c]); break;
            case Crossover:
                for(int c=0;c<2;c++) {
                    float lo=filter[c][0].tick(in[c]),hi=filter[c][1].tick(in[c]);
                    wet[c]=lo+(hi-lo)*clamp(p[2],0,1);
                } break;
            case Loudness: case Hum: case Subsonic: case VocalClarity:
                for(int c=0;c<2;c++) wet[c]=filter[c][1].tick(filter[c][0].tick(in[c])); break;
            case Gain:
                for(int c=0;c<2;c++) {
                    float amplitude=p[1]<=-100?0:db(clamp(p[1],-100,18));
                    float pan=clamp(p[2],-1,1);
                    wet[c]=in[c]*amplitude*(c==0 ? 1-std::max(pan,0.f) : 1+std::min(pan,0.f));
                } break;
            case BassMono: {
                float loL=filter[0][0].tick(in[0]),loR=filter[1][0].tick(in[1]);
                float mid=(loL+loR)*.5f;
                wet[0]=in[0]-loL+mid;wet[1]=in[1]-loR+mid;break;
            }
            case Phase:
                for(int c=0;c<2;c++) wet[c]=-in[c]; break;
            case Width: case Collapse: {
                float mid=(in[0]+in[1])*.5f, side=(in[0]-in[1])*.5f;
                float w=mode==Collapse ? clamp(p[1],0,1) : 1+clamp(p[1],0,1)*1.5f;
                wet[0]=mid+side*w;wet[1]=mid-side*w;break;
            }
            case Compressor: {
                float level=std::max(std::abs(in[0]),std::abs(in[1]));
                float g=compress(level,0,clamp(p[1],-60,0),clamp(p[2],1,20),clamp(p[3],.001,.1),clamp(p[4],.02,1));
                wet[0]*=g;wet[1]*=g;break;
            }
            case NightMode: {
                float amount=clamp(p[1],0,1);
                float level=std::max(std::abs(in[0]),std::abs(in[1]));
                float g=compress(level,0,-12-18*amount,1+5*amount,.008,.25)*db(6*amount);
                wet[0]*=g;wet[1]*=g;break;
            }
            case Limiter: {
                float ceiling=db(clamp(p[1],-24,0));
                float peak=std::max(std::abs(in[0]),std::abs(in[1]));
                float target=std::min(1.f,ceiling/std::max(peak,.000001f));
                float coefficient=target<gain[0] ? attackLimiter : releaseLimiter;
                gain[0]=target+(gain[0]-target)*coefficient;
                for(int c=0;c<2;c++) { dry[c]=read(c,0,float(lookahead));delay[c][0][cursor]=in[c]; }
                float delayedPeak=std::max(std::abs(dry[0]),std::abs(dry[1]));
                gain[0]=std::min(gain[0],ceiling/std::max(delayedPeak,.000001f));
                for(int c=0;c<2;c++) wet[c]=dry[c]*gain[0];break;
            }
            case Multiband: {
                float band[2][3];
                for(int c=0;c<2;c++) {
                    low[c]+=splitLow*(in[c]-low[c]);upper[c]+=splitHigh*(in[c]-upper[c]);
                    band[c][0]=low[c];band[c][1]=upper[c]-low[c];band[c][2]=in[c]-upper[c];wet[c]=0;
                }
                for(int b=0;b<3;b++) {
                    float g=compress(std::max(std::abs(band[0][b]),std::abs(band[1][b])),b,-24.f+b*3,3.f-b*.4f,.012f-b*.004f,.18f-b*.04f);
                    for(int c=0;c<2;c++) wet[c]+=band[c][b]*g;
                }break;
            }
            case SoftClip: case Saturation: {
                float drive=1+clamp(p[1],0,1)*(mode==SoftClip?5:11);
                float mix=mode==SoftClip?1:clamp(p[2],0,1);
                for(int c=0;c<2;c++) { float shaped=oversampledShape(in[c],c,drive);wet[c]=in[c]+mix*(shaped-in[c]); }break;
            }
            case VirtualSub:
                for(int c=0;c<2;c++) {
                    float bass=filter[c][0].tick(in[c]);
                    float harmonic=std::abs(bass)*1.1f+bass*bass*bass*2;
                    harmonic=filter[c][2].tick(filter[c][1].tick(harmonic));
                    // Recover audible upper-bass harmonics on small speakers without
                    // adding more sub-bass that those speakers cannot reproduce.
                    wet[c]=in[c]+2.2f*clamp(p[1],0,1)*harmonic;
                }break;
            case Exciter:
                for(int c=0;c<2;c++) {
                    float high=filter[c][0].tick(in[c]);
                    float harmonics=oversampledShape(high,c,4)-high;
                    wet[c]=in[c]+clamp(p[1],0,1)*filter[c][1].tick(harmonics)*1.5f;
                }break;
            case Transient: {
                float peak=std::max(std::abs(in[0]),std::abs(in[1]));
                fast=follow(peak,fast,fastAttack,fastRelease);slow=follow(peak,slow,slowAttack,slowRelease);
                float transient=clamp((fast-slow)/std::max(slow,.015f),0,1);
                float active=clamp(slow/.015f,0,1);
                float g=db(active*(clamp(p[1],-12,12)*transient+clamp(p[2],-12,12)*(1-transient)));
                wet[0]*=g;wet[1]*=g;break;
            }
            case Spatial: case Stereo3D: {
                float amount=clamp(p[1],0,1), focus=clamp(p[2],0,1);
                float mid=(in[0]+in[1])*.5f,side=(in[0]-in[1])*.5f;
                float a=read(1,0,float(sr*(.009+.018*amount))), b=read(0,0,float(sr*(.017+.023*amount)));
                delay[0][0][cursor]=in[0];delay[1][0][cursor]=in[1];
                // Opposite-polarity early reflections create width even from mono.
                // Their sum cancels in mono; preserve the direct center instead of
                // making the apparent effect mostly a drop in level.
                float reflectedSide=(a-b)*.5f*amount;
                if(mode==Spatial) {
                    float wideSide=side*(1+.5f*amount)+reflectedSide*.8f;
                    wet[0]=mid+wideSide;wet[1]=mid-wideSide;
                } else {
                    float center=mid*(.85f+.3f*focus);
                    float wideSide=side*(1+amount)+reflectedSide*1.2f;
                    wet[0]=center+wideSide;wet[1]=center-wideSide;
                }
                break;
            }
            case Surround: case Reverb: {
                float size=mode==Surround?.7f:clamp(p[2],0,1), damp=mode==Surround?.45f:clamp(p[3],0,1);
                float mix=mode==Surround?clamp(p[1],0,1)*.55f:clamp(p[1]/100,0,1);
                const float times[4]={.0297f,.0371f,.0411f,.0437f};
                for(int c=0;c<2;c++) {
                    float sum=0;
                    for(int b=0;b<4;b++) {
                        float echo=read(c,b,float(sr*(times[b]+c*.0017f)*(.65f+size*1.8f)));
                        damping[c][b]+=(1-.92f*damp)*(echo-damping[c][b]);
                        delay[c][b][cursor]=(in[c]*.8f+in[1-c]*.2f)+damping[c][b]*(.35f+.52f*size);
                        sum+=echo*.25f;
                    }
                    // Early reflections give the room an audible onset; the
                    // decorrelated late tail alone was masked by the dry signal.
                    float early=read(c,0,float(sr*(c==0?.011:.019)));
                    if(mode==Surround) wet[c]=in[c]+mix*(sum*.8f+early*.5f);
                    else wet[c]=in[c]*(1-mix)+mix*(sum*1.3f+early*.6f);
                }break;
            }
            default: break;
            }
            outL[n]=dry[0]+enabled*(wet[0]-dry[0]);
            if(channels>1) outR[n]=dry[1]+enabled*(wet[1]-dry[1]);
            cursor=(cursor+1)%capacity;
        }
    }
private:
    bool dormant=true;
    double sr=48000; float smooth=.001f; int capacity=1,cursor=0,lookahead=144;unsigned tickCounter=0;
    std::array<float,8> p{};
    std::array<std::array<Biquad,3>,2> filter;
    std::array<std::array<std::vector<float>,4>,2> delay;
    std::array<std::array<float,4>,2> damping{};
    std::array<float,2> low{},upper{},previous{};
    std::array<std::array<float,2>,2> aa{};
    std::array<float,3> env{},gain{1,1,1};
    float fast=0,slow=0,splitLow=0,splitHigh=0,attackLimiter=0,releaseLimiter=0;
    float fastAttack=0,fastRelease=0,slowAttack=0,slowRelease=0,aaCoeff=0;
    std::array<float,3> attack{},release{};
    float read(int ch,int line,float distance) {
        float pos=cursor-std::clamp(distance,1.f,float(capacity-2));
        if(pos<0) pos+=capacity;
        int a=int(pos),b=(a+1)%capacity;float f=pos-a;
        return delay[ch][line][a]*(1-f)+delay[ch][line][b]*f;
    }
    static float follow(float x,float history,float a,float r) { float c=x>history?a:r;return x+(history-x)*c; }
    float compress(float x,int b,float threshold,float ratio,float at,float rel) {
        env[b]=follow(x,env[b],attack[b],release[b]);
        float over=20*std::log10(std::max(env[b],.000001f))-threshold;
        float reduction=over<=-3?0:over<3?(1-1/ratio)*(over+3)*(over+3)/12:(1-1/ratio)*over;
        return db(-reduction);
    }
    float oversampledShape(float x,int c,float drive) {
        float output=0;
        for(int i=1;i<=4;i++) {
            float input=previous[c]+(x-previous[c])*(i*.25f);
            float value=std::tanh(input*drive)/std::sqrt(drive);
            aa[c][0]+=aaCoeff*(value-aa[c][0]);aa[c][1]+=aaCoeff*(aa[c][0]-aa[c][1]);output=aa[c][1];
        }
        previous[c]=x;return output;
    }
    void coefficients() {
        auto coefficient=[this](float seconds){return std::exp(-1.f/float(std::max(seconds,.0001f)*sr));};
        splitLow=1-std::exp(float(-2*3.141592653589793*200/sr));splitHigh=1-std::exp(float(-2*3.141592653589793*2500/sr));
        attackLimiter=coefficient(.0003);releaseLimiter=coefficient(clamp(p[2],.005,1));
        fastAttack=coefficient(.001);fastRelease=coefficient(.06);slowAttack=coefficient(.02);slowRelease=coefficient(.18);
        aaCoeff=1-std::exp(float(-2*3.141592653589793*.42/4));
        for(int b=0;b<3;b++) {attack[b]=coefficient(mode==Multiband?.012f-b*.004f:clamp(p[3],.001,.1));release[b]=coefficient(mode==Multiband?.18f-b*.04f:clamp(p[4],.02,1));}
        if(mode==NightMode) { attack[0]=coefficient(.008);release[0]=coefficient(.25); }
        for(int c=0;c<2;c++) {
            auto &f=filter[c];
            switch(mode) {
            case Subsonic:
                f[0].configure(1,clamp(p[1],20,60),.541196,0,sr);
                f[1].configure(1,clamp(p[1],20,60),1.306563,0,sr);break;
            case VocalClarity:
                f[0].configure(2,300,.8,-4*clamp(p[1],0,1),sr);
                f[1].configure(2,2500,.7,6*clamp(p[1],0,1),sr);break;
            case BassMono:f[0].configure(0,100,.707,0,sr);break;
            case Bass:f[0].configure(3,clamp(p[2],40,150),.707,clamp(p[1],0,12),sr);break;
            case Treble:f[0].configure(4,6500,.707,6,sr);break;
            case Loudness:f[0].configure(3,90,.707,5,sr);f[1].configure(4,8000,.707,3,sr);break;
            case Notch:f[0].configure(2,clamp(p[1],20,20000),clamp(p[2],.3,20),clamp(p[3],-36,0),sr);break;
            case Hum:f[0].configure(2,clamp(p[1],45,65),25,-18,sr);f[1].configure(2,clamp(p[2],80,420),20,-18*clamp(p[3],0,1),sr);break;
            case Crossover:f[0].configure(0,clamp(p[1],30,400),.707,0,sr);f[1].configure(1,clamp(p[1],30,400),.707,0,sr);break;
            case VirtualSub:f[0].configure(0,clamp(p[2],30,70),.707,0,sr);f[1].configure(1,clamp(p[2],30,70)*1.5,.707,0,sr);f[2].configure(0,250,.707,0,sr);break;
            case Exciter:f[0].configure(1,2200,.707,0,sr);f[1].configure(1,2500,.707,0,sr);break;
            default:break;
            }
        }
    }
};
}
