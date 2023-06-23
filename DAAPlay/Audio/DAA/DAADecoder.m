/// Copyright (c) 2023, Dolby Laboratories Inc.
/// All rights reserved.
///
/// Redistribution and use in source and binary forms, with or without modification, are permitted
/// provided that the following conditions are met:
///
/// 1. Redistributions of source code must retain the above copyright notice, this list of conditions
///    and the following disclaimer.
/// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions
///    and the following disclaimer in the documentation and/or other materials provided with the distribution.
/// 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or
///    promote products derived from this software without specific prior written permission.
///
/// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
/// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
/// PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
/// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
/// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
/// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
/// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
/// OF THE POSSIBILITY OF SUCH DAMAGE.

#import <CoreMotion/CoreMotion.h>

#import "DAADecoder.h"
#import <os/log.h>

#define SAMPLE_RATE           (48000)
#define AC4_SAMPLES_PER_FRAME (2048)
#define AC4_SAMPLES_PER_BLOCK (256)
#define ESTIMATED_LATENCY     (3168)
#define NUM_CHANNELS          (DLB_DECODE_PCMOUT_CHANNELS)

@interface DAADecoder()

@property dlb_buffer outputDlbBuffer;
@property (nonatomic, assign) void *decoder;
@property (nonatomic, assign) int sampleRate;
@property unsigned long timescale;
@property size_t maxOutputBufferSize;
@property int packetCounter;
@property AVAudioFormat *format;
@property (nonatomic) AVAudioPCMBuffer *audioOutputBuffer;
@property int16_t *pcmOutputBuffer;
@property int numSamplesBuffered;

@end

@implementation DAADecoder

