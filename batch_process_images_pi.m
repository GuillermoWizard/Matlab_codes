

function batch_process_images_pi(directory_path)
    % Function to batch process PNG images in a specified directory
    % directory_path: path to the directory containing the images

    % Get a list of all PNG files in the directory
    image_files = dir(fullfile(directory_path, '*.png'));
    num_files = length(image_files);

    fprintf('Found %d PNG files in %s\n', num_files, directory_path);

    % Loop over each image file
    for idx = 1:num_files
        % Get the filename
        FILENAME = fullfile(directory_path, image_files(idx).name);
        fprintf('Processing image %d of %d: %s\n', idx, num_files, FILENAME);

        % Call the image processing function
        num_cells = process_image(FILENAME);

        % Display the total number of cells detected
        fprintf('Total number of cells detected in %s: %d\n', image_files(idx).name, num_cells);

        % Wait for user input before proceeding to the next image
        fprintf('Press any key to continue to the next image...\n');
        pause; % Waits for the user to press a key

        % Alternatively, use input to prompt the user
        % input('Press Enter to continue to the next image...','s');
    end
end


function num_cells = process_image(FILENAME)
    % Function to process a single image and return the number of cells detected
    % FILENAME: full path to the image file

    %% LOAD IMAGE AND APPLY CHANNEL CONVERSION
    I = imread(FILENAME);

    % Keep red channel
    I_cell = I(:,:,1);  % Red Channel is channel 1

    % Enhance contrast using adaptive histogram equalization
    I_enhanced = adapthisteq(I_cell);

    % Reduce noise with a median filter
    I_filtered = medfilt2(I_enhanced, [3 3]);

    %% BRIGHT THRESHOLDING
    % Apply adaptive thresholding
    bw = imbinarize(I_filtered, 'adaptive', 'ForegroundPolarity', 'bright', 'Sensitivity', 0.000001);

    % Remove small objects (noise)
    min_cell_area = 600;  % Adjust based on expected cell size
    bw_cleaned = bwareaopen(bw, min_cell_area);

    % Fill holes inside cells
    bw_filled = imfill(bw_cleaned, 'holes');

    % Smooth the cell edges
    se = strel('disk', 5);  % Adjust the size for smoothing
    bw_smooth = imclose(bw_filled, se);
    bw_smooth = imopen(bw_smooth, se);

    %% SEGMENTATION
    % Compute the distance transform
    D = -bwdist(~bw_smooth);

    % Suppress minima to prevent over-segmentation
    mask = imextendedmin(D, 4);  % Adjust the H-minima transform height
    D2 = imimposemin(D, mask);

    % Apply the watershed transform
    L = watershed(D2);

    % Create a binary image where the watershed lines are set to 0
    bw_separated = bw_smooth;
    bw_separated(L == 0) = 0;

    %% COUNT
    % Label connected components
    [L_cells, num_cells] = bwlabel(bw_separated);

    %% OVERLAY ON THE ORIGINAL
    % Overlay boundaries on the original image without displaying it
    figure_handle = figure('Visible', 'off');
    imshow(I), hold on
    visboundaries(bw_separated, 'Color', 'r', 'LineWidth', 0.5);
    title(['Detected Cells: ', num2str(num_cells)]);
    hold off

    %% SAVE THE IMAGE
    % Extract the directory, filename, and extension of the input image
    [input_dir, input_name, ext] = fileparts(FILENAME);
    output_name = [input_name, '_COUNTED', '.png'];
    output_path = fullfile(input_dir, output_name);

    % Save the figure as an image (using print for higher quality)
    print(figure_handle, output_path, '-dpng', '-r300');

    % Close the figure to free up resources
    close(figure_handle);
end
