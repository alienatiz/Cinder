#include "CinderDSP.h"
#include <stdlib.h>
#include <math.h>
#include <stdatomic.h>
#include <string.h>

struct CinderKernel {
    double rate, gain, smoothing;
    uint64_t frame, sound, total, lengths[6], cycle;
    size_t noise_count, sweep_count;
    float *pink, *band, *sweep;
    float *music_left, *music_right;
    uint32_t music_count;
    float *music_mono;
    uint32_t mono_count;
    int program;
    _Atomic float target, peak, rms;
    double window_energy;
    uint64_t window_samples, window_size;
    _Atomic uint64_t published_frames, published_sound;
    _Atomic int requested, paused, finished;
};
static const double pi = 3.14159265358979323846;
static double noise(uint32_t *seed) {
    *seed ^= *seed << 13; *seed ^= *seed >> 17; *seed ^= *seed << 5;
    return (double)(*seed) / 2147483648.0 - 1.0;
}
static void normalize(float *samples, size_t n) {
    float peak=0;
    for(size_t i=0;i<n;i++) peak=fmaxf(peak,fabsf(samples[i]));
    if(peak>0) for(size_t i=0;i<n;i++) samples[i]*=0.5f/peak;
}
static void make_noise(float *out,size_t n,double rate,int pink) {
    uint32_t seed=pink?3103:3104;
    double b0=0,b1=0,b2=0,low=0,dc=0;
    const double lp=1-exp(-2*pi*(pink?14000:12000)/rate);
    const double hp=1-exp(-2*pi*(pink?60:80)/rate);
    const size_t overlap=(size_t)(rate*.05);
    for(size_t i=0;i<n+overlap;i++) {
        double white=noise(&seed);
        b0=.997*b0+.03*white; b1=.985*b1+.08*white; b2=.9*b2+.2*white;
        double value=pink?(b0+b1+b2+.15*white):white;
        low+=lp*(value-low); dc+=hp*(low-dc);
        if(i<n) out[i]=(float)(low-dc);
        else {
            // Continue the filter beyond the loop, then blend that continuation
            // into its head. Equal-power weights avoid a periodic fade to silence.
            // Preparation only: no extra allocation or crossfade in the render callback.
            const size_t j=i-n;
            const double angle=(pi*.5)*(double)j/(double)(overlap-1);
            out[j]=(float)((low-dc)*cos(angle)+(double)out[j]*sin(angle));
        }
    }
    normalize(out,n);
}
CinderKernel *cinder_create(double rate,double hours,double db) {
    const double minutes=hours*60;
    if(!isfinite(rate)||rate<32000||rate>192000||!isfinite(minutes)||minutes<1-1e-7||minutes>60000+1e-7||
       fabs(minutes-round(minutes))>=1e-7||!isfinite(db)||db < -60||db>0) return NULL;
    CinderKernel *k=calloc(1,sizeof(*k)); if(!k) return NULL;
    k->program=-1;
    k->rate=rate;k->total=(uint64_t)llround(round(minutes)*60*rate);k->cycle=(uint64_t)(3600*rate);
    int seconds[]={900,300,900,900,300,300};
    for(int i=0;i<6;i++) k->lengths[i]=(uint64_t)(seconds[i]*rate);
    k->noise_count=(size_t)(12*rate);k->sweep_count=(size_t)(30*rate);
    k->pink=calloc(k->noise_count,sizeof(float));k->band=calloc(k->noise_count,sizeof(float));
    k->sweep=calloc(k->sweep_count,sizeof(float));
    if(!k->pink||!k->band||!k->sweep){cinder_destroy(k);return NULL;}
    make_noise(k->pink,k->noise_count,rate,1);make_noise(k->band,k->noise_count,rate,0);
    double phase=0;
    for(size_t i=0;i<k->sweep_count;i++) {
        double t=(double)i/rate, f=100*exp(log(100)*fmin(t,30-t)/15);
        phase+=2*pi*f/rate;
        double fade=fmin(1.,fmin(t,30-t)/.75);
        k->sweep[i]=(float)(.5*sin(phase)*fade);
    }
    k->window_size=(uint64_t)(rate*.1);
    k->smoothing=1-exp(-1/(rate*.02));
    atomic_init(&k->target,(float)pow(10,db/20));atomic_init(&k->peak,0);atomic_init(&k->rms,0);
    atomic_init(&k->published_frames,0);atomic_init(&k->published_sound,0);
    atomic_init(&k->requested,0);atomic_init(&k->paused,0);atomic_init(&k->finished,0);
    if(!atomic_is_lock_free(&k->target)||!atomic_is_lock_free(&k->published_frames)||!atomic_is_lock_free(&k->rms)) {
        cinder_destroy(k); return NULL;
    }
    return k;
}
void cinder_destroy(CinderKernel *k){if(k){free(k->pink);free(k->band);free(k->sweep);free(k->music_left);free(k->music_right);free(k->music_mono);free(k);}}
int cinder_music(CinderKernel *k,const float *left,const float *right,uint32_t n) {
    if(!k||k->frame||!left||!right||!n||(uint64_t)n*8>256000000) return 0;
    for(uint32_t i=0;i<n;i++) if(!isfinite(left[i])||!isfinite(right[i])||fabsf(left[i])>.50001f||fabsf(right[i])>.50001f)return 0;
    float *a=malloc((size_t)n*sizeof(float)),*b=malloc((size_t)n*sizeof(float));
    if(!a||!b){free(a);free(b);return 0;}
    memcpy(a,left,(size_t)n*sizeof(float));memcpy(b,right,(size_t)n*sizeof(float));
    free(k->music_mono);k->music_mono=NULL;k->mono_count=0;
    free(k->music_left);free(k->music_right);k->music_left=a;k->music_right=b;k->music_count=n;return 1;
}
int cinder_music_take(CinderKernel *k,float *left,float *right,uint32_t n) {
    if(!k||k->frame||!left||!right||left==right||!n||(uint64_t)n*8>256000000)return 0;
    for(uint32_t i=0;i<n;i++)if(!isfinite(left[i])||!isfinite(right[i])||fabsf(left[i])>.50001f||fabsf(right[i])>.50001f)return 0;
    free(k->music_mono);k->music_mono=NULL;k->mono_count=0;
    free(k->music_left);free(k->music_right);
    k->music_left=left;k->music_right=right;k->music_count=n;return 1;
}
int cinder_music_mono_take(CinderKernel *k,float *mono,uint32_t n) {
    if(!k||k->frame||!mono||!n||(uint64_t)n*sizeof(float)>256000000)return 0;
    for(uint32_t i=0;i<n;i++)if(!isfinite(mono[i])||fabsf(mono[i])>.50001f)return 0;
    free(k->music_left);free(k->music_right);k->music_left=NULL;k->music_right=NULL;k->music_count=0;
    free(k->music_mono);k->music_mono=mono;k->mono_count=n;return 1;
}
void cinder_gain(CinderKernel *k,double db){if(k&&isfinite(db)&&db>=-60&&db<=0)atomic_store(&k->target,(float)pow(10,db/20));}
int cinder_program(CinderKernel *k,int step) {
    if(!k||k->frame||(step!=-1&&step!=0&&step!=2&&step!=3&&step!=4))return 0;
    k->program=step;return 1;
}
void cinder_pause(CinderKernel *k,int pause){if(k&&atomic_load(&k->requested)!=2)atomic_store(&k->requested,pause?1:0);}
void cinder_stop(CinderKernel *k){if(k)atomic_store(&k->requested,2);}
void cinder_render(CinderKernel *k,float *left,float *right,uint32_t count) {
    float peak=0;
    const int mode=atomic_load(&k->requested);
    const double target=mode?0:atomic_load(&k->target);
    for(uint32_t i=0;i<count;i++) {
        float value=0,other=0;
        k->gain+=(target-k->gain)*k->smoothing;
        if(mode&&k->gain<1e-6){atomic_store(&k->paused,mode==1);if(mode==2)atomic_store(&k->finished,1);}
        else if(k->frame<k->total&&!atomic_load(&k->finished)) {
            atomic_store(&k->paused,0);
            uint64_t position=k->frame%k->cycle;int step=0;
            while(step<5&&position>=k->lengths[step])position-=k->lengths[step++];
            if(k->program>=0){step=k->program;position=k->frame;}
            if(step==0||step==3)value=k->pink[position%k->noise_count];
            else if(step==2)value=k->band[position%k->noise_count];
            else if(step==4)value=k->sweep[position%k->sweep_count];
            other=value;
            if(step==3&&k->mono_count)value=other=k->music_mono[position%k->mono_count];
            else if(step==3&&k->music_count){value=k->music_left[position%k->music_count];other=k->music_right[position%k->music_count];}
            uint64_t duration=k->program>=0?k->total:k->lengths[step];
            double edge=fmin(1.,fmin((double)position,(double)(duration-1-position))/(k->rate*.75));
            double ending=fmin(1.,(double)(k->total-1-k->frame)/(k->rate*.75));
            value*=(float)(k->gain*edge*ending);
            other*=(float)(k->gain*edge*ending);
            k->frame++;if(step!=1&&step!=5)k->sound++;
            if(k->frame>=k->total)atomic_store(&k->finished,1);
        }
        // Fixed 100 ms measurement window, independent of UI polling.
        if(mode && atomic_load(&k->paused)) {
            k->window_energy=0;k->window_samples=0;atomic_store(&k->rms,0);
        } else {
            k->window_energy+=((double)value*value+(double)other*other)*.5;
            if(++k->window_samples>=k->window_size) {
                atomic_store(&k->rms,(float)sqrt(k->window_energy/k->window_samples));
                k->window_energy=0;k->window_samples=0;
            }
        }
        left[i]=value;right[i]=other;peak=fmaxf(peak,fmaxf(fabsf(value),fabsf(other)));
    }
    // Retain every block's peak until the UI consumes it.
    float previous=atomic_load(&k->peak);
    while(previous<peak&&!atomic_compare_exchange_weak(&k->peak,&previous,peak)) {}
    atomic_store(&k->published_frames,k->frame);atomic_store(&k->published_sound,k->sound);
}
CinderMetrics cinder_metrics(CinderKernel *k) {
    return (CinderMetrics){atomic_load(&k->published_frames),atomic_load(&k->published_sound),
        atomic_exchange(&k->peak,0),atomic_load(&k->rms),atomic_load(&k->paused),atomic_load(&k->finished)};
}
