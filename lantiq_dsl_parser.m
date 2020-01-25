function [ current_dsl_struct ] = lantiq_dsl_parser( input_args )
%LANTIQ_DSL_PARSER Summary of this function goes here
%   Detailed explanation goes here

% TODO:
%	scale the x_vecs correctly, by evaluating nGroupSize (WIP)
%		still needs for for the fixed 512 value sets
%	add textual summary and error statistics page
%	find G.INP RTX counter?
%	separate data acquisition and plotting WIP
%	save out plots and data WIP
%	allow to read from precanned text captures of dsl_cmd output
%	collect statistics over collected per bin data (min, max, mode, ...)

% refactor plotting into its own function

% generate one page subplot, with deltaSNR, bitallocation, HLOG and
% deltaQLN and add saving code

% either collect, store and process data, or load and process data
load_data = 0;


process_bitallocation = 1;
process_bitallocation2 = 1;
process_gainallocation = 1;
process_gainallocation2 = 1;
process_snrallocation = 1;
process_snrallocation2 = 1;
process_deltaSNR = 1;
process_deltaHLOG = 1;
process_deltaQLN = 1;

plot_combined = 1;
DefaultPaperSizeType = 'A4';
output_rect_fraction = 1/2.54; % matlab's print will interpret values as INCH even for PaperUnit centimeter specified figures...

close_figures_at_end = 1;
InvisibleFigures = 0;
if (InvisibleFigures)
	figure_visibility_string = 'off';
else
	figure_visibility_string = 'on';
end

% most commands require specification of the direction
direction_list = [1, 0];	% upload, download
updir = 0;
updir_string = num2str(updir);
downdir = 1;
downdir_string = num2str(downdir);

deltdatatype_list = [1]; % zero seems to be not in use
deltdatatype_string = num2str(deltdatatype_list(1));

channel_list = [0];
%channel_string = num2str(channel_list(1));
HistoryInterval_list = [0, 1, 2];


bit_color_up = [0 1 0];
bit_color_down = [0 0 1];
snr_color_up = [0 0.66 0];
snr_color_down = [254 233 23]/255;

out_format = 'pdf';
%out_format = 'png';

mat_prefix = 'lantiq_dsl_data';
out_dir = fullfile(pwd, out_format);
mat_save_dir = fullfile(pwd, 'dsl_cmd_run_data');
if ~isdir(mat_save_dir)
	mkdir(mat_save_dir);
end


%ssh root@192.168.100.1 '. /lib/functions/lantiq_dsl.sh ; dsl_cmd g997racg 0 0'
ssh_dsl_cfg.lantiq_IP = '192.168.100.1';
ssh_dsl_cfg.lantig_user = 'root';
ssh_dsl_cfg.lantig_dsl_cmd_prefix = '. /lib/functions/lantiq_dsl.sh ; dsl_cmd';
ssh_dsl_cfg.ssh_command_stem = ['ssh ', ssh_dsl_cfg.lantig_user, '@', ssh_dsl_cfg.lantiq_IP];
dsl_sub_cmd_arg_string = [];




