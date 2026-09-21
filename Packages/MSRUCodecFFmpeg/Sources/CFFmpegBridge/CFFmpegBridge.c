#include "MSRUFFmpegBridge.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
#include <libavutil/channel_layout.h>
#include <libavutil/error.h>
#include <libavutil/mathematics.h>
#include <libswresample/swresample.h>


typedef struct {

    AVFormatContext *format_context;

    AVCodecContext *codec_context;

    SwrContext *swr_context;

    AVPacket *packet;

    AVFrame *frame;

    int stream_index;


    int source_sample_rate;

    int source_channels;

    AVChannelLayout source_channel_layout;

    enum AVSampleFormat source_sample_format;


    int output_sample_rate;

    int output_channels;

    AVChannelLayout output_channel_layout;


    int is_dsd;

    int reached_eof;

    int sent_flush;


    float **pending_buffers;

    int pending_capacity;

    int pending_frames;

    int pending_offset;

} MSRUFFmpegDecoder;


// MARK: - Error Helpers

static void
msru_write_error(
    char *buffer,
    int32_t buffer_size,
    const char *message
) {
    if (buffer == NULL || buffer_size <= 0) {
        return;
    }

    snprintf(
        buffer,
        (size_t) buffer_size,
        "%s",
        message
    );
}

static void
msru_write_ffmpeg_error(
    char *buffer,
    int32_t buffer_size,
    const char *prefix,
    int error_code
) {
    char error_text[AV_ERROR_MAX_STRING_SIZE] = { 0 };

    av_strerror(
        error_code,
        error_text,
        sizeof(error_text)
    );

    if (buffer == NULL || buffer_size <= 0) {
        return;
    }

    snprintf(
        buffer,
        (size_t) buffer_size,
        "%s: %s",
        prefix,
        error_text
    );
}


// MARK: - Pending Buffer Management

static int
msru_ensure_pending_capacity(
    MSRUFFmpegDecoder *decoder,
    int frames
) {
    if (decoder->pending_capacity >= frames && decoder->pending_buffers != NULL) {
        return 0;
    }

    int new_capacity = frames > (decoder->pending_capacity * 2) ? frames : (decoder->pending_capacity * 2);
    if (new_capacity < 8192) {
        new_capacity = 8192;
    }

    int channels = decoder->output_channels;
    if (channels <= 0) {
        channels = 2;
    }

    if (decoder->pending_buffers == NULL) {
        decoder->pending_buffers = (float **)calloc((size_t)channels, sizeof(float *));
        if (decoder->pending_buffers == NULL) {
            return AVERROR(ENOMEM);
        }
        for (int ch = 0; ch < channels; ch++) {
            decoder->pending_buffers[ch] = (float *)malloc((size_t)new_capacity * sizeof(float));
            if (decoder->pending_buffers[ch] == NULL) {
                return AVERROR(ENOMEM);
            }
        }
    } else {
        for (int ch = 0; ch < channels; ch++) {
            float *re = (float *)realloc(decoder->pending_buffers[ch], (size_t)new_capacity * sizeof(float));
            if (re == NULL) {
                return AVERROR(ENOMEM);
            }
            decoder->pending_buffers[ch] = re;
        }
    }

    decoder->pending_capacity = new_capacity;
    return 0;
}


// MARK: - Resampler Configuration

