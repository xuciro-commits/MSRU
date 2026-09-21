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
    int has_pending_packet;

    float **pending_buffers;
    int pending_capacity_frames;
    int pending_channels;
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


// MARK: - DSD Rate Selection Policy (P0-3)

/*
 * DSD-to-PCM decimation rate policy:
 * - DSD64 (2.8224 MHz bit clock or 352.8 kHz byte clock) -> 88.2 kHz
 * - DSD128 (5.6448 MHz bit clock or 705.6 kHz byte clock) -> 176.4 kHz
 * - DSD256 and above (11.2896 MHz+) -> 176.4 kHz (compatibility cap for AudioUnit / AVAudioEngine)
 * - 48kHz-family DSD (3.072 MHz, 6.144 MHz, etc.) -> 96 kHz / 192 kHz
 */
static int
msru_choose_dsd_pcm_rate(int source_sample_rate) {
    if (source_sample_rate <= 0) {
        return 88200;
    }

    // Check for 48kHz-family DSD (multiples of 48000, 384000, 3072000, etc.)
    if ((source_sample_rate % 48000 == 0) || (source_sample_rate % 384000 == 0)) {
        if (source_sample_rate >= 6144000 || (source_sample_rate >= 768000 && source_sample_rate < 2822400)) {
            return 192000;
        }
        return 96000;
    }

    // Standard 44.1kHz-family DSD (2.8224MHz / 352.8kHz for DSD64, 5.6448MHz / 705.6kHz for DSD128, etc.)
    if (source_sample_rate >= 5644800 || (source_sample_rate >= 705600 && source_sample_rate < 2822400)) {
        return 176400;
    }

    // DSD64 default -> 88.2 kHz
    return 88200;
}


// MARK: - Seekability Detection (P1-3)

static int
msru_compute_can_seek(const MSRUFFmpegDecoder *decoder) {
    if (decoder == NULL || decoder->format_context == NULL) {
        return 0;
    }

    if (decoder->format_context->pb != NULL) {
        if (decoder->format_context->pb->seekable & AVIO_SEEKABLE_NORMAL) {
            return 1;
        }
        if (decoder->format_context->pb->seekable != 0) {
            return 1;
        }
    }

    if (decoder->format_context->duration > 0) {
        return 1;
    }

    return 0;
}


// MARK: - Pending Buffer Management (P0-5)

static void
msru_free_pending_buffers(MSRUFFmpegDecoder *decoder) {
    if (decoder->pending_buffers != NULL) {
        for (int ch = 0; ch < decoder->pending_channels; ch++) {
            if (decoder->pending_buffers[ch] != NULL) {
                free(decoder->pending_buffers[ch]);
                decoder->pending_buffers[ch] = NULL;
            }
        }
        free(decoder->pending_buffers);
        decoder->pending_buffers = NULL;
    }
    decoder->pending_capacity_frames = 0;
    decoder->pending_channels = 0;
    decoder->pending_frames = 0;
    decoder->pending_offset = 0;
}

static int
msru_ensure_pending_capacity(
    MSRUFFmpegDecoder *decoder,
    int frames
) {
    int target_channels = decoder->output_channels > 0 ? decoder->output_channels : 2;

    // Cleanly reallocate if channel count changed
    if (decoder->pending_buffers != NULL && decoder->pending_channels != target_channels) {
        msru_free_pending_buffers(decoder);
    }

    if (decoder->pending_buffers != NULL && decoder->pending_capacity_frames >= frames) {
        return 0;
    }

    int new_capacity = frames > (decoder->pending_capacity_frames * 2)
        ? frames
        : (decoder->pending_capacity_frames * 2);
    if (new_capacity < 8192) {
        new_capacity = 8192;
    }

    if (decoder->pending_buffers == NULL) {
        float **new_buffers = (float **)calloc((size_t)target_channels, sizeof(float *));
        if (new_buffers == NULL) {
            return AVERROR(ENOMEM);
        }
        for (int ch = 0; ch < target_channels; ch++) {
            new_buffers[ch] = (float *)malloc((size_t)new_capacity * sizeof(float));
            if (new_buffers[ch] == NULL) {
                for (int i = 0; i < ch; i++) {
                    free(new_buffers[i]);
                }
                free(new_buffers);
                return AVERROR(ENOMEM);
            }
        }
        decoder->pending_buffers = new_buffers;
        decoder->pending_channels = target_channels;
        decoder->pending_capacity_frames = new_capacity;
        decoder->pending_frames = 0;
        decoder->pending_offset = 0;
        return 0;
    }

    // Safe realloc for existing channel buffers
    for (int ch = 0; ch < target_channels; ch++) {
        float *re = (float *)realloc(decoder->pending_buffers[ch], (size_t)new_capacity * sizeof(float));
        if (re == NULL) {
            return AVERROR(ENOMEM);
        }
        decoder->pending_buffers[ch] = re;
    }

    decoder->pending_capacity_frames = new_capacity;
    return 0;
}