if ~(load_data)
	current_dsl_struct = struct();
	
	current_datetime = datestr(now, 'yyyymmddTHHMMSS');
	current_dsl_struct.current_datetime = current_datetime;
	
	
	% get the list of all supported commands:
	%[ssh_status, dsl_cmd_output ] = fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, dsl_sub_cmd_arg_string );
	[ssh_status, dsl_cmd_output ] = fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, 'help', dsl_sub_cmd_arg_string );
	if (ssh_status == 0)
		tmp_list = strsplit(dsl_cmd_output);
		tmp_list(1) = [];
		num_subcmds_and_names = size(tmp_list, 2);
		current_dsl_struct.subcmd_list = tmp_list((1:2:num_subcmds_and_names-1));
		current_dsl_struct.subcmd_list = regexprep(current_dsl_struct.subcmd_list, ',$', '');	%remove trailing comata
		current_dsl_struct.subcmd_names_list  = tmp_list((2:2:num_subcmds_and_names));
	end
	
	% DATA collection
	% zero ARG commands: dsmstatg, bpsg cause issues
	zero_arg_sub_cmd_string_list = {'bpsg', 'vig', 'vpcg', 'ptsg', 'dsmsg', 'dsmcg', 'bpstg', 'pmcg', 'pmlictg', 'llcg', 'lsg', ...
		'g997xtusesg', 'g997xtusecg', 'g997upbosg'};
	for i_zero_arg_sub_cmd_string = 1 : length(zero_arg_sub_cmd_string_list)
		dsl_sub_cmd_string = zero_arg_sub_cmd_string_list{i_zero_arg_sub_cmd_string};
		[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string)] = ...
			fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, []);
		current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name = current_dsl_struct.subcmd_names_list{find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list))};
	end
	
	% commands with one argument: HistoryInterval
	% g997listrg cause issues
	single_arg_sub_cmd_string_list = {'pmlicsg', 'pmlic1dg', 'pmlic15mg'};
	for i_single_arg_sub_cmd_string = 1 : length(single_arg_sub_cmd_string_list)
		dsl_sub_cmd_string = single_arg_sub_cmd_string_list{i_single_arg_sub_cmd_string};
		for i_HistoryInterval = 1:length(HistoryInterval_list)
			cur_HistoryInterval = HistoryInterval_list(i_HistoryInterval);
			cur_HistoryInterval_string = [num2str(cur_HistoryInterval)];
			[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['HistoryInterval_', cur_HistoryInterval_string])] = ...
				fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, cur_HistoryInterval_string);
		end
		current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name = current_dsl_struct.subcmd_names_list{find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list))};
	end
	
	% commands with one argument: Direction
	% g997listrg cause issues
	single_arg_sub_cmd_string_list = {'osg', 'g997bansg', 'g997bang', 'g997gansg', 'g997gang', 'g997sansg', 'g997sang', 'lfsg', 'g997lspbg', ...
		'g997lig', 'g997ansg', 'g997listrg', 'g997rasg', 'pmlsctg', 'pmlesctg'};
	for i_single_arg_sub_cmd_string = 1 : length(single_arg_sub_cmd_string_list)
		dsl_sub_cmd_string = single_arg_sub_cmd_string_list{i_single_arg_sub_cmd_string};
		for i_dir = 1:length(direction_list)
			cur_dir = direction_list(i_dir);
			cur_dir_string = [num2str(cur_dir)];
			[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string])] = ...
				fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, cur_dir_string);
		end
		current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name = current_dsl_struct.subcmd_names_list{find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list))};
	end
	
	% commands with two arguments: Direction and DeltDataType
	dual_arg_sub_cmd_string_list = {'g997dsnrg', 'g997dhlogg', 'g997dqlng', 'g997lsg','dsnrg'};
	for i_dual_arg_sub_cmd_string = 1 : length(dual_arg_sub_cmd_string_list)
		dsl_sub_cmd_string = dual_arg_sub_cmd_string_list{i_dual_arg_sub_cmd_string};
		for i_dir = 1:length(direction_list)
			cur_dir = direction_list(i_dir);
			cur_dir_string = [num2str(cur_dir)];
			
			for i_deltdatatype = 1 : length(deltdatatype_list)
				cur_deltdatatype = deltdatatype_list(i_deltdatatype);
				cur_arg_string = [cur_dir_string, ' ', num2str(cur_deltdatatype)];
				[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).(['DeltDataType_', num2str(cur_deltdatatype)])] = ...
					fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, cur_arg_string);
			end
		end
		current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name = current_dsl_struct.subcmd_names_list{find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list))};
	end
	
	% commands with two arguments: Direction and HistoryInterval
	dual_arg_sub_cmd_string_list = {'pmlscsg', 'pmlsc1dg', 'pmlsc15mg', 'pmlescsg', 'pmlesc1dg', 'pmlesc15mg'};
	for i_dual_arg_sub_cmd_string = 1 : length(dual_arg_sub_cmd_string_list)
		dsl_sub_cmd_string = dual_arg_sub_cmd_string_list{i_dual_arg_sub_cmd_string};
		for i_dir = 1:length(direction_list)
			cur_dir = direction_list(i_dir);
			cur_dir_string = [num2str(cur_dir)];
			
			for i_HistoryInterval = 1 : length(HistoryInterval_list)
				cur_HistoryInterval = HistoryInterval_list(i_HistoryInterval);
				cur_arg_string = [cur_dir_string, ' ', num2str(cur_HistoryInterval)];
				[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).(['HistoryInterval_', num2str(cur_HistoryInterval)])] = ...
					fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, cur_arg_string);
			end
		end
		current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name = current_dsl_struct.subcmd_names_list{find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list))};
	end
	
	% commands with two arguments: Channel and Direction
	dual_arg_sub_cmd_string_list = {'g997fpsg', 'g997csg', 'fpsg', 'g997cdrtcg', 'pmcctg', 'pmdpctg'};
	for i_dual_arg_sub_cmd_string = 1 : length(dual_arg_sub_cmd_string_list)
		dsl_sub_cmd_string = dual_arg_sub_cmd_string_list{i_dual_arg_sub_cmd_string};
		
		for i_chan = 1: length(channel_list)
			cur_chan = channel_list(i_chan);
			cur_chan_string = [num2str(cur_chan)];
			for i_dir = 1:length(direction_list)
				cur_dir = direction_list(i_dir);
				cur_dir_string = [num2str(cur_dir)];
				[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['Channel_', cur_chan_string]).(['Direction_', cur_dir_string])] = ...
					fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, [cur_chan_string, ' ', cur_dir_string]);
			end
			
		end
		current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name = current_dsl_struct.subcmd_names_list{find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list))};
	end
	
	% commands with three arguments: Channel and Direction and HistoryInterval
	dual_arg_sub_cmd_string_list = {'pmdpcsg', 'pmdpc1dg', 'pmdpc15mg', 'pmccsg', 'pmcc1dg', 'pmcc15mg'};
	for i_dual_arg_sub_cmd_string = 1 : length(dual_arg_sub_cmd_string_list)
		dsl_sub_cmd_string = dual_arg_sub_cmd_string_list{i_dual_arg_sub_cmd_string};
		
		for i_chan = 1: length(channel_list)
			cur_chan = channel_list(i_chan);
			cur_chan_string = [num2str(cur_chan)];
			for i_dir = 1:length(direction_list)
				cur_dir = direction_list(i_dir);
				cur_dir_string = [num2str(cur_dir)];
				for i_HistoryInterval = 1 : length(HistoryInterval_list)
					cur_HistoryInterval = HistoryInterval_list(i_HistoryInterval);
					cur_histint_string = num2str(cur_HistoryInterval);
					
					[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['Channel_', cur_chan_string]).(['Direction_', cur_dir_string]).(['HistoryInterval_', num2str(cur_HistoryInterval)])] = ...
						fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, [cur_chan_string, ' ', cur_dir_string, ' ', cur_histint_string]);
				end
			end
			
		end
		current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name = current_dsl_struct.subcmd_names_list{find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list))};
	end
	
	
	% save data out
	disp(['Saving data to ', fullfile(mat_save_dir, [mat_prefix, '.', current_datetime, '.mat'])]);
	save(fullfile(mat_save_dir, [mat_prefix, '.', current_datetime, '.mat']), 'current_dsl_struct');
	
else
	% load data instead
	[lantiq_dsl_data_file_name, lantiq_dsl_data_file_dir] = uigetfile({[mat_prefix, '.*.mat']}, 'Select the lantig dsl data file');
	if (lantiq_dsl_data_file_name == 0)
		disp('No lantiq dsl data file selected, exiting');
		return
	end
	lantiq_dsl_data_file_FQN = fullfile(lantiq_dsl_data_file_dir, lantiq_dsl_data_file_name);
	disp(['Loading ', lantiq_dsl_data_file_FQN]);
	load(lantiq_dsl_data_file_FQN);
