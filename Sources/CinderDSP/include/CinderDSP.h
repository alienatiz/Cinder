#ifndef CINDER_DSP_H
#define CINDER_DSP_H
#include <stdint.h>
typedef struct CinderKernel CinderKernel;
typedef struct { uint64_t frames, sound_frames; float peak, rms; int paused, finished; } CinderMetrics;
CinderKernel *cinder_create(double rate, double hours, double gain_db);
void cinder_destroy(CinderKernel *kernel);
/* Preparation only: -1 full cycle; 0 pink, 2 band, 3 music, 4 sweep. */
int cinder_program(CinderKernel *kernel, int step);
/* Preparation only, before rendering starts. Copies bounded stereo buffers. */
int cinder_music(CinderKernel *kernel, const float *left, const float *right, uint32_t frames);
/* Takes malloc-buffer ownership on success only; preparation thread only. */
int cinder_music_take(CinderKernel *kernel, float *left, float *right, uint32_t frames);
/* Preparation only. Takes malloc-owned mono loop on success; caller owns it on failure. */
int cinder_music_mono_take(CinderKernel *kernel, float *mono, uint32_t frames);
void cinder_gain(CinderKernel *kernel, double gain_db);
void cinder_pause(CinderKernel *kernel, int pause);
void cinder_stop(CinderKernel *kernel);
void cinder_render(CinderKernel *kernel, float *left, float *right, uint32_t frames);
CinderMetrics cinder_metrics(CinderKernel *kernel);
#endif
