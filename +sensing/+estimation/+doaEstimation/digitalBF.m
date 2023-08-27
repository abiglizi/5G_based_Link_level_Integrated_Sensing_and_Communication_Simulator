function [aziEst, eleEst] = digitalBF(radarEstParams, Ra)
%DIGITALBF Digital beamformer (DBF) /beamscan for DoA estimation
%
%  Author: D.S Xue, Key Laboratory of Universal Wireless Communications,
% Ministry of Education, BUPT.

    % Antenna array    
    array = radarEstParams.antennaType;
    d = .5;  % the ratio of element spacing to wavelength, normally set to 0.5

    % Threshhold for peak finding
    thresh = npwgnthresh(radarEstParams.Pfa);

    if isa(array, 'phased.NRRectangularPanelArray') % UPA model

        % Array parameters
        nAntsX       = array.Size(1);                           % number of X-axis elements
        nAntsY       = array.Size(2);                           % number of Y-axis elements
        aGranularity = radarEstParams.azimuthScanGranularity;   % azimuth scan granularity, in degree
        eGranularity = radarEstParams.elevationScanGranularity; % elevation scan granularity, in degree
        aMax         = radarEstParams.azimuthScanScale;         % azimuth scan scale, in degree
        eMax         = radarEstParams.elevationScanScale;       % elevation scan scale, in degree
        aSteps       = floor((aMax+1)/aGranularity);            % azimuth scan steps
        eSteps       = floor((eMax+1)/eGranularity);            % elevation scan steps
        
        % UPA steering vector
        aUPA = @(ph, th, m, n)exp(-2j*pi*sind(th)*(m*d*cosd(ph) + n*d*sind(ph)));
        mm = 0:1:nAntsX-1;
        nn = (0:1:nAntsY-1)';
    
        % Digital beamforming method  
        Pdbf = zeros(eSteps, aSteps);
        for e = 1:eSteps
            for a = 1:aSteps
                scanElevation = (e-1)*eGranularity - eMax/2;
                scanAzimuth   = (a-1)*aGranularity - aMax/2;
                aa = aUPA(scanAzimuth, scanElevation, mm, nn);
                aa = reshape(aa, nAntsX*nAntsY, 1);
                Pdbf(e,a) = aa'*Ra*aa;
            end
        end
        
        % Normalization
        Pdbf     = -abs(Pdbf);
        PdbfNorm = Pdbf./max(Pdbf);
        PdbfdB   = mag2db(PdbfNorm);

        % Plot
        plot2DAngularSpectrum

        % Assignment
        [~, idx] = findpeaks(PdbfdB(:), 'Threshold', thresh, 'SortStr', 'ascend');
        [ele, azi] = ind2sub(size(PdbfdB), idx);
        eleEst = (ele-1)*eGranularity-eMax/2;
        aziEst = (azi-1)*aGranularity-aMax/2;

    else % ULA model

        % Array parameters
        nAnts           = array.NumElements;                      % number of antenna elements
        scanGranularity = radarEstParams.azimuthScanGranularity;  % beam scan granularity, in degree
        aMax            = radarEstParams.azimuthScanScale;        % beam scan scale, in degree
        aSteps          = floor((aMax+1)/scanGranularity);        % beam scan steps

        % ULA steering vector
        aULA = @(ph, m)exp(-2j*pi*m*d*sind(ph));
        nn = (0:1:nAnts-1)';
    
        % Digital beamforming method  
        Pdbf = zeros(1, aSteps);
        for a = 1:aSteps
            scanAngle = (a-1)*scanGranularity - aMax/2;
            aa        = aULA(scanAngle, nn);
            Pdbf(a)   = aa'*Ra*aa;
        end
        
        % Normalization
        Pdbf     = abs(Pdbf);
        PdbfNorm = Pdbf./max(Pdbf);
        PdbfdB   = mag2db(PdbfNorm);

        % Plot
        plotAngularSpectrum
        
        % DoA estimation
        [~, aIdx] = findpeaks(PdbfdB, 'Threshold', thresh, 'SortStr', 'ascend');
        aziEst = (aIdx-1)*scanGranularity - aMax/2;

    end

    %% Local Functions
    function plot2DAngularSpectrum()
    % Plot 2D angular spectrum (in dB)  
        figure('Name', '2D Angular Spectrum')

        % Angular grid for plotting
        aziGrid = linspace(-aMax/2, aMax/2, aSteps); % [-aMax/2, aMax/2]
        eleGrid = linspace(-eMax/2, eMax/2, eSteps); % [-eMax/2, eMax/2]

        % plot DoA spectrum 
        imagesc(aziGrid, eleGrid, PdbfdB)

        title('DoA Estimation using Digital Beamforming Method')
        ylabel('Elevation (°)')
        xlabel('Azimuth (°)')
        ylim([-eMax/2 eMax/2])
        xlim([-aMax/2 aMax/2])
        grid on

    end

    function plotAngularSpectrum()
    % Plot angular spectrum (in dB)  
        figure('Name', 'Angular Spectrum')

        % Angular grid for plotting
        aziGrid = linspace(-aMax/2, aMax/2, aSteps); % [-aMax/2, aMax/2]

        % plot DoA spectrum 
        plot(aziGrid, PdbfdB, 'LineWidth', 1)

        title('DoA Estimation using Digital Beamforming Method')
        ylabel('Angular Spectrum (dB)')
        xlabel('Azimuth (°)')
        xlim([-aMax/2 aMax/2])
        grid on

    end

end