end


if (process_bitallocation)
	% g997bansg DIRECTION: 997_BitAllocationNscShortGet
	dsl_sub_cmd_string = 'g997bansg';
	
	n_bits_upload = sum(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data);
	n_bits_download = sum(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data);
	
	g997bansg_fh = figure('Name', current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data, 'EdgeColor', bit_color_up, 'FaceColor', bit_color_up);
	hold on
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data, 'EdgeColor', bit_color_down, 'FaceColor', bit_color_down);
	hold off
	set(gca(), 'YLim', [0 16]);
	ylabel(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_name);
	xlabel('Bin');
	title({[current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name, '; Up: ', num2str(n_bits_upload/1000), ' kbit; Down: ', num2str(n_bits_download/1000), ' kbit']; ...
		['Up: ', num2str(n_bits_upload*4/1000), ' Mbps; Down: ', num2str(n_bits_download*4/1000), ' Mbps']}, 'Interpreter', 'None');
	set(gca(), 'XLim', [0 current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).NumData]);
	
	write_out_figure(g997bansg_fh, fullfile(out_dir, [current_dsl_struct.current_datetime, '_', dsl_sub_cmd_string, '.', out_format]));
end

if (process_bitallocation2)
	% g997bansg DIRECTION: 997_BitAllocationNscShortGet
	dsl_sub_cmd_string = 'g997bang';
	
	n_bits_upload = sum(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data);
	n_bits_download = sum(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data);
	
	g997bang_fh = figure('Name', current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data, 'EdgeColor', bit_color_up, 'FaceColor', bit_color_up);
	hold on
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data, 'EdgeColor', bit_color_down, 'FaceColor', bit_color_down);
	hold off
	set(gca(), 'YLim', [0 16]);
	
	%x_max = size(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data, 2) * current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).GroupSize;
	set(gca(), 'XLim', [0 4096]);
	%get(gca(), 'XLim')
	
	ylabel(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_name);
	xlabel('Bin');
	title({[current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name, '; Up: ', num2str(n_bits_upload/1000), ' kbit; Down: ', num2str(n_bits_download/1000), ' kbit']; ...
		['Up: ', num2str(n_bits_upload*4/1000), ' Mbps; Down: ', num2str(n_bits_download*4/1000), ' Mbps']}, 'Interpreter', 'None');
	write_out_figure(g997bang_fh, fullfile(out_dir, [current_dsl_struct.current_datetime, '_', dsl_sub_cmd_string, '.', out_format]));
end


if (process_gainallocation)
	dsl_sub_cmd_string = 'g997gansg';
	
	g997gansg_fh = figure('Name', current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data, 'EdgeColor', bit_color_up, 'FaceColor', bit_color_up);
	hold on
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data, 'EdgeColor', bit_color_down, 'FaceColor', bit_color_down);
	hold off
	%set(gca(), 'YLim', [0 16]);
	ylabel(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_name);
	xlabel('Bin');
	title([current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name], 'Interpreter', 'None');
	set(gca(), 'XLim', [0 current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).NumData]);
	write_out_figure(g997gansg_fh, fullfile(out_dir, [current_dsl_struct.current_datetime, '_', dsl_sub_cmd_string, '.', out_format]));
end

if (process_gainallocation2)
	dsl_sub_cmd_string = 'g997gang';
	
	g997gang_fh = figure('Name', current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data, 'EdgeColor', bit_color_up, 'FaceColor', bit_color_up);
	hold on
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data, 'EdgeColor', bit_color_down, 'FaceColor', bit_color_down);
	hold off
	%set(gca(), 'YLim', [0 16]);
	ylabel(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_name);
	xlabel('Bin');
	title([current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name], 'Interpreter', 'None');
	write_out_figure(g997gang_fh, fullfile(out_dir, [current_dsl_struct.current_datetime, '_', dsl_sub_cmd_string, '.', out_format]));
end


if (process_snrallocation)
	% 	onlt 512 bins, but covering the whole frequency range (so one value for every 8 sub-carriers)
	dsl_sub_cmd_string = 'g997sansg';
	
	g997sansg_fh = figure('Name', current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data, 'EdgeColor', snr_color_up, 'FaceColor', snr_color_up);
	hold on
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data, 'EdgeColor', snr_color_down, 'FaceColor', snr_color_down);
	hold off
	%set(gca(), 'YLim', [0 16]);
	ylabel(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_name);
	xlabel('Bin');
	title([current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name], 'Interpreter', 'None');
	set(gca(), 'XLim', [0 current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).NumData]);
	write_out_figure(g997sansg_fh, fullfile(out_dir, [current_dsl_struct.current_datetime, '_', dsl_sub_cmd_string, '.', out_format]));
end

if (process_snrallocation2)
	% 	onlt 512 bins, but covering the whole frequency range (so one value for every 8 sub-carriers)
	dsl_sub_cmd_string = 'g997sang';
	
	g997sang_fh = figure('Name', current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data, 'EdgeColor', snr_color_up, 'FaceColor', snr_color_up);
	hold on
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data, 'EdgeColor', snr_color_down, 'FaceColor', snr_color_down);
	hold off
	%set(gca(), 'YLim', [0 16]);
	ylabel(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_name);
	xlabel('Bin');
	title([current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name], 'Interpreter', 'None');
	write_out_figure(g997sang_fh, fullfile(out_dir, [current_dsl_struct.current_datetime, '_', dsl_sub_cmd_string, '.', out_format]));
end

