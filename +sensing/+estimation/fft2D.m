function estResults = fft2D(radarEstParams, cfar, rxGrid, txGrid)
%2D-FFT Algorithm for Range, Velocity and Angle Estimation.
%
% Input parameters:
%
% radarEstParams: structure containing radar system parameters 
% such as the number of IFFT/FFT points, range and velocity resolutions, and angle FFT size.
%
% cfarDetector: an object implementing the Constant False Alarm Rate (CFAR) detection algorithm.
%
% CUTIdx: index of the cells under test (CUT)
%
% rxGrid: M-by-N-by-P matrix representing the received signal 
% at P antenna elements from N samples over M chirp sequences.
%
% txGrid: M-by-N-by-P matrix representing the transmitted signal 
% at P antenna elements from N samples over M chirp sequences.
%
% txArray: phased array System object™ or a NR Rectangular Panel Array (URA) System object™
%
%
% Output parameters: 
%
% estResults containing the estimated range, velocity, and angle
% for each target detected. The function also includes functions to plot results.
%
% Author: D.S Xue, Key Laboratory of Universal Wireless Communications,
% Ministry of Education, BUPT.

    %% Input Parameters
    [nSc, nSym, nAnts] = size(rxGrid);
    nIFFT              = radarEstParams.nIFFT;
    nFFT               = radarEstParams.nFFT;

    % Angular grid
    aMax    = radarEstParams.scanScale;
    aziGrid = -aMax/2:aMax/2;

    % Range and Doppler grid
    rngGrid = ((0:nIFFT-1)*radarEstParams.rRes)';        % [0,nIFFT-1]*rRes
    dopGrid = ((-nFFT/2:nFFT/2-1)*radarEstParams.vRes)'; % [-nFFT/2,nFFT/2-1]*vRes

    % CFAR
    cfarDetector = cfar.cfarDetector2D;
    CUTIdx       = cfar.CUTIdx;
    if ~strcmp(cfarDetector.OutputFormat,'Detection index')
        cfarDetector.OutputFormat = 'Detection index';
    end

    %% Simulation params initialization
    % 3D-FFT parameters
    detections = cell(nAnts, 1);

    % Estimated results
    estResults = struct;
    rngEst     = cell(nAnts, 1);
    velEst     = cell(nAnts, 1);

    %% DoA estimation using beamscan method
    % Array parameters
    d = .5;  % Antenna array element spacing, normally set to 0.5

    % Array correlation matrix
    rxGridReshaped = reshape(rxGrid, nSc*nSym, nAnts)'; % [nAnts x nSc*nSym]
    Ra = rxGridReshaped*rxGridReshaped'./(nSc*nSym);    % [nAnts x nAnts]

    % Generare beamforming power spectrum
    Pbf  = zeros(1, aMax+1);
    for a = 1:aMax+1
        aa     = exp(-2j.*pi.*sind(a-aMax/2-1).*d.*(0:1:nAnts-1)).'; % angle steering vector, [1 x nAnts]
        Pbf(a) = aa'*Ra*aa;
    end
    
    % DoA estimation
    [~, aIdx] = max(abs(Pbf));
    aziEst = aIdx - aMax/2 -1;

    % Assignment
    estResults.aziEst = mean(aziEst);

    %% 2D-FFT Algorithm
    % Element-wise multiplication
    channelInfo = bsxfun(@times, rxGrid, pagectranspose(pagetranspose(txGrid)));  % [nSc x nSym x nAnts]

    % Select window
    [rngWin, dopWin] = selectWindow('kaiser');

    % Generate windowed RDM
    chlInfoWindowed = channelInfo.*rngWin;                                     % Apply window to the channel info matrix
    rngIFFT         = ifftshift(ifft(chlInfoWindowed, nIFFT, 1).*sqrt(nIFFT)); % IDFT per columns, [nIFFT x nSym x nAnts]
    rngIFFTWindowed = rngIFFT.*dopWin;                                         % Apply window to the ranging matrix
    rdm             = fftshift(fft(rngIFFTWindowed, nFFT, 2)./sqrt(nFFT));     % DFT per rows, [nIFFT x nFFT x nAnts]

    % Range and velocity estimation
    for r = 1:nAnts
        % CFAR detection
        detections{r} = cfarDetector(abs(rdm(:,:,r).^2), CUTIdx);
        nDetecions = size(detections{r}, 2);

        if ~isempty(detections{r})

            for i = 1:nDetecions

                % Detection indices
                rngIdx = detections{r}(1,i)-1;
                velIdx = detections{r}(2,i)-nFFT/2-1;

                % Range and velocity estimation
                rngEst{r} = rngIdx.*radarEstParams.rRes;
                velEst{r} = velIdx.*radarEstParams.vRes;

                % Range and Doppler estimation values
                % Remove outliers from estimation values
                rngEstFiltered = filterOutliers(cat(2, rngEst{:}));
                velEstFiltered = filterOutliers(cat(2, velEst{:}));
                % Assignment
                estResults(i).rngEst = mean(rngEstFiltered, 2);
                estResults(i).velEst = mean(velEstFiltered, 2);

            end

         end
    end

