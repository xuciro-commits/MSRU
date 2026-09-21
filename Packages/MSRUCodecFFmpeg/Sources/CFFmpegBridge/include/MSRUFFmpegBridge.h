#ifndef MSRU_FFMPEG_BRIDGE_H
#define MSRU_FFMPEG_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif


typedef void *MSRUFFmpegDecoderRef;


typedef struct {

    int32_t sample_rate;

    int32_t channels;

    uint64_t channel_layout_mask;

    double duration_seconds;

    int64_t bit_rate;

    int32_t can_seek;

    char codec_name[32];

    char format_name[32];

} MSRUFFmpegAudioInfo;


/*
 Return:

  1  = frames returned
  0  = EOF
 -1 = error
 */


MSRUFFmpegDecoderRef
msru_ffmpeg_decoder_open(
    const char *path,
    MSRUFFmpegAudioInfo *info,
    char *error_buffer,
    int32_t error_buffer_size
);


int32_t
msru_ffmpeg_decoder_read(
    MSRUFFmpegDecoderRef decoder,
    float **channel_buffers,
    int32_t channel_count,
    int32_t capacity_frames,
    int32_t *output_frames,
    char *error_buffer,
    int32_t error_buffer_size
);


int32_t
msru_ffmpeg_decoder_seek(
    MSRUFFmpegDecoderRef decoder,
    double seconds,
    char *error_buffer,
    int32_t error_buffer_size
);


void
msru_ffmpeg_decoder_close(
    MSRUFFmpegDecoderRef decoder
);


const char *
msru_ffmpeg_version(void);


#ifdef __cplusplus
}
#endif

#endif