if (process_deltaSNR)
	% 	This takes two aruments, nDirection and nDeltDataType, but only 1
	% 	for nDeltDataType
	dsl_sub_cmd_string = 'g997dsnrg';
	
	g997dsnrg_fh = figure('Name', current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	ARG2 = ['DeltDataType_', deltdatatype_string];
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).(ARG2).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).(ARG2).Data, 'EdgeColor', snr_color_up, 'FaceColor', snr_color_up);
	hold on
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data, 'EdgeColor', snr_color_down, 'FaceColor', snr_color_down);
	hold off
	
	max_y = max(max(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data(:)),max(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).(ARG2).Data(:)));
	set(gca(), 'YLim', [20 ceil(max_y/5)*5]);
	
	x_max = size(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data, 2) * current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).GroupSize;
	set(gca(), 'XLim', [0 x_max]);
	set(gca(), 'XLim', [0 4096]);
	
	ylabel(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data_name);
	xlabel('Bin');
	title([current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name], 'Interpreter', 'None');
	write_out_figure(g997dsnrg_fh, fullfile(out_dir, [current_dsl_struct.current_datetime, '_', dsl_sub_cmd_string, '.', out_format]));
end

if (process_deltaHLOG)
	% 	This takes two aruments, nDirection and nDeltDataType, but only 1
	% 	for nDeltDataType
	dsl_sub_cmd_string = 'g997dhlogg';
	
	g997dhlogg_fh = figure('Name', current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	%bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).(ARG2).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).(ARG2).Data, 'EdgeColor', bit_color_up, 'FaceColor', bit_color_up);
	ARG2 = ['DeltDataType_', deltdatatype_string];
	plot(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).(ARG2).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).(ARG2).Data, 'Color', bit_color_up);
	hold on
	%bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data, 'EdgeColor', bit_color_down, 'FaceColor', bit_color_down);
	plot(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data, 'Color', bit_color_down);
	hold off
	%set(gca(), 'YLim', [0 16]);
	x_max = size(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data, 2) * current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).GroupSize;
	set(gca(), 'XLim', [0 x_max]);
	ylabel(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data_name);
	xlabel('Bin');
	title([current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name], 'Interpreter', 'None');
	write_out_figure(g997dhlogg_fh, fullfile(out_dir, [current_dsl_struct.current_datetime, '_', dsl_sub_cmd_string, '.', out_format]));
end


if (process_deltaQLN)
	% 	This takes two aruments, nDirection and nDeltDataType, but only 1
	% 	for nDeltDataType
	dsl_sub_cmd_string = 'g997dqlng';
	
	g997dqlng_fh = figure('Name', current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	%bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).(ARG2).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).(ARG2).Data, 'EdgeColor', bit_color_up, 'FaceColor', bit_color_up);
	ARG2 = ['DeltDataType_', deltdatatype_string];
	plot(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).(ARG2).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).(ARG2).Data, 'Color', bit_color_up);
	hold on
	%bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data, 'EdgeColor', bit_color_down, 'FaceColor', bit_color_down);
	plot(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data, 'Color', bit_color_down);
	
	hold off
	%set(gca(), 'YLim', [0 16]);
	x_max = size(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data, 2) * current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).GroupSize;
	set(gca(), 'XLim', [0 x_max]);
	ylabel(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data_name);
	xlabel('Bin');
	title([current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name], 'Interpreter', 'None');
	write_out_figure(g997dqlng_fh, fullfile(out_dir, [current_dsl_struct.current_datetime, '_', dsl_sub_cmd_string, '.', out_format]));
end

% construct summary figure

if (plot_combined)
	combined_SNR_BitAllocation_fh = figure('Name', ['SNR and Bit Allocation by sub-carrier: ', current_dsl_struct.current_datetime], 'visible', figure_visibility_string);
	%fnFormatDefaultAxes(DefaultAxesType);
	[output_rect] = fnFormatPaperSize(DefaultPaperSizeType, gcf, output_rect_fraction);
	set(combined_SNR_BitAllocation_fh, 'Units', 'centimeters', 'Position', output_rect, 'PaperPosition', output_rect);
	
	% G997_DeltSNRGet
	g997dsnrg_ah = findobj('Parent', g997dsnrg_fh, 'Type','axes');
	g997dsnrg_axh = copyobj(g997dsnrg_ah, combined_SNR_BitAllocation_fh);
	subplot(2,1,1, g997dsnrg_axh);
	
	% G997_BitAllocationNscGet
	g997bang_ah = findobj('Parent', g997bang_fh, 'Type','axes');
	g997bang_axh = copyobj(g997bang_ah, combined_SNR_BitAllocation_fh);
	subplot(2,1,2, g997bang_axh);
	
	dsl_sub_cmd_string = 'combined_SNR_BitAllocation';
	write_out_figure(combined_SNR_BitAllocation_fh, fullfile(out_dir, [current_dsl_struct.current_datetime, '_', dsl_sub_cmd_string, '.', out_format]));
	
	
	
	combined_HLOG_QLN_fh = figure('Name', ['HLOG and QLN by sub-carrier: ', current_dsl_struct.current_datetime], 'visible', figure_visibility_string);
	%fnFormatDefaultAxes(DefaultAxesType);
	[output_rect] = fnFormatPaperSize(DefaultPaperSizeType, gcf, output_rect_fraction);
	set(combined_HLOG_QLN_fh, 'Units', 'centimeters', 'Position', output_rect, 'PaperPosition', output_rect);
	
	% G997_DeltHLOGGet
	g997dhlogg_ah = findobj('Parent', g997dhlogg_fh, 'Type','axes');
	g997dhlogg_axh = copyobj(g997dhlogg_ah, combined_HLOG_QLN_fh);
	subplot(2,1,1, g997dhlogg_axh);
	
	% G997_DeltQLNGet
	g997dqlng_ah = findobj('Parent', g997dqlng_fh, 'Type','axes');
	g997dqlng_axh = copyobj(g997dqlng_ah, combined_HLOG_QLN_fh);
	subplot(2,1,2, g997dqlng_axh);
	
	dsl_sub_cmd_string = 'combined_HLOG_QLN';
	write_out_figure(combined_HLOG_QLN_fh, fullfile(out_dir, [current_dsl_struct.current_datetime, '_', dsl_sub_cmd_string, '.', out_format]));
end

% close all figues?
if (close_figures_at_end)
	close all;
end


return
end