%     estResults = getUniqueStruct(estResults);

    %% Plot Results
    % plot 2D-RDM (1st Rx antenna array element)
    plotRDM(1)

    % Uncomment to plot 2D-FFT spectra
    plotFFTSpectra(1,1,1)

    %% Local functions
    function [rngWin, dopWin] = selectWindow(winType)
        % Windows for sidelobe suppression: 'hamming, hann, blackman, 
        % kaiser, taylorwin, chebwin, barthannwin, gausswin, tukeywin'
        switch winType
            case 'hamming'      % Hamming window
                rngWin = repmat(hamming(nSc), [1 nSym]);
                dopWin = repmat(hamming(nIFFT), [1 nSym]);
            case 'hann'         % Hanning window
                rngWin = repmat(hann(nSc), [1 nSym]);
                dopWin = repmat(hann(nIFFT), [1 nSym]);
            case 'blackman'     % Blackman window
                rngWin = repmat(blackman(nSc), [1 nSym]);
                dopWin = repmat(blackman(nIFFT), [1 nSym]);
            case 'kaiser'       % Kaiser window
                rngWin = repmat(kaiser(nSc, 3), [1 nSym]);
                dopWin = repmat(kaiser(nIFFT, 3), [1 nSym]);
            case 'taylorwin'    % Taylor window
                rngWin = repmat(taylorwin(nSc, 4, -30), [1 nSym]);
                dopWin = repmat(taylorwin(nIFFT, 4, -30), [1 nSym]);
            case 'chebwin'      % Chebyshev window
                rngWin = repmat(chebwin(nSc, 100), [1 nSym]);
                dopWin = repmat(chebwin(nIFFT, 100), [1 nSym]);
            case 'barthannwin'  % Modified Bartlett-Hann window
                rngWin = repmat(barthannwin(nSc), [1 nSym]);
                dopWin = repmat(barthannwin(nIFFT), [1 nSym]);
            case 'gausswin'     % Gaussian window
                rngWin = repmat(gausswin(nSc, 2.5), [1 nSym]);
                dopWin = repmat(gausswin(nIFFT, 2.5), [1 nSym]);
            case 'tukeywin'     % tukey (tapered cosine) window
                rngWin = repmat(tukeywin(nSc, .5), [1 nSym]);
                dopWin = repmat(tukeywin(nIFFT, .5), [1 nSym]);
            otherwise           % Default to Hamming window
                rngWin = repmat(hamming(nSc), [1 nSym]);
                dopWin = repmat(hamming(nIFFT), [1 nSym]);
        end
    end

    function uniqueStruct = getUniqueStruct(myStruct)
        % Delete duplicated elements in the struct

        [~, uniqueIndices] = unique(struct2table(myStruct), 'stable', 'rows');
        uniqueStruct = myStruct(uniqueIndices);

    end

    function filteredData = filterOutliers(data)
        % Calculate mean and standard deviation
        meanValue = mean(data);
        stdValue = std(data);
    
        % Define threshold: assume outliers are values beyond mean plus/minus 2 times the standard deviation
        threshold = 2 * stdValue;
    
        % Filter out outliers based on the threshold
        filteredData = data(abs(data - meanValue) <= threshold);
    end

    function plotRDM(aryIdx)
    % plot 2D range-Doppler(velocity) map
        figure('Name','2D RDM')

        h = imagesc(dopGrid, rngGrid, mag2db(abs(rdm(:,:,aryIdx))));
        h.Parent.YDir = 'normal';
        colorbar

        title('Range-Doppler Map')
        xlabel('Radial Velocity (m/s)')
        ylabel('Range (m)')

    end

    function plotFFTSpectra(fastTimeIdx, slowTimeIdx, aryIdx)
    % Plot 2D-FFT spectra (in dB)  
        figure('Name', '2D FFT Results')
     
        t = tiledlayout(3, 1, 'TileSpacing','compact');
        title(t, '2D-FFT Estimation')
        ylabel(t, 'FFT Spectra (dB)')

        % plot DoA spectrum 
        nexttile(1)
        aziFFTPlot = abs(Pbf);
        aziFFTNorm = aziFFTPlot./max(aziFFTPlot);
        aziFFTdB   = mag2db(aziFFTNorm);
        plot(aziGrid, aziFFTdB, 'LineWidth', 1);
        title('DoA Estimation (Beamscan)')
        xlabel('DoA (°)')
        xlim([-60 60])
        grid on

        
        % plot range spectrum 
        nexttile(2)
        rngIFFTPlot = abs(ifftshift(rngIFFT(:, slowTimeIdx, aryIdx)));
        rngIFFTNorm = rngIFFTPlot./max(rngIFFTPlot);
        rngIFFTdB   = mag2db(rngIFFTNorm);
        plot(rngGrid, rngIFFTdB, 'LineWidth', 1);
        title('Range Estimation')
        xlabel('Range (m)')
        xlim([0 500])
        grid on

        % plot Doppler/velocity spectrum 
        nexttile(3)    
        % DFT per rows, [nSc x nFFT x nAnts]
        velFFTPlot = abs(fftshift(fft(chlInfoWindowed(fastTimeIdx, :, aryIdx), nFFT, 2)./sqrt(nFFT)));
        velFFTNorm = velFFTPlot./max(velFFTPlot);
        velFFTdB   = mag2db(velFFTNorm);
        plot(dopGrid, velFFTdB, 'LineWidth', 1);
        title('Velocity(Doppler) Estimation')
        xlabel('Radial Velocity (m/s)')
        xlim([-50 50])
        grid on

    end
    
end