static int
msru_configure_resampler(
    MSRUFFmpegDecoder *decoder,
    AVFrame *frame
) {
    const int frame_rate = frame->sample_rate > 0 ? frame->sample_rate : decoder->source_sample_rate;
    const enum AVSampleFormat frame_fmt = (enum AVSampleFormat)frame->format;

    if (decoder->swr_context != NULL
        && decoder->source_sample_rate == frame_rate
        && decoder->source_sample_format == frame_fmt
        && av_channel_layout_compare(&decoder->source_channel_layout, &frame->ch_layout) == 0) {
        return 0;
    }

    if (decoder->swr_context != NULL) {
        swr_free(&decoder->swr_context);
    }

    decoder->source_sample_rate = frame_rate;
    decoder->source_sample_format = frame_fmt;
    av_channel_layout_uninit(&decoder->source_channel_layout);
    av_channel_layout_copy(&decoder->source_channel_layout, &frame->ch_layout);

    // Preserve source channel layout! Do NOT downmix to stereo.
    av_channel_layout_uninit(&decoder->output_channel_layout);
    av_channel_layout_copy(&decoder->output_channel_layout, &frame->ch_layout);
    decoder->output_channels = frame->ch_layout.nb_channels;

    // Sample rate policy:
    // DSD -> PCM requires conversion (e.g. 88.2 kHz for DSD64, 176.4 kHz for DSD128+)
    // PCM (APE, DTS) -> preserve source sample rate!
    if (decoder->is_dsd) {
        if (decoder->source_sample_rate >= 5644800) {
            decoder->output_sample_rate = 176400;
        } else {
            decoder->output_sample_rate = 88200;
        }
    } else {
        decoder->output_sample_rate = decoder->source_sample_rate;
    }

    int ret = swr_alloc_set_opts2(
        &decoder->swr_context,
        &decoder->output_channel_layout,
        AV_SAMPLE_FMT_FLTP,
        decoder->output_sample_rate,
        &decoder->source_channel_layout,
        decoder->source_sample_format,
        decoder->source_sample_rate,
        0,
        NULL
    );

    if (ret < 0) {
        return ret;
    }

    ret = swr_init(decoder->swr_context);
    return ret;
}


// MARK: - Open