// MARK: - Resampler Configuration (P0-2, P0-4)

/*
 * Note: DSD-to-PCM decimation pipeline:
 * Decodes DSD bitstream to float planar samples, resampled/filtered via libswresample
 * into target float planar PCM (AV_SAMPLE_FMT_FLTP). Does NOT claim Native DSD or DoP.
 */
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
        decoder->swr_context = NULL;
    }

    decoder->source_sample_rate = frame_rate;
    decoder->source_sample_format = frame_fmt;
    av_channel_layout_uninit(&decoder->source_channel_layout);
    av_channel_layout_copy(&decoder->source_channel_layout, &frame->ch_layout);

    // Multichannel preservation: do not downmix to stereo! Preserve full channel layout.
    av_channel_layout_uninit(&decoder->output_channel_layout);
    av_channel_layout_copy(&decoder->output_channel_layout, &frame->ch_layout);
    decoder->output_channels = frame->ch_layout.nb_channels;

    if (decoder->is_dsd) {
        decoder->output_sample_rate = msru_choose_dsd_pcm_rate(decoder->source_sample_rate);
    } else {
        decoder->output_sample_rate = decoder->source_sample_rate > 0 ? decoder->source_sample_rate : 44100;
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

    return swr_init(decoder->swr_context);
}

static int
msru_configure_resampler_fallback(
    MSRUFFmpegDecoder *decoder
) {
    if (decoder->swr_context != NULL) {
        return 0;
    }

    decoder->source_sample_rate = decoder->codec_context->sample_rate > 0 ? decoder->codec_context->sample_rate : 44100;
    decoder->source_sample_format = decoder->codec_context->sample_fmt != AV_SAMPLE_FMT_NONE ? decoder->codec_context->sample_fmt : AV_SAMPLE_FMT_FLTP;
    av_channel_layout_uninit(&decoder->source_channel_layout);
    av_channel_layout_copy(&decoder->source_channel_layout, &decoder->codec_context->ch_layout);

    av_channel_layout_uninit(&decoder->output_channel_layout);
    av_channel_layout_copy(&decoder->output_channel_layout, &decoder->source_channel_layout);
    decoder->output_channels = decoder->source_channel_layout.nb_channels > 0 ? decoder->source_channel_layout.nb_channels : 2;

    if (decoder->is_dsd) {
        decoder->output_sample_rate = msru_choose_dsd_pcm_rate(decoder->source_sample_rate);
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

    return swr_init(decoder->swr_context);
}


// MARK: - Open (P1-1: Probing First Frame & Locking Format)

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

    // Check if DSD format
    if (codec->id == AV_CODEC_ID_DSD_LSBF
        || codec->id == AV_CODEC_ID_DSD_MSBF
        || codec->id == AV_CODEC_ID_DSD_LSBF_PLANAR
        || codec->id == AV_CODEC_ID_DSD_MSBF_PLANAR) {
        decoder->is_dsd = 1;
        // P0-2: Request float planar samples from DSD decoder
        decoder->codec_context->request_sample_fmt = AV_SAMPLE_FMT_FLTP;
    } else {
        decoder->is_dsd = 0;
    }

    ret = avcodec_open2(decoder->codec_context, codec, NULL);
    if (ret < 0) {
        msru_write_ffmpeg_error(error_buffer, error_buffer_size, "Failed to open codec", ret);
        avcodec_free_context(&decoder->codec_context);
        avformat_close_input(&decoder->format_context);
        free(decoder);
        return NULL;
    }

    decoder->source_sample_rate = decoder->codec_context->sample_rate;
    decoder->source_channels = decoder->codec_context->ch_layout.nb_channels;
    decoder->source_sample_format = decoder->codec_context->sample_fmt;
    av_channel_layout_copy(&decoder->source_channel_layout, &decoder->codec_context->ch_layout);

    av_channel_layout_copy(&decoder->output_channel_layout, &decoder->source_channel_layout);
    decoder->output_channels = decoder->source_channels;

    if (decoder->is_dsd) {
        decoder->output_sample_rate = msru_choose_dsd_pcm_rate(decoder->source_sample_rate);
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

    // P1-1: Probe the first valid audio frame to negotiate and lock output parameters
    int probed = 0;
    while (!probed && !decoder->reached_eof) {
        int r_ret = avcodec_receive_frame(decoder->codec_context, decoder->frame);
        if (r_ret == 0) {
            probed = 1;
            break;
        } else if (r_ret == AVERROR_EOF) {
            decoder->reached_eof = 1;
            break;
        } else if (r_ret == AVERROR(EAGAIN)) {
            int got_packet = 0;
            while (!got_packet) {
                int read_ret = av_read_frame(decoder->format_context, decoder->packet);
                if (read_ret == AVERROR_EOF) {
                    if (!decoder->sent_flush) {
                        avcodec_send_packet(decoder->codec_context, NULL);
                        decoder->sent_flush = 1;
                    }
                    break;
                } else if (read_ret < 0) {
                    break;
                }

                if (decoder->packet->stream_index == decoder->stream_index) {
                    int send_ret = avcodec_send_packet(decoder->codec_context, decoder->packet);
                    if (send_ret == 0) {
                        av_packet_unref(decoder->packet);
                        got_packet = 1;
                    } else if (send_ret == AVERROR(EAGAIN)) {
                        decoder->has_pending_packet = 1;
                        got_packet = 1;
                    } else {
                        av_packet_unref(decoder->packet);
                        break;
                    }
                } else {
                    av_packet_unref(decoder->packet);
                }
            }
            if (!got_packet && decoder->sent_flush) {
                continue;
            }
            if (!got_packet) {
                break;
            }
        } else {
            break;
        }
    }

    if (probed && decoder->frame->nb_samples > 0) {
        int config_ret = msru_configure_resampler(decoder, decoder->frame);
        if (config_ret >= 0) {
            int max_out = swr_get_out_samples(decoder->swr_context, decoder->frame->nb_samples);
            if (max_out <= 0) {
                max_out = decoder->frame->nb_samples;
            }
            if (msru_ensure_pending_capacity(decoder, max_out) >= 0) {
                int converted = swr_convert(
                    decoder->swr_context,
                    (uint8_t **)decoder->pending_buffers,
                    max_out,
                    (const uint8_t **)decoder->frame->extended_data,
                    decoder->frame->nb_samples
                );
                if (converted > 0) {
                    decoder->pending_frames = converted;
                    decoder->pending_offset = 0;
                }
            }
        }
        av_frame_unref(decoder->frame);
    } else {
        msru_configure_resampler_fallback(decoder);
    }

    // Calculate duration
    double duration = 0.0;
    if (stream->duration > 0 && stream->time_base.den > 0) {
        duration = (double)stream->duration * av_q2d(stream->time_base);
    } else if (decoder->format_context->duration > 0) {
        duration = (double)decoder->format_context->duration / (double)AV_TIME_BASE;
    }

    // Return locked output format information
    info->sample_rate = decoder->output_sample_rate;
    info->channels = decoder->output_channels;
    info->channel_layout_mask = (decoder->output_channel_layout.order == AV_CHANNEL_ORDER_NATIVE)
        ? decoder->output_channel_layout.u.mask
        : 0;
    info->duration_seconds = duration;
    info->bit_rate = decoder->format_context->bit_rate > 0 ? decoder->format_context->bit_rate : decoder->codec_context->bit_rate;
    info->can_seek = msru_compute_can_seek(decoder);

    snprintf(info->codec_name, sizeof(info->codec_name), "%s", codec->name != NULL ? codec->name : "unknown");
    snprintf(info->format_name, sizeof(info->format_name), "%s", decoder->format_context->iformat->name != NULL ? decoder->format_context->iformat->name : "unknown");

    return (MSRUFFmpegDecoderRef)decoder;
}


// MARK: - Read (P0-1, P0-4)

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
        // 1. Drain pending converted frames first
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

        // 2. Try to receive decoded frame
        int ret = avcodec_receive_frame(decoder->codec_context, decoder->frame);
        if (ret == 0) {
            // Frame received! Convert and store into pending_buffers
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

            // P0-4: Use extended_data for planar and multichannel safety (>8 channels)
            int converted = swr_convert(
                decoder->swr_context,
                (uint8_t **)decoder->pending_buffers,
                max_out,
                (const uint8_t **)decoder->frame->extended_data,
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
            // P0-1: Standard send/receive state machine
            // If we have a pending packet from earlier EAGAIN, try sending it again
            if (decoder->has_pending_packet) {
                int send_ret = avcodec_send_packet(decoder->codec_context, decoder->packet);
                if (send_ret == 0) {
                    av_packet_unref(decoder->packet);
                    decoder->has_pending_packet = 0;
                    continue; // Loop back to receive_frame
                } else if (send_ret == AVERROR(EAGAIN)) {
                    // Packet not accepted yet, drain frames if possible
                } else if (send_ret == AVERROR_EOF) {
                    av_packet_unref(decoder->packet);
                    decoder->has_pending_packet = 0;
                    decoder->reached_eof = 1;
                    break;
                } else {
                    msru_write_ffmpeg_error(error_buffer, error_buffer_size, "Send packet failed", send_ret);
                    av_packet_unref(decoder->packet);
                    decoder->has_pending_packet = 0;
                    return -1;
                }
            }

            // Read packets until a packet is accepted or EOF
            int packet_sent = 0;
            while (!packet_sent && !decoder->has_pending_packet) {
                int read_ret = av_read_frame(decoder->format_context, decoder->packet);
                if (read_ret == AVERROR_EOF) {
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
                    if (send_ret == 0) {
                        av_packet_unref(decoder->packet);
                        packet_sent = 1;
                    } else if (send_ret == AVERROR(EAGAIN)) {
                        // DO NOT UNREF! Keep packet in decoder->packet
                        decoder->has_pending_packet = 1;
                        packet_sent = 1;
                    } else if (send_ret == AVERROR_EOF) {
                        av_packet_unref(decoder->packet);
                        decoder->reached_eof = 1;
                        packet_sent = 1;
                    } else {
                        msru_write_ffmpeg_error(error_buffer, error_buffer_size, "Send packet failed", send_ret);
                        av_packet_unref(decoder->packet);
                        return -1;
                    }
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


// MARK: - Seek (P1-2: Complete State Cleanup)

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

    // 1. Flush codec buffers
    if (decoder->codec_context != NULL) {
        avcodec_flush_buffers(decoder->codec_context);
    }

    // 2. Unref any pending packet
    if (decoder->has_pending_packet) {
        av_packet_unref(decoder->packet);
        decoder->has_pending_packet = 0;
    }

    // 3. Unref any cached frame
    if (decoder->frame != NULL) {
        av_frame_unref(decoder->frame);
    }

    // 4. Clear pending buffer state
    decoder->pending_frames = 0;
    decoder->pending_offset = 0;

    // 5. Reset EOF and flush flags
    decoder->reached_eof = 0;
    decoder->sent_flush = 0;

    // 6. Free resampler context so next frame rebuilds it fresh, eliminating stale filter delay
    if (decoder->swr_context != NULL) {
        swr_free(&decoder->swr_context);
        decoder->swr_context = NULL;
    }

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

    msru_free_pending_buffers(decoder);

    if (decoder->swr_context != NULL) {
        swr_free(&decoder->swr_context);
        decoder->swr_context = NULL;
    }

    if (decoder->frame != NULL) {
        av_frame_free(&decoder->frame);
    }

    if (decoder->packet != NULL) {
        if (decoder->has_pending_packet) {
            av_packet_unref(decoder->packet);
            decoder->has_pending_packet = 0;
        }
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
