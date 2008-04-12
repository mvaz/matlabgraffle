%% preamble
hasWaitBar      = false;
samplingRate    = 16000;
nbOfMicChannels = 1;
blockLength     = 1000;


%% initialization of H_GetCochlea
numberOfChannels = 100;
minFrequency  = 20;
maxFrequency = 8000;
minPitch           = 80;
maxPitch          = 500;
H_GetCochlea = GetCochlea(samplingRate, numberOfChannels, minFrequency, maxFrequency );

%% initialization of H_GetEnvelope
load cochleaCorrectionCoefficients;
cochleaCoefficients = repmat( coefficients', 1, blockLength );

envelopeFilterOrder = 5;
H_GetEnvelope  = GetEnvelope( H_GetCochlea, maxPitch, envelopeFilterOrder );

%% initialization of H_ApplySignalFilter
cutOffFrequency = 30;
H_ApplySignalFilter = ApplySignalFilter( cutOffFrequency, samplingRate, numberOfChannels, envelopeFilterOrder, 'low' );

%% initialization of Sync1
latency1 = get( H_GetCochlea, 'latency') + get(H_GetEnvelope,'latency') + get(H_ApplySignalFilter,'latency');

Sync1 = SynchronizeInputs( latency1 );

%% initialization of H_FilterOverChannels
fwidth = 40;
% filterType = 'gauss';
filterType = 'laplace';
H_FilterOverChannels = FilterOverChannels( H_GetCochlea, filterType, fwidth, fwidth);

%% initialization of H_DetectSpeechActivity
speechActivityGain      = 50;
speechActivityThreshold = 0.01;
H_DetectSpeechActivity = DetectSpeechActivity( speechActivityGain, speechActivityThreshold, max(500,ceil(log(2)/speechActivityThreshold)), 50, 0 );

%% initialization of H_DetectFrication
fricationGain = 20;
fricationThreshold = 0.02;
slope1 = max( 1000, ceil(log(2)/fricationThreshold) );
slope2 = 0;
H_DetectFrication = DetectFrication( H_GetCochlea, 750, 2500, fricationGain, fricationThreshold, slope1, slope2 );
display('initialization finished')


%% initialization of H_ReadFromFile
fileList = fullfile( getpref('ALISCORP','path'), 'miguel', 'bluebot-02' );
H_ReadFromFile = ReadFromFile( fileList, '', '.wav', blockLength, zeros(1,900));

H_ReadFromFileHasJuice = @(x) ~get( x, 'isEndOfList' );
display('initialization of sources finished')
% the loop
while H_ReadFromFileHasJuice(H_ReadFromFile)
    
    [ H_ReadFromFile signalBlock] = compute(H_ReadFromFile);
    
    [ H_GetCochlea basilarBlock] = compute(H_GetCochlea, signalBlock);
    basilarBlock  = basilarBlock .* cochleaCoefficients(:,1:size(basilarBlock,2));
    
    [ H_GetEnvelope envelopeBlock] = compute(H_GetEnvelope, basilarBlock);
    accumulate(envelopeBlock, 'Acc');
    
    [ H_ApplySignalFilter envelopeEnvelopBlock] = compute(H_ApplySignalFilter, envelopeBlock);
    
    [ Sync1 envelopeEnvelopBlock] = compute(Sync1, envelopeEnvelopBlock);
    
    [ H_FilterOverChannels formantBlock] = compute(H_FilterOverChannels, envelopeEnvelopBlock);
    formantBlock = max( 0, formantBlock );
    
    [speechActivityBlock] = feval( @(x) mean(x), formantBlock);
    
    [ H_DetectSpeechActivity speechActivityBlock] = compute(H_DetectSpeechActivity, speechActivityBlock);
    
    [ H_DetectFrication fricMaskBlock discard] = compute(H_DetectFrication, envelopeEnvelopBlock, speechActivityBlock);
end

display('done')
