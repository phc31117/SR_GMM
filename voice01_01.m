clear all;

[y, fs] = audioread('05_03.wav');

framesize_time = 32;
framesize = framesize_time * fs / 1000;
shiftsize_time = 16;
shiftsize = shiftsize_time * fs / 1000;
original_matrix = buffer(y, framesize, (framesize - shiftsize), 'nodelay');

[num_of_samples, num_of_frames] = size(original_matrix);

hamming_window = hamming(num_of_samples);

for i = 1:num_of_frames
    hamming_matrix(:, i) = original_matrix(:, i) .* hamming_window;
end


%%  Energy
energy = sum((hamming_matrix .^ 2));
energy = mean(abs(hamming_matrix));
silence_time = 2000;
num_of_silence_frames = ceil((fs / 1000 * silence_time - framesize) / shiftsize) + 1;
energy_threshold = mean(energy(1:num_of_silence_frames)) + std(energy(1:num_of_silence_frames));


%% Zero Crossing Rate
for i = 1:num_of_frames
	hamming_matrix_ZCR(:, i) = hamming_matrix(:, i) - mean(hamming_matrix(:, i));	% mean justification
end
ZCR = sum(hamming_matrix_ZCR(1:(end - 1), :) .* hamming_matrix_ZCR(2:end, :) < 0);

lower_pitch = 60;
higher_pitch = 200;


%% Pitch
for i = 1:num_of_frames
    if energy(i) <= energy_threshold
        original_pitch(i) = 0;
        hamming_pitch(i) = 0;
    else
        temp = xcorr(original_matrix(:, i));
        original_acf(:, i) = temp((end / 2):end);
        original_acf_mv(:, i) = movmean(original_acf(:, i), 5);
        [pks, locs] = findpeaks(original_acf_mv((fs / higher_pitch):end, i), 'MinPeakDistance', fs / higher_pitch);
        [val, ind] = max(pks);
        if isempty(val)
            original_pitch(i) = 0;
        else
            original_period(i) = locs(ind) + (fs / higher_pitch) - 1;
            original_period_val(i) = val;
            original_pitch(i) = fs / original_period(i);
            if original_pitch(i) < lower_pitch || original_pitch(i) > higher_pitch
                original_pitch(i) = 0;
            end
        end

        temp = xcorr(hamming_matrix(:, i));
        hamming_acf(:, i) = temp((end / 2):end);
        hamming_acf_mv(:, i) = movmean(hamming_acf(:, i), 5);
        [pks, locs] = findpeaks(hamming_acf_mv((fs / higher_pitch):end, i), 'MinPeakDistance', fs / higher_pitch);
        [val, ind] = max(pks);
        if isempty(val)
            hamming_pitch(i) = 0;
        else
            hamming_period(i) = locs(ind) + (fs / higher_pitch) - 1;
            hamming_period_val(i) = val;
            hamming_pitch(i) = fs / hamming_period(i);
            if hamming_pitch(i) < lower_pitch || hamming_pitch(i) > higher_pitch
                hamming_pitch(i) = 0;
            end
        end
    end
end


%% End point detection
IMX = max(energy(1:num_of_silence_frames));
IMN = min(energy(1:num_of_silence_frames));
I1 = 0.03 * (IMX - IMN) + IMN;
I2 = 4 * IMX;
ITL = 7*min(I1, I2);
ITU = 5*ITL;
IZCT = sum(ZCR(1:num_of_silence_frames) / length(ZCR(1:num_of_silence_frames)));

i = 1;
begin_flag = false;
begin_ind = 0;
flag = false;
while i < num_of_frames
    if ~begin_flag
        if energy(i) > ITL
            begin_ind = i;
            begin_flag = true;
        end
    else
        if energy(i) < ITL
            begin_flag = false;
        elseif energy(i) > ITU
            flag = true;
        end
    end
    if flag
        break;
    end
    i = i + 1;
end

end_ind = num_of_frames;
while i < num_of_frames
    if energy(i) < ITL
        end_ind = i;
        break;
    end
    i = i + 1;
end


%% Plot
figure(1)
plot((1:length(y)) / shiftsize, y);
title('Waveform');
xlabel('Frame');
ylabel('Amplitude');
axis ([-inf inf -max(abs(y)) max(abs(y))]);
print('-djpeg', '-f1', '-r300', '05-03');