MSRUFFmpegDecoderRef
msru_ffmpeg_decoder_open(
    const char *path,
    MSRUFFmpegAudioInfo *info,
    char *error_buffer,
    int32_t error_buffer_size
) {
    if (path == NULL || info == NULL) {
        msru_write_error(error_buffer, error_buffer_size, "Invalid arguments to msru_ffmpeg_decoder_open.");
        return NULL;
    }

    MSRUFFmpegDecoder *decoder = (MSRUFFmpegDecoder *)calloc(1, sizeof(MSRUFFmpegDecoder));
    if (decoder == NULL) {
        msru_write_error(error_buffer, error_buffer_size, "Out of memory allocating MSRUFFmpegDecoder.");
        return NULL;
    }

    int ret = avformat_open_input(&decoder->format_context, path, NULL, NULL);
    if (ret < 0) {
        msru_write_ffmpeg_error(error_buffer, error_buffer_size, "Cannot open input file", ret);
        free(decoder);
        return NULL;
    }

    ret = avformat_find_stream_info(decoder->format_context, NULL);
    if (ret < 0) {
        msru_write_ffmpeg_error(error_buffer, error_buffer_size, "Cannot find stream information", ret);
        avformat_close_input(&decoder->format_context);
        free(decoder);
        return NULL;
    }

    const AVCodec *codec = NULL;
    int audio_stream = av_find_best_stream(decoder->format_context, AVMEDIA_TYPE_AUDIO, -1, -1, &codec, 0);
    if (audio_stream < 0 || codec == NULL) {
        msru_write_error(error_buffer, error_buffer_size, "No supported audio stream found in container.");
        avformat_close_input(&decoder->format_context);
        free(decoder);
        return NULL;
    }

    decoder->stream_index = audio_stream;
    AVStream *stream = decoder->format_context->streams[audio_stream];

    decoder->codec_context = avcodec_alloc_context3(codec);
    if (decoder->codec_context == NULL) {
        msru_write_error(error_buffer, error_buffer_size, "Cannot allocate codec context.");
        avformat_close_input(&decoder->format_context);
        free(decoder);
        return NULL;
    }

    ret = avcodec_parameters_to_context(decoder->codec_context, stream->codecpar);
    if (ret < 0) {
        msru_write_ffmpeg_error(error_buffer, error_buffer_size, "Failed to copy codec parameters", ret);
        avcodec_free_context(&decoder->codec_context);
        avformat_close_input(&decoder->format_context);
        free(decoder);
        return NULL;
    }

    ret = avcodec_open2(decoder->codec_context, codec, NULL);
    if (ret < 0) {
        msru_write_ffmpeg_error(error_buffer, error_buffer_size, "Failed to open codec", ret);
        avcodec_free_context(&decoder->codec_context);
        avformat_close_input(&decoder->format_context);
        free(decoder);
        return NULL;
    }

    // Check if DSD format
    if (codec->id == AV_CODEC_ID_DSD_LSBF
        || codec->id == AV_CODEC_ID_DSD_MSBF
        || codec->id == AV_CODEC_ID_DSD_LSBF_PLANAR
        || codec->id == AV_CODEC_ID_DSD_MSBF_PLANAR) {
        decoder->is_dsd = 1;
    } else {
        decoder->is_dsd = 0;
    }

    decoder->source_sample_rate = decoder->codec_context->sample_rate;
    decoder->source_channels = decoder->codec_context->ch_layout.nb_channels;
    decoder->source_sample_format = decoder->codec_context->sample_fmt;
    av_channel_layout_copy(&decoder->source_channel_layout, &decoder->codec_context->ch_layout);

    // Initial output layout matches source layout
    av_channel_layout_copy(&decoder->output_channel_layout, &decoder->source_channel_layout);
    decoder->output_channels = decoder->source_channels;

    if (decoder->is_dsd) {
        if (decoder->source_sample_rate >= 5644800) {
            decoder->output_sample_rate = 176400;
        } else {
            decoder->output_sample_rate = 88200;
        }
    } else {
        decoder->output_sample_rate = decoder->source_sample_rate > 0 ? decoder->source_sample_rate : 44100;
    }

    decoder->packet = av_packet_alloc();
    decoder->frame = av_frame_alloc();
    if (decoder->packet == NULL || decoder->frame == NULL) {
        msru_write_error(error_buffer, error_buffer_size, "Cannot allocate AVFrame or AVPacket.");
        msru_ffmpeg_decoder_close(decoder);
        return NULL;
    }

    // Calculate duration
    double duration = 0.0;
    if (stream->duration > 0 && stream->time_base.den > 0) {
        duration = (double)stream->duration * av_q2d(stream->time_base);
    } else if (decoder->format_context->duration > 0) {
        duration = (double)decoder->format_context->duration / (double)AV_TIME_BASE;
    }

    info->sample_rate = decoder->output_sample_rate;
    info->channels = decoder->output_channels;
    info->channel_layout_mask = decoder->output_channel_layout.order == AV_CHANNEL_ORDER_NATIVE ? decoder->output_channel_layout.u.mask : 0;
    info->duration_seconds = duration;
    info->bit_rate = decoder->format_context->bit_rate > 0 ? decoder->format_context->bit_rate : decoder->codec_context->bit_rate;
    info->can_seek = 1;

    snprintf(info->codec_name, sizeof(info->codec_name), "%s", codec->name != NULL ? codec->name : "unknown");
    snprintf(info->format_name, sizeof(info->format_name), "%s", decoder->format_context->iformat->name != NULL ? decoder->format_context->iformat->name : "unknown");

    return (MSRUFFmpegDecoderRef)decoder;
}


// MARK: - Read

