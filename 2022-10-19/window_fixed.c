/*
    gcc ./window_fixed.c -o window_fixed -lm -lfftw3
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <math.h>

#include <fftw3.h>

#define REAL 0
#define IMAG 1


/*
    ./window_fixed -Wall <frequency sampling> <frequency limit>  <window size> <window step> <raw pcm s16le samples file>
*/
int main(int argc, char** argv)
{
    FILE* f;
    struct stat st;
    int window_size, window_offset, window_limit, samples_count, window_step;
    double freq_src, freq_limit, freq_step;
    fftw_plan fft_plan;
    fftw_complex *fft_in, *fft_out;
    int16_t *samples_buffer;

    if(argc != 6)
    {
        fprintf(stderr, "Error! Not enough arguments!\n");
        fprintf(stderr, "Usage:\n");
        fprintf(stderr, "    %s <frequency sampling> <frequency limit>  <window size> <window step> <raw pcm s16le samples file>\n", argv[0]);
        return 1;
    };

    freq_src = atof(argv[1]);
    freq_limit = atof(argv[2]);
    window_size = atof(argv[3]);
    window_step = atof(argv[4]);

    /* lets open file */
    f = fopen(argv[5], "rb");
    if(!f)
    {
        fprintf(stderr, "Error! Failed to open file [%s]\n", argv[5]);
        return 1;
    };

    /* read file to mem */
    stat(argv[5], &st);
    samples_count = st.st_size / sizeof(int16_t);
    samples_buffer = malloc(st.st_size);
    fread(samples_buffer, sizeof(int16_t), samples_count, f);

    /* close */
    fclose(f);

    fprintf(stderr, "File [%s] has %d samples\n", argv[5], samples_count);

    /* allocate ffts buffer */
    fft_in = (fftw_complex*) fftw_malloc(sizeof(fftw_complex) * window_size);
    fft_out = (fftw_complex*) fftw_malloc(sizeof(fftw_complex) * window_size);

    /* init fft plan */
    fft_plan = fftw_plan_dft_1d(window_size, fft_in, fft_out, FFTW_FORWARD, FFTW_ESTIMATE);

    freq_step = freq_src / window_size;
    window_limit = fmin(freq_limit / freq_step, window_size / 2);

    /* do some calc */
    for(window_offset = 0;;)
    {
        int i;

        fprintf(stderr, "window_offset=%d\n", window_offset);

        for(i = 0; i < window_size && i < (samples_count - window_offset); i++)
        {
            fft_in[i][REAL] = (double)samples_buffer[i] / 32768.0;
            fft_in[i][IMAG] = 0;
        };

        if(i < window_size)
            break;

        fftw_execute(fft_plan);

        for(i = 0; i < window_limit; i++)
        {
            double mag = sqrt(fft_out[i][REAL] * fft_out[i][REAL] +
                fft_out[i][IMAG] * fft_out[i][IMAG]);

            printf("%f\t%f\n", i * freq_step, mag);
//            printf("%f\t%f\t%f\n", window_offset / freq_src, i * freq_step, mag);
        };

        window_offset += window_step;

        fprintf(stderr, "done\n");

        exit(0);
    };

    /* free ffts buffer */
    fftw_free(fft_in);
    fftw_free(fft_out);
    fftw_destroy_plan(fft_plan);

    /* free samples */
    free(samples_buffer);

    return 0;
}