function [ return_struct ] = fn_parse_lantiqdsl_cmd_output( input_char_array )
% dsl_cmd reurns a list of space separated key=value pairs, e.g.
% hms-beagle2:~ smoeller$ ssh root@192.168.100.1 '. /lib/functions/lantiq_dsl.sh ; dsl_cmd g997cdrtcg 0 0'
% nReturn=0 nChannel=0 nDirection=0 nDataRateThresholdUpshift=0 nDataRateThresholdDownshift=0

% bash-3.2$ ssh root@192.168.100.1 '. /lib/functions/lantiq_dsl.sh ; dsl_cmd g997bansg 1'
% nReturn=0 nDirection=1 nNumData=4096
% nFormat=nBit(hex) nData="
% 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
% 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ... "

return_struct = struct();

return_struct.input_string = input_char_array; % keep the origo=inally parsed string for sanity checking

% find the separators to get the number of items
key_value_separator = '=';
keep_parsing = 1;
unprocessed_string = input_char_array;
while (keep_parsing)
	[cur_key, unprocessed_string] = strtok(unprocessed_string, key_value_separator);
	% exit the loop
	if (isempty(unprocessed_string))
		keep_parsing = 0;
		break
	end
	cur_key = strtrim(cur_key);
	cur_struct_key = cur_key;
	% struct fields have issues with starting with n???
	if strcmp(cur_struct_key(1), 'n')
		cur_struct_key(1) = [];
	end
	% get rid of taboo characters in the key name so that the key can be
	% turned into a matlab structure fieldname
	cur_struct_key = sanitize_name_for_matlab(cur_struct_key);
	
	% remove the now trailing key_value_separator
	if strcmp(unprocessed_string(1), key_value_separator)
		unprocessed_string(1) = [];
	end
	
	if ~strcmp(cur_key, 'nData')
		[cur_value, unprocessed_string] = strtok(unprocessed_string, [' ', char(10)]);
		%TODO special case and parse nFormat (and use to parse nData
		% try to convert strings into numbers
		[~, str2num_status] = str2num(cur_value);
		if (str2num_status)
			cur_value = str2double(cur_value);
		end
		return_struct.(cur_struct_key) = cur_value;
	else
		% nData contains everything between two " double quotes
		douple_quote_idx = strfind(unprocessed_string, '"');
		if (length(douple_quote_idx) < 2)
			%% there is no trailing double quote, might be a bug
			%disp(['Trailling double quote missing: ', unprocessed_string]);
			if isempty(strfind(unprocessed_string, key_value_separator))
				% just pick the last value
				douple_quote_idx(end+1) = length(unprocessed_string) +1 ; % we subtract one again later
			else
				error('Missing quote is not in last key value pair, not handled, bailing out...');
			end
		end
		cur_value = unprocessed_string(douple_quote_idx(1)+1:douple_quote_idx(end)-1);
		% now emulate strtok and remove the extracted data from the
		% unprocessed_string, in case there are key-value pairs behind it
		unprocessed_string = unprocessed_string(douple_quote_idx(end)+1:end);
		return_struct = fn_convert_and_add_nData_to_struct(return_struct, cur_value, return_struct.Format);
	end
end

return
end

function [ out_struct ] = fn_convert_and_add_nData_to_struct(in_struct, in_value, in_Format)
% will evaluate the in_Format string to properly dissect the in_value data
% for know in_Formats this will als copy X and Y data for per bin values

out_struct = in_struct;
cur_value = in_value;

% implement generic parser that disects in_Format to create the correct
% amount of fields with names taken directly from in_format as well as
% using the correct format conversion
out_struct = fn_parse_value_string_by_in_Format(out_struct, cur_value, in_Format);

% change this to just create the canonical data copies so that a generic
% prinnting function can just plot Data over Data_xvec
switch in_Format
	case {'nBit(hex)', 'nGain(hex)', 'nSnr(hex)'}
		% copy the field containing the to-be-plotted data to .Data
		cur_name = strtok(in_Format, '(');
		out_struct.Data = out_struct.(sanitize_name_for_matlab(cur_name(2:end)));
		% synthesize a vector of x values to plot the data over
		out_struct.Data_xvec = (1:1:length(out_struct.Data)) - 1;
		
		out_struct.Data_name = sanitize_name_for_matlab(cur_name(2:end));
		out_struct.Data_xvec_name = sanitize_name_for_matlab('Bin');
		
		
	case {'(nGroupIndex(dec),nSnr(dec))', '(nToneIndex(dec),nSnr(hex))', ...
			'(nToneIndex(dec),nBit(hex))', '(nToneIndex(dec),nGain(hex))', ...
			'(nToneIndex(dec),nQln(dec))', '(nToneIndex(dec),nHlog(dec))', ...
			'(nPilotNum(dec),nPilotIndex(dec))'}
		% extract the Format information
		[proto_xvev_name, proto_data_name] = strtok(in_Format(2:end-1), ',');
		% get the xvecs
		proto_data_xvec = strtok(proto_xvev_name, '(');
		cur_xvec_name = sanitize_name_for_matlab(proto_data_xvec(2:end));
		out_struct.Data_xvec = out_struct.(cur_xvec_name);
		out_struct.Data_xvec_name = cur_xvec_name;
		
		% get the data
		cur_name = sanitize_name_for_matlab(strtok(proto_data_name(3:end), '('));
		out_struct.Data = out_struct.(cur_name);
		out_struct.Data_name = cur_name;
		
	otherwise
		disp(['fn_convert_and_add_nData_to_struct: Encountered unhandled format string: ', in_Format, ' no auto generation of .Data and .Data_xvec.']);
end

return
end



function [ quoted_string ] = fn_single_quote_string( string )
% wrap a string in single quotes...

quoted_string = [' '' ', string, ' '' '];

return
end

function [ ssh_status, dsl_cmd_output_string, parsed_dsl_output_struct ] = fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg_struct, dsl_sub_cmd_string, dsl_sub_cmd_arg_string )
% this function also does dsl_sub_cmd specific processing