int32_t
msru_ffmpeg_decoder_read(
    MSRUFFmpegDecoderRef decoder_ref,
    float **channel_buffers,
    int32_t channel_count,
    int32_t capacity_frames,
    int32_t *output_frames,
    char *error_buffer,
    int32_t error_buffer_size
) {
    MSRUFFmpegDecoder *decoder = (MSRUFFmpegDecoder *)decoder_ref;
    if (decoder == NULL || channel_buffers == NULL || capacity_frames <= 0 || output_frames == NULL) {
        msru_write_error(error_buffer, error_buffer_size, "Invalid arguments to msru_ffmpeg_decoder_read.");
        return -1;
    }

    *output_frames = 0;
    int frames_needed = capacity_frames;
    int frames_written = 0;

    while (frames_needed > 0) {
        // Drain pending converted frames first
        int available = decoder->pending_frames - decoder->pending_offset;
        if (available > 0) {
            int to_copy = available < frames_needed ? available : frames_needed;
            int ch_to_copy = decoder->output_channels < channel_count ? decoder->output_channels : channel_count;

            for (int ch = 0; ch < ch_to_copy; ch++) {
                if (channel_buffers[ch] != NULL && decoder->pending_buffers[ch] != NULL) {
                    memcpy(
                        channel_buffers[ch] + frames_written,
                        decoder->pending_buffers[ch] + decoder->pending_offset,
                        (size_t)to_copy * sizeof(float)
                    );
                }
            }

            // Zero any extra destination channels
            for (int ch = ch_to_copy; ch < channel_count; ch++) {
                if (channel_buffers[ch] != NULL) {
                    memset(channel_buffers[ch] + frames_written, 0, (size_t)to_copy * sizeof(float));
                }
            }

            decoder->pending_offset += to_copy;
            frames_written += to_copy;
            frames_needed -= to_copy;

            if (frames_needed == 0) {
                break;
            }
        }

        // Pending buffer exhausted, reset counters
        decoder->pending_frames = 0;
        decoder->pending_offset = 0;

        if (decoder->reached_eof) {
            break;
        }

        // Try to receive a decoded frame from codec
        int ret = avcodec_receive_frame(decoder->codec_context, decoder->frame);
        if (ret == 0) {
            // Convert frame using SwrContext
            int configure_ret = msru_configure_resampler(decoder, decoder->frame);
            if (configure_ret < 0) {
                msru_write_ffmpeg_error(error_buffer, error_buffer_size, "Resampler configuration failed", configure_ret);
                av_frame_unref(decoder->frame);
                return -1;
            }

            int max_out = swr_get_out_samples(decoder->swr_context, decoder->frame->nb_samples);
            if (max_out <= 0) {
                max_out = decoder->frame->nb_samples;
            }

            int ensure_ret = msru_ensure_pending_capacity(decoder, max_out);
            if (ensure_ret < 0) {
                msru_write_ffmpeg_error(error_buffer, error_buffer_size, "Out of memory in pending buffer", ensure_ret);
                av_frame_unref(decoder->frame);
                return -1;
            }

            int converted = swr_convert(
                decoder->swr_context,
                (uint8_t **)decoder->pending_buffers,
                max_out,
                (const uint8_t **)decoder->frame->data,
                decoder->frame->nb_samples
            );

            av_frame_unref(decoder->frame);

            if (converted < 0) {
                msru_write_ffmpeg_error(error_buffer, error_buffer_size, "Swr conversion failed", converted);
                return -1;
            }

            decoder->pending_frames = converted;
            decoder->pending_offset = 0;
            continue;
        } else if (ret == AVERROR_EOF) {
            decoder->reached_eof = 1;
            break;
        } else if (ret == AVERROR(EAGAIN)) {
            // Need to feed more packets to decoder
            while (1) {
                int read_ret = av_read_frame(decoder->format_context, decoder->packet);
                if (read_ret == AVERROR_EOF) {
                    // Send flush packet to decoder
                    if (!decoder->sent_flush) {
                        avcodec_send_packet(decoder->codec_context, NULL);
                        decoder->sent_flush = 1;
                    }
                    break;
                } else if (read_ret < 0) {
                    msru_write_ffmpeg_error(error_buffer, error_buffer_size, "Read frame failed", read_ret);
                    return -1;
                }

                if (decoder->packet->stream_index == decoder->stream_index) {
                    int send_ret = avcodec_send_packet(decoder->codec_context, decoder->packet);
                    av_packet_unref(decoder->packet);
                    if (send_ret < 0 && send_ret != AVERROR(EAGAIN)) {
                        msru_write_ffmpeg_error(error_buffer, error_buffer_size, "Send packet failed", send_ret);
                        return -1;
                    }
                    break;
                } else {
                    av_packet_unref(decoder->packet);
                }
            }
        } else {
            msru_write_ffmpeg_error(error_buffer, error_buffer_size, "Codec receive frame failed", ret);
            return -1;
        }
    }

    *output_frames = frames_written;
    if (frames_written > 0) {
        return 1;
    } else if (decoder->reached_eof) {
        return 0;
    } else {
        return 0;
    }
}