- (void)createDecoderFor:(DAADecoderType)type isHeadphone:(bool)isHeadphone isVirtualized:(bool) isVirtualized {
  int err;
  dlb_decode_query_ip queryIp;
  dlb_decode_query_info_op queryOp;
  dlb_decode_query_mem_op queryMemOp;
  char *decoderMemory;
  int parameterValue;
  
  _timescale = SAMPLE_RATE;
  _packetCounter = 0;
  _numSamplesBuffered = 0;
  
  /* Nullify pointers */
  _pcmOutputBuffer = NULL;
  _outputDlbBuffer.ppdata = NULL;
  _decoder = NULL;
  
  /* Initialize DAA DDP configuration based on stream type */
  memset(&queryIp, 0, sizeof(queryIp));
  memset(&queryOp, 0, sizeof(queryOp));
  memset(&queryMemOp, 0, sizeof(queryMemOp));
  
  switch (type) {
    case DAADecoderAC4Simple:
      queryIp.input_bitstream_format = DLB_DECODE_INPUT_FORMAT_AC4;
      queryIp.input_bitstream_type = DLB_DECODE_INPUT_TYPE_AC4_SIMPLE_TRANSPORT;
      break;
    case DAADecoderAC4Raw:
      queryIp.input_bitstream_format = DLB_DECODE_INPUT_FORMAT_AC4;
      queryIp.input_bitstream_type = DLB_DECODE_INPUT_TYPE_AC4_RAW_FRAME;
      break;
    case DAADecoderDDP:
      queryIp.input_bitstream_format = DLB_DECODE_INPUT_FORMAT_DDP;
      queryIp.input_bitstream_type = DLB_DECODE_INPUT_TYPE_UNDEFINED;
      break;
  }
  
  queryIp.output_datatype = DLB_BUFFER_SHORT_16;
  queryIp.timescale = _timescale;
  
  err = dlb_decode_query_info(&queryIp, &queryOp);
  if (err != DLB_DECODE_ERR_NO_ERROR) {
    NSLog(@" Failed to query decoder information");
    return;
  }
  
  _daaVersion = [NSString stringWithUTF8String:queryOp.daa_version];
  _daaAPIVersion = [NSString stringWithUTF8String:queryOp.daa_api_version];
  _coreDecoderVersion = [NSString stringWithUTF8String:queryOp.core_decoder_version];
  
  err = dlb_decode_query_memory(&queryIp, &queryMemOp);
  if (err != DLB_DECODE_ERR_NO_ERROR) {
    NSLog(@"Failed to query decoder memory");
    return;
  }
  
  /* Allocate memory for decoder */
  decoderMemory = (char *) calloc(1, queryMemOp.decoder_size);
  if (decoderMemory == NULL) {
    NSLog(@"Failed to allocate decoder memory");
    [self end];
    return;
  }
  _decoder = (void *) ((long) (decoderMemory));
  
  err = dlb_decode_open(&queryIp, _decoder);
  if (err != DLB_DECODE_ERR_NO_ERROR) {
    NSLog(@"Failed to open DAA-DDP decoder");
    [self end];
    return;
  }
  
  /* Initialise dlb_buffer for output buffer */
  _outputDlbBuffer.ppdata = (void **) calloc(1, sizeof(void *) * NUM_CHANNELS);
  if (_outputDlbBuffer.ppdata == NULL) {
    NSLog(@"Failed to allocate memory for dlbBuffer");
    [self end];
    return;
  }
  memset(_outputDlbBuffer.ppdata, 0, sizeof(void *) * NUM_CHANNELS);
  
  /* Initialize the PCM output buffer */
  _maxOutputBufferSize = queryMemOp.output_buffer_size;
  _pcmOutputBuffer = (int16_t *) calloc(_maxOutputBufferSize, sizeof(int16_t));
  
  /* Initialize the AVAudioFormat */
  _format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16
                                             sampleRate:SAMPLE_RATE
                                               channels:NUM_CHANNELS
                                            interleaved:true];
  
  /* Initialize the AVAudioBuffer */
  _audioOutputBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:_format frameCapacity:AC4_SAMPLES_PER_BLOCK];
  
  /* Reset all decoder parameters */
  [self setHeadphoneEndpoint:isHeadphone];
  [self setVirtualizer:isVirtualized];
  
  parameterValue = 0;
  dlb_decode_setparam(_decoder, DLB_DECODE_CTL_DIALOG_ENHANCEMENT_ID, &parameterValue, sizeof(parameterValue));
  
  parameterValue = -16;
  dlb_decode_setparam(_decoder, DLB_DECODE_CTL_OUTPUT_REFERENCE_LEVEL_ID, &parameterValue, sizeof(parameterValue));
  
  parameterValue = DLB_DECODE_PRESENTATION_DEFAULT;
  dlb_decode_setparam(_decoder, DLB_DECODE_CTL_PRESENTATION_ID, &parameterValue, sizeof(parameterValue));
  
  parameterValue = DLB_DECODE_MAIN_ASSO_PREF_DEFAULT;
  dlb_decode_setparam(_decoder, DLB_DECODE_CTL_MAIN_ASSO_PREF_ID, &parameterValue, sizeof(parameterValue));
  
  // Reset time and latency tracking
  // Note that the latency is only known once the decoder has started. ESTIMATED_LATENCY is
  // truly a best guess estimate
  _timeInSamples = 0;
  _latencyInSamples = ESTIMATED_LATENCY;
  _startUpSamples = ESTIMATED_LATENCY;
  
  //NSLog(@"DaaDdpDecoder::open exit");
}

- (void)setHeadphoneEndpoint:(bool)isHeadphone {
  dlb_decode_endpoint value = DLB_DECODE_ENDP_STEREO_SPEAKER;
  if (isHeadphone) {
    value = DLB_DECODE_ENDP_STEREO_HEADPHONE;
  }
  dlb_decode_setparam(_decoder, DLB_DECODE_CTL_ENDPOINT_ID, &value, sizeof(value));
}

- (void)setVirtualizer:(bool)enable {
  dlb_decode_virtualizer_onoff value = DLB_DECODE_VIRTUALIZER_OFF;
  if (enable) {
    value = DLB_DECODE_VIRTUALIZER_ON;
  }
  dlb_decode_setparam(_decoder, DLB_DECODE_CTL_VIRTUALIZER_ID, &value, sizeof(value));
}

- (void)end {
  if (_pcmOutputBuffer != NULL) {
    free(_pcmOutputBuffer);
    _pcmOutputBuffer = NULL;
  }
  
  if (_outputDlbBuffer.ppdata != NULL) {
    free(_outputDlbBuffer.ppdata);
    _outputDlbBuffer.ppdata = NULL;
  }
  
  if (_decoder != NULL) {
    dlb_decode_close(_decoder);
    free(_decoder);
    _decoder = NULL;
  }
}

- (bool)isReadyToDecode {
  return _numSamplesBuffered == 0;
}