dsl_cmd_output_string = [];

if ~exist('ssh_dsl_cfg_struct', 'var')
	error('The struct containing the ssh and dsl_cmd configuration is missing.');
end

if ~exist('dsl_sub_cmd_string', 'var')
	disp('The dsl_sub_cmd_string is missing.');
end

% not all commands need arguments
if ~exist('dsl_sub_cmd_arg_string', 'var') || isempty(dsl_sub_cmd_arg_string)
	dsl_sub_cmd_arg_string = '';
end


% get the list of all supported commands:
lantig_dsl_cmd_string = fn_single_quote_string([ssh_dsl_cfg_struct.lantig_dsl_cmd_prefix, ' ', dsl_sub_cmd_string, ' ', dsl_sub_cmd_arg_string]);
disp(['fn_call_dsl_cmd_via_ssh: ', lantig_dsl_cmd_string]);
[ssh_status, dsl_cmd_output_string] = system([ssh_dsl_cfg_struct.ssh_command_stem, ' ', fn_single_quote_string([ssh_dsl_cfg_struct.lantig_dsl_cmd_prefix, ' ', dsl_sub_cmd_string, ' ', dsl_sub_cmd_arg_string])]);

parsed_dsl_output_struct.dsl_sub_cmd_string = dsl_sub_cmd_string;
parsed_dsl_output_struct.dsl_sub_cmd_arg_string = dsl_sub_cmd_arg_string;

% this currently is incompatible with the parser
if strcmp(dsl_sub_cmd_string, 'g997listrg')
	parsed_dsl_output_struct.input_string = dsl_cmd_output_string;
	disp('g997listrg: parser incompatible, just returning the dsl_cmd_output_string as .input_string for now');
	return
end


parsed_dsl_output_struct = fn_parse_lantiqdsl_cmd_output(dsl_cmd_output_string);
% check nReturn, if not 0 display error message
if isfield(parsed_dsl_output_struct, 'Return')
	ret_val = parsed_dsl_output_struct.Return;
	if (ret_val ~= 0)
		disp(['Calling ', lantig_dsl_cmd_string, ' resulted in non-zero return value']);
		if ~isempty(regexp(dsl_cmd_output_string, 'wrong number of parameters'))
			disp(dsl_cmd_output_string);
		end
	end
else
	% the help command does not return nReturn
end

% some command return unscaled data, so scale according to T-REC-G.997.1-201902
if isfield(parsed_dsl_output_struct, 'Data')
	parsed_dsl_output_struct.Data_orig = parsed_dsl_output_struct.Data;
	parsed_dsl_output_struct.Data_name_orig = parsed_dsl_output_struct.Data_name;
	switch dsl_sub_cmd_string
		case {'g997gansg', 'g997gang'}
			% T-REC-G.997.1-201902: 7.5.1.29.3 Downstream gains allocation (GAINSpsds)
			% This parameter specifies the downstream gains allocation table per subcarrier. It is an array of
			% integer values in the 0 to 4 093 range for subcarriers 0 to NSds. The gain value is represented
			% as a multiple of 1/512 on linear scale. The same GAINSpsds format shall be applied to ITU-T G.992.3
			% and ITU-T G.992.5 Annex C FEXT GAINSpsds and NEXT GAINSpsds.
			% The reported gains of subcarriers out of the downstream MEDLEY set shall be set to 0.
			% This parameter shall be reported with the most recent values when read over the Q-interface.
			parsed_dsl_output_struct.Data = parsed_dsl_output_struct.Data / 512;
			parsed_dsl_output_struct.Data_name = parsed_dsl_output_struct.Data_name(2:end);
			
		case {'g997sansg', 'g997sang', 'g997dsnrg'}
			% mask out the FF/255 bins, as FF is the "no measurement could be done" marker
			parsed_dsl_output_struct.ignore_bin_marker = 255;
			parsed_dsl_output_struct.ignore_bin_idx = find(parsed_dsl_output_struct.Data == parsed_dsl_output_struct.ignore_bin_marker);
			
			% T-REC-G.997.1-201902: 7.5.1.28.3 Downstream SNR(f) (SNRpsds)
			% This parameter is an array of real values in decibels for downstream SNR(f). Each array entry represents
			% the SNR(f = i × SNRGds × ?f) value for a particular subcarrier group index i, ranging from 0 to MIN(NSds,511).
			% The SNR(f) is represented as (?32 + snr(i)/2), where snr(i) is an unsigned integer in the range from 0 to 254.
			% A special value indicates that no measurement could be done for this subcarrier group because it is out of the
			% passband or that the SNR is out of range to be represented. The same SNRpsds format shall be applied to ITU-T G.992.3
			% and ITU-T G.992.5 Annex C FEXT SNRpsds and NEXT SNRpsds.
			parsed_dsl_output_struct.Data = (parsed_dsl_output_struct.Data * 0.5) - 32;
			parsed_dsl_output_struct.Data(parsed_dsl_output_struct.ignore_bin_idx) = 0;
			parsed_dsl_output_struct.Data_name = [parsed_dsl_output_struct.Data_name(2:end), ' [dB]'];
			
		case 'g997dhlogg'
			parsed_dsl_output_struct.ignore_bin_marker = 1023;
			parsed_dsl_output_struct.ignore_bin_idx = find(parsed_dsl_output_struct.Data == parsed_dsl_output_struct.ignore_bin_marker);
			
			% T-REC-G.997.1-201902: 7.5.1.26.6 Downstream H(f) logarithmic representation (HLOGpsds)
			% This parameter is an array of real values in decibels for downstream Hlog(f). Each array entry represents
			% the real Hlog(f = i × HLOGGds × ?f) value for a particular subcarrier group subcarrier index i, ranging
			% from 0 to MIN(NSds,511). The real Hlog(f) value is represented as (6 ? m(i)/10), where m(i) is an
			% unsigned integer in the range from 0 to 1 022. A special value indicates that no measurement could be
			% done for this subcarrier group because it is out of the passband or that the attenuation is out of range to be represented.
			parsed_dsl_output_struct.Data = 6 - (parsed_dsl_output_struct.Data / 10);
			parsed_dsl_output_struct.Data(parsed_dsl_output_struct.ignore_bin_idx) = NaN;
			parsed_dsl_output_struct.Data_name = [parsed_dsl_output_struct.Data_name(2:end), ' [dB]'];
			
		case 'g997dqlng'
			parsed_dsl_output_struct.ignore_bin_marker = 255;
			parsed_dsl_output_struct.ignore_bin_idx = find(parsed_dsl_output_struct.Data == parsed_dsl_output_struct.ignore_bin_marker);
			
			% T-REC-G.997.1-201902: 7.5.1.27.3 Downstream QLN(f) (QLNpsds)
			% This parameter is an array of real values in decibels with reference to 1 mW per hertz for
			% downstream QLN(f). Each array entry represents the QLN(f = i × QLNGds × ?f) value for a particular
			% subcarrier group index i, ranging from 0 to MIN(NSds,511). The QLN(f) is represented as (?23 ? n(i)/2), where
			% n(i) is an unsigned integer in the range from 0 to 254. A special value indicates that no measurement could
			% be done for this subcarrier group because it is out of the passband or that the noise PSD is out of range to be represented.
			% The same QLNpsds format shall be applied to ITU-T G.992.3 and ITU-T G.992.5 Annex C FEXT QLNpsds and NEXT QLNpsds.
			parsed_dsl_output_struct.Data = -23 - (parsed_dsl_output_struct.Data / 2);
			parsed_dsl_output_struct.Data(parsed_dsl_output_struct.ignore_bin_idx) = NaN;
			parsed_dsl_output_struct.Data_name = [parsed_dsl_output_struct.Data_name(2:end), ' [dB, ref 1mW/Hz]'];
			
			
		case {'g997bang', 'g997bansg'}
			parsed_dsl_output_struct.Data_name = parsed_dsl_output_struct.Data_name(2:end);
			
		otherwise
			% nothing to do
	end
	% get the correct frequency center bins.
	switch dsl_sub_cmd_string
		case {'g997dsnrg', 'g997dhlogg', 'g997dqlng'}
			% adjust the xvec to the group center bins
			if isfield(parsed_dsl_output_struct, 'GroupSize')
				parsed_dsl_output_struct.Data_xvec_orig = parsed_dsl_output_struct.Data_xvec;
				parsed_dsl_output_struct.Data_xvec_groupcentered = (parsed_dsl_output_struct.Data_xvec * parsed_dsl_output_struct.GroupSize) + (parsed_dsl_output_struct.GroupSize * 0.5);
				parsed_dsl_output_struct.Data_xvec = parsed_dsl_output_struct.Data_xvec_groupcentered;
			end
	end
