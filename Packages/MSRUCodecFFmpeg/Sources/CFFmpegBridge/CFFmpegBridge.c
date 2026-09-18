#include "MSRUFFmpegBridge.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
#include <libavutil/channel_layout.h>
#include <libavutil/error.h>
#include <libavutil/mathematics.h>
#include <libswresample/swresample.h>


#define MSRU_INPUT_BUFFER_SIZE 32768


typedef struct {

    FILE *file;

    int64_t file_size;


    AVCodecParserContext *parser;

    AVCodecContext *codec_context;

    AVPacket *packet;

    AVFrame *frame;

    SwrContext *swr_context;


    uint8_t input_buffer[
        MSRU_INPUT_BUFFER_SIZE
        + AV_INPUT_BUFFER_PADDING_SIZE
    ];

    uint8_t *input_data;

    int input_size;


    int source_sample_rate;

    enum AVSampleFormat source_sample_format;

    int source_channels;


    int output_sample_rate;

    int64_t bit_rate;


    int reached_file_eof;

    int sent_decoder_flush;

    int reached_decoder_eof;


    float *pending_left;

    float *pending_right;

    int pending_capacity;

    int pending_frames;

    int pending_offset;

} MSRUFFmpegDecoder;


// MARK: - Error

static void
msru_write_error(
    char *buffer,
    int32_t buffer_size,
    const char *message
) {

    if (
        buffer == NULL
        || buffer_size <= 0
    ) {
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

    char error_text[
        AV_ERROR_MAX_STRING_SIZE
    ] = { 0 };


    av_strerror(
        error_code,
        error_text,
        sizeof(error_text)
    );


    if (
        buffer == NULL
        || buffer_size <= 0
    ) {
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


// MARK: - Pending PCM

static int
msru_ensure_pending_capacity(
    MSRUFFmpegDecoder *decoder,
    int frames
) {

    if (
        decoder->pending_capacity
        >= frames
    ) {
        return 0;
    }


    int new_capacity =
        frames;


    float *new_left =
        realloc(
            decoder->pending_left,
            sizeof(float)
            * (size_t) new_capacity
        );


    if (
        new_left == NULL
    ) {
        return AVERROR(ENOMEM);
    }


    decoder->pending_left =
        new_left;


    float *new_right =
        realloc(
            decoder->pending_right,
            sizeof(float)
            * (size_t) new_capacity
        );


    if (
        new_right == NULL
    ) {
        return AVERROR(ENOMEM);
    }


    decoder->pending_right =
        new_right;


    decoder->pending_capacity =
        new_capacity;


    return 0;
}


// MARK: - Resampler

static int
msru_configure_resampler(
    MSRUFFmpegDecoder *decoder,
    AVFrame *frame
) {

    const int sample_rate =
        frame->sample_rate;


    const int channels =
        frame->ch_layout.nb_channels;


    const enum AVSampleFormat sample_format =
        (enum AVSampleFormat)
        frame->format;


    if (
        decoder->swr_context != NULL
        &&
        decoder->source_sample_rate
            == sample_rate
        &&
        decoder->source_sample_format
            == sample_format
        &&
        decoder->source_channels
            == channels
    ) {

        return 0;
    }


    if (
        decoder->swr_context != NULL
    ) {

        swr_free(
            &decoder->swr_context
        );
    }


    AVChannelLayout output_layout =
        AV_CHANNEL_LAYOUT_STEREO;


    int result =
        swr_alloc_set_opts2(
            &decoder->swr_context,

            &output_layout,

            AV_SAMPLE_FMT_FLTP,

            sample_rate,

            &frame->ch_layout,

            sample_format,

            sample_rate,

            0,

            NULL
        );


    if (
        result < 0
    ) {

        return result;
    }


    result =
        swr_init(
            decoder->swr_context
        );


    if (
        result < 0
    ) {

        return result;
    }


    decoder->source_sample_rate =
        sample_rate;


    decoder->source_sample_format =
        sample_format;


    decoder->source_channels =
        channels;


    decoder->output_sample_rate =
        sample_rate;


    return 0;
}


// MARK: - Convert Frame

static int
msru_convert_frame(
    MSRUFFmpegDecoder *decoder,
    AVFrame *frame
) {

    int result =
        msru_configure_resampler(
            decoder,
            frame
        );


    if (
        result < 0
    ) {

        return result;
    }


    int maximum_output_frames =
        swr_get_out_samples(
            decoder->swr_context,
            frame->nb_samples
        );


    if (
        maximum_output_frames <= 0
    ) {

        maximum_output_frames =
            frame->nb_samples
            + 64;
    }


    result =
        msru_ensure_pending_capacity(
            decoder,
            maximum_output_frames
        );


    if (
        result < 0
    ) {

        return result;
    }


    uint8_t *output_data[2] = {

        (uint8_t *)
            decoder
                ->pending_left,

        (uint8_t *)
            decoder
                ->pending_right
    };


    const uint8_t **input_data =
        (const uint8_t **)
            frame->extended_data;


    int converted_frames =
        swr_convert(
            decoder->swr_context,

            output_data,

            maximum_output_frames,

            input_data,

            frame->nb_samples
        );


    if (
        converted_frames < 0
    ) {

        return converted_frames;
    }


    decoder->pending_frames =
        converted_frames;


    decoder->pending_offset =
        0;


    return converted_frames;
}


// MARK: - Input

static int
msru_fill_input_buffer(
    MSRUFFmpegDecoder *decoder
) {

    if (
        decoder->reached_file_eof
    ) {

        return 0;
    }


    size_t bytes_read =
        fread(
            decoder->input_buffer,
            1,
            MSRU_INPUT_BUFFER_SIZE,
            decoder->file
        );


    if (
        bytes_read == 0
    ) {

        decoder->reached_file_eof =
            1;


        decoder->input_data =
            NULL;


        decoder->input_size =
            0;


        return 0;
    }


    memset(
        decoder
            ->input_buffer
            + bytes_read,

        0,

        AV_INPUT_BUFFER_PADDING_SIZE
    );


    decoder->input_data =
        decoder->input_buffer;


    decoder->input_size =
        (int) bytes_read;


    return 1;
}


// MARK: - Decoder Feed

static int
msru_send_next_packet(
    MSRUFFmpegDecoder *decoder
) {

    while (1) {

        if (
            decoder->input_size <= 0
            &&
            !decoder->reached_file_eof
        ) {

            msru_fill_input_buffer(
                decoder
            );
        }


        if (
            decoder->input_size > 0
        ) {

            uint8_t *packet_data =
                NULL;


            int packet_size =
                0;


            int consumed =
                av_parser_parse2(
                    decoder->parser,

                    decoder
                        ->codec_context,

                    &packet_data,

                    &packet_size,

                    decoder
                        ->input_data,

                    decoder
                        ->input_size,

                    AV_NOPTS_VALUE,

                    AV_NOPTS_VALUE,

                    0
                );


            if (
                consumed < 0
            ) {

                return consumed;
            }


            decoder->input_data +=
                consumed;


            decoder->input_size -=
                consumed;


            if (
                packet_size > 0
            ) {

                decoder->packet->data =
                    packet_data;


                decoder->packet->size =
                    packet_size;


                int result =
                    avcodec_send_packet(
                        decoder
                            ->codec_context,

                        decoder
                            ->packet
                    );


                decoder->packet->data =
                    NULL;


                decoder->packet->size =
                    0;


                if (
                    result == AVERROR(EAGAIN)
                ) {

                    return 1;
                }


                if (
                    result < 0
                ) {

                    return result;
                }


                return 1;
            }


            /*
             Parser consumed nothing and
             produced nothing.

             Avoid a possible infinite loop.
             */

            if (
                consumed == 0
            ) {

                return AVERROR_INVALIDDATA;
            }


            continue;
        }


        /*
         End of file.

         Flush decoder exactly once.
         */

        if (
            decoder->reached_file_eof
            &&
            !decoder->sent_decoder_flush
        ) {

            decoder->sent_decoder_flush =
                1;


            int result =
                avcodec_send_packet(
                    decoder
                        ->codec_context,

                    NULL
                );


            if (
                result == AVERROR_EOF
            ) {

                decoder->reached_decoder_eof =
                    1;


                return 0;
            }


            if (
                result < 0
                &&
                result != AVERROR(EAGAIN)
            ) {

                return result;
            }


            return 1;
        }


        decoder->reached_decoder_eof =
            1;


        return 0;
    }
}


// MARK: - Decode Next Frame

static int
msru_decode_next_frame(
    MSRUFFmpegDecoder *decoder
) {

    while (1) {

        int result =
            avcodec_receive_frame(
                decoder
                    ->codec_context,

                decoder
                    ->frame
            );


        if (
            result == 0
        ) {

            result =
                msru_convert_frame(
                    decoder,

                    decoder
                        ->frame
                );


            av_frame_unref(
                decoder
                    ->frame
            );


            if (
                result < 0
            ) {

                return result;
            }


            return 1;
        }


        if (
            result == AVERROR_EOF
        ) {

            decoder->reached_decoder_eof =
                1;


            return 0;
        }


        if (
            result != AVERROR(EAGAIN)
        ) {

            return result;
        }


        result =
            msru_send_next_packet(
                decoder
            );


        if (
            result < 0
        ) {

            return result;
        }


        if (
            result == 0
            &&
            decoder->reached_decoder_eof
        ) {

            return 0;
        }
    }
}


// MARK: - Reset

static void
msru_reset_decoder_state(
    MSRUFFmpegDecoder *decoder
) {

    decoder->input_data =
        NULL;


    decoder->input_size =
        0;


    decoder->reached_file_eof =
        0;


    decoder->sent_decoder_flush =
        0;


    decoder->reached_decoder_eof =
        0;


    decoder->pending_frames =
        0;


    decoder->pending_offset =
        0;


    avcodec_flush_buffers(
        decoder
            ->codec_context
    );


    if (
        decoder->parser != NULL
    ) {

        av_parser_close(
            decoder->parser
        );


        decoder->parser =
            NULL;
    }


    decoder->parser =
        av_parser_init(
            AV_CODEC_ID_DTS
        );


    if (
        decoder->swr_context != NULL
    ) {

        swr_free(
            &decoder->swr_context
        );
    }


    decoder->source_sample_rate =
        0;


    decoder->source_channels =
        0;


    decoder->source_sample_format =
        AV_SAMPLE_FMT_NONE;
}


// MARK: - Open

MSRUFFmpegDecoderRef
msru_ffmpeg_decoder_open(
    const char *path,
    MSRUFFmpegAudioInfo *info,
    char *error_buffer,
    int32_t error_buffer_size
) {

    if (
        path == NULL
    ) {

        msru_write_error(
            error_buffer,
            error_buffer_size,
            "Missing DTS file path."
        );


        return NULL;
    }


    FILE *file =
        fopen(
            path,
            "rb"
        );


    if (
        file == NULL
    ) {

        msru_write_error(
            error_buffer,
            error_buffer_size,
            "Unable to open DTS file."
        );


        return NULL;
    }


    if (
        fseeko(
            file,
            0,
            SEEK_END
        ) != 0
    ) {

        fclose(
            file
        );


        msru_write_error(
            error_buffer,
            error_buffer_size,
            "Unable to determine DTS file size."
        );


        return NULL;
    }


    int64_t file_size =
        (int64_t)
            ftello(
                file
            );


    rewind(
        file
    );


    const AVCodec *codec =
        avcodec_find_decoder(
            AV_CODEC_ID_DTS
        );


    if (
        codec == NULL
    ) {

        fclose(
            file
        );


        msru_write_error(
            error_buffer,
            error_buffer_size,
            "FFmpeg DTS/DCA decoder is unavailable."
        );


        return NULL;
    }


    MSRUFFmpegDecoder *decoder =
        calloc(
            1,
            sizeof(
                MSRUFFmpegDecoder
            )
        );


    if (
        decoder == NULL
    ) {

        fclose(
            file
        );


        msru_write_error(
            error_buffer,
            error_buffer_size,
            "Unable to allocate DTS decoder."
        );


        return NULL;
    }


    decoder->file =
        file;


    decoder->file_size =
        file_size;


    decoder->source_sample_format =
        AV_SAMPLE_FMT_NONE;


    decoder->parser =
        av_parser_init(
            AV_CODEC_ID_DTS
        );


    if (
        decoder->parser == NULL
    ) {

        msru_ffmpeg_decoder_close(
            decoder
        );


        msru_write_error(
            error_buffer,
            error_buffer_size,
            "FFmpeg DTS parser is unavailable."
        );


        return NULL;
    }


    decoder->codec_context =
        avcodec_alloc_context3(
            codec
        );


    if (
        decoder->codec_context == NULL
    ) {

        msru_ffmpeg_decoder_close(
            decoder
        );


        msru_write_error(
            error_buffer,
            error_buffer_size,
            "Unable to allocate DTS codec context."
        );


        return NULL;
    }


    int result =
        avcodec_open2(
            decoder
                ->codec_context,

            codec,

            NULL
        );


    if (
        result < 0
    ) {

        msru_ffmpeg_decoder_close(
            decoder
        );


        msru_write_ffmpeg_error(
            error_buffer,
            error_buffer_size,
            "Unable to open DTS decoder",
            result
        );


        return NULL;
    }


    decoder->packet =
        av_packet_alloc();


    decoder->frame =
        av_frame_alloc();


    if (
        decoder->packet == NULL
        ||
        decoder->frame == NULL
    ) {

        msru_ffmpeg_decoder_close(
            decoder
        );


        msru_write_error(
            error_buffer,
            error_buffer_size,
            "Unable to allocate DTS packet/frame."
        );


        return NULL;
    }


    /*
     Decode first frame immediately.

     This lets us discover:
     - sample rate
     - channel layout
     - bitrate

     The converted first frame remains
     in pending PCM and will still be
     returned to Swift.
     */

    result =
        msru_decode_next_frame(
            decoder
        );


    if (
        result <= 0
    ) {

        msru_ffmpeg_decoder_close(
            decoder
        );


        if (
            result < 0
        ) {

            msru_write_ffmpeg_error(
                error_buffer,
                error_buffer_size,
                "Unable to decode first DTS frame",
                result
            );

        } else {

            msru_write_error(
                error_buffer,
                error_buffer_size,
                "DTS file contains no decodable audio frames."
            );
        }


        return NULL;
    }


    decoder->bit_rate =
        decoder
            ->codec_context
            ->bit_rate;


    double duration =
        0;


    if (
        decoder->bit_rate > 0
        &&
        decoder->file_size > 0
    ) {

        duration =
            (
                (double)
                    decoder
                        ->file_size
                * 8.0
            )
            /
            (double)
                decoder
                    ->bit_rate;
    }


    if (
        info != NULL
    ) {

        info->sample_rate =
            decoder
                ->output_sample_rate;


        info->channels =
            2;


        info->duration_seconds =
            duration;


        info->bit_rate =
            decoder
                ->bit_rate;
    }


    return decoder;
}


// MARK: - Read

int32_t
msru_ffmpeg_decoder_read(
    MSRUFFmpegDecoderRef decoder_ref,
    float *left,
    float *right,
    int32_t capacity_frames,
    int32_t *output_frames,
    char *error_buffer,
    int32_t error_buffer_size
) {

    MSRUFFmpegDecoder *decoder =
        (MSRUFFmpegDecoder *)
            decoder_ref;


    if (
        decoder == NULL
        ||
        left == NULL
        ||
        right == NULL
        ||
        capacity_frames <= 0
    ) {

        msru_write_error(
            error_buffer,
            error_buffer_size,
            "Invalid DTS decoder read request."
        );


        return -1;
    }


    int written =
        0;


    while (
        written
        < capacity_frames
    ) {

        int available =
            decoder->pending_frames
            -
            decoder->pending_offset;


        if (
            available > 0
        ) {

            int remaining =
                capacity_frames
                - written;


            int copy_frames =
                available
                < remaining
                ? available
                : remaining;


            memcpy(
                left + written,

                decoder
                    ->pending_left
                    + decoder
                        ->pending_offset,

                sizeof(float)
                * (size_t)
                    copy_frames
            );


            memcpy(
                right + written,

                decoder
                    ->pending_right
                    + decoder
                        ->pending_offset,

                sizeof(float)
                * (size_t)
                    copy_frames
            );


            decoder->pending_offset +=
                copy_frames;


            written +=
                copy_frames;


            continue;
        }


        decoder->pending_frames =
            0;


        decoder->pending_offset =
            0;


        int result =
            msru_decode_next_frame(
                decoder
            );


        if (
            result == 0
        ) {

            break;
        }


        if (
            result < 0
        ) {

            msru_write_ffmpeg_error(
                error_buffer,
                error_buffer_size,
                "DTS decoding failed",
                result
            );


            return -1;
        }
    }


    if (
        output_frames != NULL
    ) {

        *output_frames =
            written;
    }


    if (
        written > 0
    ) {

        return 1;
    }


    return 0;
}


// MARK: - Seek

int32_t
msru_ffmpeg_decoder_seek(
    MSRUFFmpegDecoderRef decoder_ref,
    double seconds,
    char *error_buffer,
    int32_t error_buffer_size
) {

    MSRUFFmpegDecoder *decoder =
        (MSRUFFmpegDecoder *)
            decoder_ref;


    if (
        decoder == NULL
    ) {

        msru_write_error(
            error_buffer,
            error_buffer_size,
            "DTS decoder is unavailable."
        );


        return -1;
    }


    if (
        decoder->bit_rate <= 0
    ) {

        msru_write_error(
            error_buffer,
            error_buffer_size,
            "DTS stream bitrate is unknown; seeking is unavailable."
        );


        return -1;
    }


    if (
        seconds < 0
    ) {

        seconds =
            0;
    }


    double byte_position =
        seconds
        *
        (
            (double)
                decoder
                    ->bit_rate
            /
            8.0
        );


    if (
        byte_position
        >
        (double)
            decoder
                ->file_size
    ) {

        byte_position =
            (double)
                decoder
                    ->file_size;
    }


    /*
     Move slightly backwards.

     Raw DTS has sync words.
     Parser will locate the next
     complete DTS frame.
     */

    const int64_t safety_window =
        64 * 1024;


    int64_t target =
        (int64_t)
            byte_position;


    if (
        target
        > safety_window
    ) {

        target -=
            safety_window;

    } else {

        target =
            0;
    }


    if (
        fseeko(
            decoder->file,
            target,
            SEEK_SET
        ) != 0
    ) {

        msru_write_error(
            error_buffer,
            error_buffer_size,
            "Unable to seek DTS file."
        );


        return -1;
    }


    msru_reset_decoder_state(
        decoder
    );


    if (
        decoder->parser == NULL
    ) {

        msru_write_error(
            error_buffer,
            error_buffer_size,
            "Unable to recreate DTS parser after seeking."
        );


        return -1;
    }


    return 0;
}


// MARK: - Close

void
msru_ffmpeg_decoder_close(
    MSRUFFmpegDecoderRef decoder_ref
) {

    MSRUFFmpegDecoder *decoder =
        (MSRUFFmpegDecoder *)
            decoder_ref;


    if (
        decoder == NULL
    ) {

        return;
    }


    if (
        decoder->swr_context
        != NULL
    ) {

        swr_free(
            &decoder
                ->swr_context
        );
    }


    if (
        decoder->frame
        != NULL
    ) {

        av_frame_free(
            &decoder
                ->frame
        );
    }


    if (
        decoder->packet
        != NULL
    ) {

        av_packet_free(
            &decoder
                ->packet
        );
    }


    if (
        decoder->codec_context
        != NULL
    ) {

        avcodec_free_context(
            &decoder
                ->codec_context
        );
    }


    if (
        decoder->parser
        != NULL
    ) {

        av_parser_close(
            decoder
                ->parser
        );
    }


    if (
        decoder->file
        != NULL
    ) {

        fclose(
            decoder->file
        );
    }


    free(
        decoder->pending_left
    );


    free(
        decoder->pending_right
    );


    free(
        decoder
    );
}


// MARK: - Version

const char *
msru_ffmpeg_version(void) {

    return av_version_info();
}