// MARK: - Seek

int32_t
msru_ffmpeg_decoder_seek(
    MSRUFFmpegDecoderRef decoder_ref,
    double seconds,
    char *error_buffer,
    int32_t error_buffer_size
) {
    MSRUFFmpegDecoder *decoder = (MSRUFFmpegDecoder *)decoder_ref;
    if (decoder == NULL || decoder->format_context == NULL) {
        msru_write_error(error_buffer, error_buffer_size, "Invalid decoder reference in seek.");
        return -1;
    }

    AVStream *stream = decoder->format_context->streams[decoder->stream_index];
    int64_t target_ts = 0;
    if (stream->time_base.den > 0) {
        target_ts = av_rescale_q((int64_t)(seconds * (double)AV_TIME_BASE), AV_TIME_BASE_Q, stream->time_base);
    } else {
        target_ts = (int64_t)(seconds * (double)AV_TIME_BASE);
    }

    int ret = av_seek_frame(decoder->format_context, decoder->stream_index, target_ts, AVSEEK_FLAG_BACKWARD);
    if (ret < 0) {
        ret = av_seek_frame(decoder->format_context, decoder->stream_index, target_ts, 0);
    }

    if (ret < 0) {
        msru_write_ffmpeg_error(error_buffer, error_buffer_size, "av_seek_frame failed", ret);
        return -1;
    }

    if (decoder->codec_context != NULL) {
        avcodec_flush_buffers(decoder->codec_context);
    }

    if (decoder->swr_context != NULL) {
        swr_init(decoder->swr_context);
    }

    decoder->pending_frames = 0;
    decoder->pending_offset = 0;
    decoder->reached_eof = 0;
    decoder->sent_flush = 0;

    return 0;
}


// MARK: - Close

void
msru_ffmpeg_decoder_close(
    MSRUFFmpegDecoderRef decoder_ref
) {
    MSRUFFmpegDecoder *decoder = (MSRUFFmpegDecoder *)decoder_ref;
    if (decoder == NULL) {
        return;
    }

    if (decoder->pending_buffers != NULL) {
        for (int ch = 0; ch < decoder->output_channels; ch++) {
            if (decoder->pending_buffers[ch] != NULL) {
                free(decoder->pending_buffers[ch]);
            }
        }
        free(decoder->pending_buffers);
        decoder->pending_buffers = NULL;
    }

    if (decoder->swr_context != NULL) {
        swr_free(&decoder->swr_context);
    }

    if (decoder->frame != NULL) {
        av_frame_free(&decoder->frame);
    }

    if (decoder->packet != NULL) {
        av_packet_free(&decoder->packet);
    }

    if (decoder->codec_context != NULL) {
        avcodec_free_context(&decoder->codec_context);
    }

    if (decoder->format_context != NULL) {
        avformat_close_input(&decoder->format_context);
    }

    av_channel_layout_uninit(&decoder->source_channel_layout);
    av_channel_layout_uninit(&decoder->output_channel_layout);

    free(decoder);
}


// MARK: - Version

const char *
msru_ffmpeg_version(void) {
    return av_version_info();
}