end

return
end



function [ ret_val ] = write_out_figure(img_fh, outfile_fqn, verbosity_str, print_options_str)
%WRITE_OUT_FIGURE save the figure referenced by img_fh to outfile_fqn,
% using .ext of outfile_fqn to decide which image type to save as.
%   Detailed explanation goes here
% write out the data

if ~exist('verbosity_str', 'var')
	verbosity_str = 'verbose';
end

% check whether the path exists, create if not...
[pathstr, name, img_type] = fileparts(outfile_fqn);
if isempty(dir(pathstr)),
	mkdir(pathstr);
end

% deal with r2016a changes, needs revision
if (strcmp(version('-release'), '2016a'))
	set(img_fh, 'PaperPositionMode', 'manual');
	if ~ismember(img_type, {'.png', '.tiff', '.tif'})
		print_options_str = '-bestfit';
	end
end

if ~exist('print_options_str', 'var') || isempty(print_options_str)
	print_options_str = '';
else
	print_options_str = [', ''', print_options_str, ''''];
end
resolution_str = ', ''-r600''';


device_str = [];

switch img_type(2:end)
	case 'pdf'
		% pdf in 7.3.0 is slightly buggy...
		%print(img_fh, '-dpdf', outfile_fqn);
		device_str = '-dpdf';
	case 'ps3'
		%print(img_fh, '-depsc2', outfile_fqn);
		device_str = '-depsc';
		print_options_str = '';
		outfile_fqn = [outfile_fqn, '.eps'];
	case {'ps', 'ps2'}
		%print(img_fh, '-depsc2', outfile_fqn);
		device_str = '-depsc2';
		print_options_str = '';
		outfile_fqn = [outfile_fqn, '.eps'];
	case {'tiff', 'tif'}
		% tiff creates a figure
		%print(img_fh, '-dtiff', outfile_fqn);
		device_str = '-dtiff';
	case 'png'
		% tiff creates a figure
		%print(img_fh, '-dpng', outfile_fqn);
		device_str = '-dpng';
		resolution_str = ', ''-r1200''';
	case 'eps'
		%print(img_fh, '-depsc', '-r300', outfile_fqn);
		device_str = '-depsc';
	case 'fig'
		%sm: allows to save figures for further refinements
		saveas(img_fh, outfile_fqn, 'fig');
	otherwise
		% default to uncompressed images
		disp(['Image type: ', img_type, ' not handled yet...']);
end

if ~isempty(device_str)
	device_str = [', ''', device_str, ''''];
	command_str = ['print(img_fh', device_str, print_options_str, resolution_str, ', outfile_fqn)'];
	eval(command_str);
end

if strcmp(verbosity_str, 'verbose')
	if ~isnumeric(img_fh)
		disp(['Saved figure (', num2str(img_fh.Number), ') to: ', outfile_fqn]);	% >R2014b have structure figure handles
	else
		disp(['Saved figure (', num2str(img_fh), ') to: ', outfile_fqn]);			% older Matlab has numeric figure handles
	end
end

ret_val = 0;

return
end



function [ output_rect ] = fnFormatPaperSize( type, gcf_h, fraction)
%FNFORMATPAPERSIZE Set the paper size for a plot, also return a reasonably
%tight output_rect.
% 20070827sm: changed default output formatting to allow pretty paper output
% Example usage:
%     Cur_fh = figure('Name', 'Test');
%     fnFormatDefaultAxes('16to9slides');
%     [output_rect] = fnFormatPaperSize('16to9landscape', gcf);
%     set(gcf(), 'Units', 'centimeters', 'Position', output_rect);
if nargin < 3
	fraction = 1;	% fractional columns?
end

switch type
	case 'A4'
		left_edge_cm = 0.05;
		bottom_edge_cm = 0.05;
		A4_w_cm = 21.0;
		A4_h_cm = 29.7;
		rect_w = (A4_w_cm - 2*left_edge_cm) * fraction;
		rect_h = ((A4_h_cm * 610/987) - 2*bottom_edge_cm) * fraction; % 610/987 approximates the golden ratio
		output_rect = [left_edge_cm bottom_edge_cm rect_w rect_h];	% left, bottom, width, height
		%output_rect = [1.0 2.0 27.7 12.0];
		set(gcf_h, 'PaperSize', [rect_w+2*left_edge_cm*fraction rect_h+2*bottom_edge_cm*fraction], 'PaperOrientation', 'landscape', 'PaperUnits', 'centimeters');
		
	case 'europe'
		output_rect = [1.0 2.0 27.7 12.0];
		set(gcf_h, 'PaperType', 'A4', 'PaperOrientation', 'landscape', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		
	case 'europe_portrait'
		output_rect = [1.0 2.0 20.0 27.7];
		set(gcf_h, 'PaperType', 'A4', 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		
	case 'default'
		% letter 8.5 x 11 ", or 215.9 mm ? 279.4 mm
		output_rect = [1.0 2.0 19.59 25.94];
		set(gcf_h, 'PaperType', 'usletter', 'PaperOrientation', 'landscape', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		
	case 'default_portrait'
		output_rect = [1.0 2.0 25.94 19.59];
		set(gcf_h, 'PaperType', 'usletter', 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		
	otherwise
		output_rect = [1.0 2.0 25.9 12.0];
		set(gcf_h, 'PaperType', 'usletter', 'PaperOrientation', 'landscape', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
end

return
end

function [ sanitized_name ]  = sanitize_name_for_matlab( input_name )
% some characters are not really helpful inside matlab variable names, so
% replace them with something that should not cause problems
taboo_char_list =		{' ', '-', '.', '=', '/', '[', ']'};
replacement_char_list = {'_', '_', '_dot_', '_eq_', '_', '_', '_'};

taboo_first_char_list = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'};
replacement_firts_char_list = {'Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine'};

sanitized_name = input_name;
% check first character to not be a number
taboo_first_char_idx = find(ismember(taboo_first_char_list, input_name(1)));
if ~isempty(taboo_first_char_idx)
	sanitized_name = [replacement_firts_char_list{taboo_first_char_idx}, input_name(2:end)];
end



for i_taboo_char = 1: length(taboo_char_list)
	current_taboo_string = taboo_char_list{i_taboo_char};
	current_replacement_string = replacement_char_list{i_taboo_char};
	current_taboo_processed = 0;
	remain = sanitized_name;
	tmp_string = '';
	while (~current_taboo_processed)
		[token, remain] = strtok(remain, current_taboo_string);
		tmp_string = [tmp_string, token, current_replacement_string];
		if isempty(remain)
			current_taboo_processed = 1;
			% we add one superfluous replaceent string at the end, so
			% remove that
			tmp_string = tmp_string(1:end-length(current_replacement_string));
		end
	end
	sanitized_name = tmp_string;
end

return
end


function [ out_struct ] = fn_parse_value_string_by_in_Format(in_struct, cur_value, in_Format)
% parse the dsl_pipe nData fields based on the nFormat string's components


out_struct = in_struct;
value_list = strsplit(strtrim(cur_value));
field_separator = ',';

processed_in_Format = in_Format;

% get the number of fields
n_values_per_cell = length(strfind(in_Format, ',')) + 1;
if n_values_per_cell > 1
	grouping_chars_expression = ['(^\', in_Format(1), '|\', in_Format(end), '$)'];
	% remove the enclosing parantheses
	processed_in_Format = regexprep(in_Format, grouping_chars_expression, '');
end

% split the inFormat into name and types
type_list = cell([1 n_values_per_cell]);
name_list = cell([1 n_values_per_cell]);
for i_values = 1 : n_values_per_cell
	[cur_format, processed_in_Format] = strtok(processed_in_Format, field_separator);	
	processed_in_Format = processed_in_Format(2:end); % get rid of the delimiter
	[proto_name, proto_type] = strtok(cur_format, '(');
	name_list{i_values} = sanitize_name_for_matlab(proto_name(2:end));
	type_list{i_values} = sanitize_name_for_matlab(proto_type(2:end-1));
	
	% pre allocate the actual data fields
	out_struct.(name_list{i_values}) = zeros(size(value_list));
	out_struct.([name_list{i_values}, '_type']) = type_list{i_values};
end

% now process the data
for i_val = 1: length(value_list)
	cur_values = value_list{i_val};
	if n_values_per_cell > 1
		cur_values = regexprep(value_list{i_val}, grouping_chars_expression, '');
	end
	
	processed_cur_val = cur_values;
	for i_values = 1 : n_values_per_cell
		cur_type = type_list{i_values};
		cur_name = name_list{i_values};
		% split, split, split
		[cur_value, processed_cur_val] = strtok(processed_cur_val, field_separator);
		processed_cur_val = processed_cur_val(2:end); % get rid of the delimiter
			
		switch cur_type
			case 'hex'
				out_struct.(cur_name)(i_val) = hex2dec(cur_value);
			case 'dec'
				out_struct.(cur_name)(i_val) = str2num(cur_value);
			otherwise
				error(['Encountered unknown Data_type: ', cur_type]);
		end	
	end
end

return
end