- (bool)decode:(NSData *)data timestamp:(NSInteger)timestamp {
  unsigned int bytesConsumed = 0;
  dlb_decode_io_params ioParams = {0};
  
  if (_numSamplesBuffered != 0) {
    NSLog(@"Not ready to decode frame. Keep calling nextBlock()");
    return false;
  }
  
  memset(_pcmOutputBuffer, 0, _maxOutputBufferSize * sizeof(int16_t));
  _outputDlbBuffer.ppdata[0] = &_pcmOutputBuffer[0];
  _outputDlbBuffer.ppdata[1] = &_pcmOutputBuffer[1];
  ioParams.pcm_output_buf = &_outputDlbBuffer;
  int timesliceCompleted = 0;
  
  /* Add bytes to the decoder */
  int err = dlb_decode_addbytes(_decoder, [data bytes], (uint)[data length], _timeInSamples, &bytesConsumed, &timesliceCompleted);
  // NSLog(@"Data add: %i, consumed: %i", (uint)[data length], bytesConsumed);
  
  if (err != DLB_DECODE_ERR_NO_ERROR) {
    NSLog(@"dlb_decode_addbytes failed %d.", err);
    return false;
  }
  
  if (!timesliceCompleted) {
    NSLog(@"Incomplete frame.");
    return false;
  }
  
  /* Decode */
  err = dlb_decode_process(_decoder, &ioParams);
    
  if (err != DLB_DECODE_ERR_NO_ERROR) {
    NSLog(@"dlb_decode_process failed %d.", err);
    return false;
  }
  
  if (ioParams.output_samples_num != AC4_SAMPLES_PER_FRAME) {
    NSLog(@"The DAA decoder returned an unexpected number of samples: %d ", ioParams.output_samples_num);
    return false;
  }
  
  // Update time and latency tracking
  _latencyInSamples = _timeInSamples - ioParams.output_timestamp;
  _timeInSamples += (uint)[data length];
  _numSamplesBuffered += ioParams.output_samples_num;
  
  return true;
}

- (DAADecodedBlock * _Nullable)nextBlock {
  if (_numSamplesBuffered == 0) {
    return nil;
  }
  
  // The decode() function saves PCM in a 2048 buffer. Consecutive calls to nextBlock()
  // will process 256 blocks at a time.
  //
  // offsetToCurrentBlock indexes into the 2048 buffer, to reference the correct block
  int offsetToCurrentBlock = AC4_SAMPLES_PER_FRAME - _numSamplesBuffered;
  
  // Consume "start-up samples"
  if (_startUpSamples > 0) {
    long long samplesToCopy = AC4_SAMPLES_PER_BLOCK - _startUpSamples;

    if (samplesToCopy <= 0) {
      // Empty frame: Consume all the samples and output a zero block
      _audioOutputBuffer.frameLength = 0;
      _startUpSamples -= AC4_SAMPLES_PER_BLOCK;
      
    } else {
      // Partial block: Consume the first _startUpSamples samples and output the rest
      _audioOutputBuffer.frameLength = (unsigned int) samplesToCopy;
      memcpy(_audioOutputBuffer.audioBufferList->mBuffers[0].mData,
             &_outputDlbBuffer.ppdata[0][(_startUpSamples + offsetToCurrentBlock) * NUM_CHANNELS * sizeof(int16_t)],
             samplesToCopy * NUM_CHANNELS * sizeof(int16_t)
             );
      _startUpSamples = 0;
    }
    
  } else {
    // Output a regular block (AC4_SAMPLES_PER_BLOCK samples)
    _audioOutputBuffer.frameLength = AC4_SAMPLES_PER_BLOCK;
    memcpy(_audioOutputBuffer.audioBufferList->mBuffers[0].mData,
           &_outputDlbBuffer.ppdata[0][offsetToCurrentBlock * NUM_CHANNELS * sizeof(int16_t)],
           AC4_SAMPLES_PER_BLOCK * NUM_CHANNELS * sizeof(int16_t)
           );
  }
  
  _numSamplesBuffered -= AC4_SAMPLES_PER_BLOCK;
  
  /* Configure the output */
  DAADecodedBlock *op = [DAADecodedBlock new];
  op.buffer = _audioOutputBuffer;
  op.packetNumber = ++self.packetCounter;
  return op;
  
}

@end

@implementation DAADecodedBlock

@end
