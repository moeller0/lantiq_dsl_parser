function [ output_args ] = lantiq_dsl_parser( input_args )
%LANTIQ_DSL_PARSER Summary of this function goes here
%   Detailed explanation goes here

% TODO: 
%	scale the x_vecs correctly, by evaluating nGroupSize
%	add textual summary and error statistics page
%	find G.INP RTX counter?
%	separate data acquisition and plotting
%	save out plots and data
%	allow to read from precanned text captures of dsl_cmd output
%	collect statistics over collected per bin data (min, max, mode, ...)

process_bitallocation = 0;
process_bitallocation2 = 0;
process_gainallocation = 1;
process_gainallocation2 = 1;
process_snrallocation = 1;
process_deltaSNR = 1;
process_deltaHLOG = 1;
process_deltaQLN = 1;

% most commands require specification of the direction
direction_list = [1, 0];	% upload, download
updir = 0;
updir_string = num2str(updir);
downdir = 1;
downdir_string = num2str(downdir);

bit_color_up = [0 1 0];
bit_color_down = [0 0 1];
snr_color_up = [0 0.66 0];
snr_color_down = [254 233 23]/255;




current_dsl_struct = struct();

%ssh root@192.168.100.1 '. /lib/functions/lantiq_dsl.sh ; dsl_cmd g997racg 0 0'
ssh_dsl_cfg.lantiq_IP = '192.168.100.1';
ssh_dsl_cfg.lantig_user = 'root';
ssh_dsl_cfg.lantig_dsl_cmd_prefix = '. /lib/functions/lantiq_dsl.sh ; dsl_cmd';
ssh_dsl_cfg.ssh_command_stem = ['ssh ', ssh_dsl_cfg.lantig_user, '@', ssh_dsl_cfg.lantiq_IP];
dsl_sub_cmd_arg_string = [];



% get the list of all supported commands:
%[ssh_status, dsl_cmd_output ] = fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, dsl_sub_cmd_arg_string );
[ssh_status, dsl_cmd_output ] = fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, 'help', dsl_sub_cmd_arg_string );
if (ssh_status == 0)
	tmp_list = strsplit(dsl_cmd_output);
	tmp_list(1) = [];
	num_subcmds_and_names = size(tmp_list, 2);
	subcmd_list = tmp_list((1:2:num_subcmds_and_names-1));
	subcmd_list = regexprep(subcmd_list, ',$', '');	%remove trailing comata
	subcmd_names_list  = tmp_list((2:2:num_subcmds_and_names));
end
%TODO get the number and names of the required arguments for each sub
%command

% % G.INP:
% lfcg 1 0
% lfcg 1 1
% lfsg 0
% lfsg 1


if (process_bitallocation)
	% g997bansg DIRECTION: 997_BitAllocationNscShortGet
	dsl_sub_cmd_string = 'g997bansg';
	
	% find dsl_sub_cmd_string in subcmd_list and get the nmae from the matching position in subcmd_names_list
	dsl_sub_cmd_name = subcmd_names_list{find(strcmp(dsl_sub_cmd_string, subcmd_list))};
	
	for i_dir = 1:length(direction_list)
		cur_dir = direction_list(i_dir);
		cur_dir_string = [num2str(cur_dir)];
		[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string])] = ...
			fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, cur_dir_string);
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data_orig = current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data;
	end
	n_bits_upload = sum(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data);
	n_bits_download = sum(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data);
	
	g997bansg_fh = figure('Name', dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data, 'EdgeColor', bit_color_up, 'FaceColor', bit_color_up);
	hold on
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data, 'EdgeColor', bit_color_down, 'FaceColor', bit_color_down);
	hold off
	set(gca(), 'YLim', [0 16]);
	ylabel(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_name);
	xlabel('Bin');
	title({[dsl_sub_cmd_name, '; Up: ', num2str(n_bits_upload/1000), ' kbit; Down: ', num2str(n_bits_download/1000), ' kbit']; ...
		['Up: ', num2str(n_bits_upload*4/1000), ' Mbps; Down: ', num2str(n_bits_download*4/1000), ' Mbps']}, 'Interpreter', 'None');
	set(gca(), 'XLim', [0 current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).NumData]);
end

if (process_bitallocation2)
	% g997bansg DIRECTION: 997_BitAllocationNscShortGet
	dsl_sub_cmd_string = 'g997bang';
	
	% find dsl_sub_cmd_string in subcmd_list and get the nmae from the matching position in subcmd_names_list
	dsl_sub_cmd_name = subcmd_names_list{find(strcmp(dsl_sub_cmd_string, subcmd_list))};
	
	for i_dir = 1:length(direction_list)
		cur_dir = direction_list(i_dir);
		cur_dir_string = [num2str(cur_dir)];
		[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string])] = ...
			fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, cur_dir_string);
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data_orig = current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data
	end
	n_bits_upload = sum(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data);
	n_bits_download = sum(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data);
	
	g997bansg_fh = figure('Name', dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data, 'EdgeColor', bit_color_up, 'FaceColor', bit_color_up);
	hold on
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data, 'EdgeColor', bit_color_down, 'FaceColor', bit_color_down);
	hold off
	set(gca(), 'YLim', [0 16]);
	ylabel(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_name);
	xlabel('Bin');
	title({[dsl_sub_cmd_name, '; Up: ', num2str(n_bits_upload/1000), ' kbit; Down: ', num2str(n_bits_download/1000), ' kbit']; ...
		['Up: ', num2str(n_bits_upload*4/1000), ' Mbps; Down: ', num2str(n_bits_download*4/1000), ' Mbps']}, 'Interpreter', 'None');
end


if (process_gainallocation)
	dsl_sub_cmd_string = 'g997gansg';
	
	% find dsl_sub_cmd_string in subcmd_list and get the nmae from the matching position in subcmd_names_list
	dsl_sub_cmd_name = subcmd_names_list{find(strcmp(dsl_sub_cmd_string, subcmd_list))};
	
	for i_dir = 1:length(direction_list)
		cur_dir = direction_list(i_dir);
		cur_dir_string = [num2str(cur_dir)];
		[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string])] = ...
			fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, cur_dir_string);
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data_orig = current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data;
		% T-REC-G.997.1-201902: 7.5.1.29.3 Downstream gains allocation (GAINSpsds)
		% This parameter specifies the downstream gains allocation table per subcarrier. It is an array of 
		% integer values in the 0 to 4 093 range for subcarriers 0 to NSds. The gain value is represented 
		% as a multiple of 1/512 on linear scale. The same GAINSpsds format shall be applied to ITU-T G.992.3 
		% and ITU-T G.992.5 Annex C FEXT GAINSpsds and NEXT GAINSpsds.
		% The reported gains of subcarriers out of the downstream MEDLEY set shall be set to 0.
		% This parameter shall be reported with the most recent values when read over the Q-interface.
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data = current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data / 512;
	end
	
	g997gansg_fh = figure('Name', dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data, 'EdgeColor', bit_color_up, 'FaceColor', bit_color_up);
	hold on
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data, 'EdgeColor', bit_color_down, 'FaceColor', bit_color_down);
	hold off
	%set(gca(), 'YLim', [0 16]);
	ylabel(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_name);
	xlabel('Bin');
	title([dsl_sub_cmd_name], 'Interpreter', 'None');
	set(gca(), 'XLim', [0 current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).NumData]);
end

if (process_gainallocation2)
	dsl_sub_cmd_string = 'g997gang';
	
	% find dsl_sub_cmd_string in subcmd_list and get the nmae from the matching position in subcmd_names_list
	dsl_sub_cmd_name = subcmd_names_list{find(strcmp(dsl_sub_cmd_string, subcmd_list))};
	
	for i_dir = 1:length(direction_list)
		cur_dir = direction_list(i_dir);
		cur_dir_string = [num2str(cur_dir)];
		[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string])] = ...
			fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, cur_dir_string);
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data_orig = current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data;
		% T-REC-G.997.1-201902: 7.5.1.29.3 Downstream gains allocation (GAINSpsds)
		% This parameter specifies the downstream gains allocation table per subcarrier. It is an array of 
		% integer values in the 0 to 4 093 range for subcarriers 0 to NSds. The gain value is represented 
		% as a multiple of 1/512 on linear scale. The same GAINSpsds format shall be applied to ITU-T G.992.3 
		% and ITU-T G.992.5 Annex C FEXT GAINSpsds and NEXT GAINSpsds.
		% The reported gains of subcarriers out of the downstream MEDLEY set shall be set to 0.
		% This parameter shall be reported with the most recent values when read over the Q-interface.
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data = current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data / 512;
	end
	
	g997gansg_fh = figure('Name', dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data, 'EdgeColor', bit_color_up, 'FaceColor', bit_color_up);
	hold on
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data, 'EdgeColor', bit_color_down, 'FaceColor', bit_color_down);
	hold off
	%set(gca(), 'YLim', [0 16]);
	ylabel(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_name);
	xlabel('Bin');
	title([dsl_sub_cmd_name], 'Interpreter', 'None');
end


%
%
if (process_snrallocation)
	% 	onlt 512 bins, but covering the whole frequency range (so one value for every 8 sub-carriers)
	dsl_sub_cmd_string = 'g997sansg';
	
	% find dsl_sub_cmd_string in subcmd_list and get the nmae from the matching position in subcmd_names_list
	dsl_sub_cmd_name = subcmd_names_list{find(strcmp(dsl_sub_cmd_string, subcmd_list))};
	
	for i_dir = 1:length(direction_list)
		cur_dir = direction_list(i_dir);
		cur_dir_string = [num2str(cur_dir)];
		[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string])] = fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, cur_dir_string);
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data_orig = current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data;
		% mask out the FF/255 bins, as these are not used for each
		% respective direction
		FF_idx = find(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data == 255);
		
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data = -32 + (current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data * 0.5);
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data(FF_idx) = 0;
	end
	
	g997sansg_fh = figure('Name', dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data, 'EdgeColor', snr_color_up, 'FaceColor', snr_color_up);
	hold on
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data, 'EdgeColor', snr_color_down, 'FaceColor', snr_color_down);
	hold off
	%set(gca(), 'YLim', [0 16]);
	ylabel(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_name);
	xlabel('Bin');
	title([dsl_sub_cmd_name], 'Interpreter', 'None');
end


if (process_deltaSNR)
	% 	This takes two aruments, nDirection and nDeltDataType, but only 1
	% 	for nDeltDataType
	dsl_sub_cmd_string = 'g997dsnrg';
	
	% find dsl_sub_cmd_string in subcmd_list and get the nmae from the matching position in subcmd_names_list
	dsl_sub_cmd_name = subcmd_names_list{find(strcmp(dsl_sub_cmd_string, subcmd_list))};
	
	for i_dir = 1:length(direction_list)
		cur_dir = direction_list(i_dir);
		cur_dir_string = [num2str(cur_dir)];
		[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string])] = ...
			fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, [cur_dir_string, ' 1']);
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data_orig = current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data;

		% mask out the FF/255 bins, as these are not used for each
		% respective direction
		FF_idx = find(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data == 255);
		%current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data(FF_idx) = 0;
		
		% T-REC-G.997.1-201902: 7.5.1.28.3 Downstream SNR(f) (SNRpsds)
		% This parameter is an array of real values in decibels for downstream SNR(f). Each array entry represents 
		% the SNR(f = i × SNRGds × ?f) value for a particular subcarrier group index i, ranging from 0 to MIN(NSds,511). 
		% The SNR(f) is represented as (?32 + snr(i)/2), where snr(i) is an unsigned integer in the range from 0 to 254. 
		% A special value indicates that no measurement could be done for this subcarrier group because it is out of the 
		% passband or that the SNR is out of range to be represented. The same SNRpsds format shall be applied to ITU-T G.992.3 
		% and ITU-T G.992.5 Annex C FEXT SNRpsds and NEXT SNRpsds.
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data = -32 + (current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data * 0.5);
		
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data(FF_idx) = 0;
	end
	
	g997dsnrg_fh = figure('Name', dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data, 'EdgeColor', snr_color_up, 'FaceColor', snr_color_up);
	hold on
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data, 'EdgeColor', snr_color_down, 'FaceColor', snr_color_down);
	hold off
	set(gca(), 'YLim', [20 60]);
	set(gca(), 'XLim', [0 511]);
	ylabel(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_name);
	xlabel('Bin');
	title([dsl_sub_cmd_name], 'Interpreter', 'None');
end

if (process_deltaHLOG)
	% 	This takes two aruments, nDirection and nDeltDataType, but only 1
	% 	for nDeltDataType
	dsl_sub_cmd_string = 'g997dhlogg';
	
	% find dsl_sub_cmd_string in subcmd_list and get the nmae from the matching position in subcmd_names_list
	dsl_sub_cmd_name = subcmd_names_list{find(strcmp(dsl_sub_cmd_string, subcmd_list))};
	
	for i_dir = 1:length(direction_list)
		cur_dir = direction_list(i_dir);
		cur_dir_string = [num2str(cur_dir)];
		[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string])] = ...
			fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, [cur_dir_string, ' 1']);
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data_orig = current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data;
		% mask out the FF/255 bins, as these are not used for each
		% respective direction
		FF_idx = find(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data == 1023);
		%current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data(FF_idx) = 0;
		
		% T-REC-G.997.1-201902: 7.5.1.26.6 Downstream H(f) logarithmic representation (HLOGpsds)
		% This parameter is an array of real values in decibels for downstream Hlog(f). Each array entry represents 
		% the real Hlog(f = i × HLOGGds × ?f) value for a particular subcarrier group subcarrier index i, ranging 
		% from 0 to MIN(NSds,511). The real Hlog(f) value is represented as (6 ? m(i)/10), where m(i) is an 
		% unsigned integer in the range from 0 to 1 022. A special value indicates that no measurement could be 
		% done for this subcarrier group because it is out of the passband or that the attenuation is out of range to be represented.		
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data = 6 - (current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data / 10);
		
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data(FF_idx) = NaN;
	end
	
	g997dhlogg_fh = figure('Name', dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	%bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data, 'EdgeColor', bit_color_up, 'FaceColor', bit_color_up);
	plot(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data, 'Color', bit_color_up);
	hold on
	%bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data, 'EdgeColor', bit_color_down, 'FaceColor', bit_color_down);
	plot(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data, 'Color', bit_color_down);
	hold off
	%set(gca(), 'YLim', [0 16]);
	set(gca(), 'XLim', [0 511]);
	ylabel(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_name);
	xlabel('Bin');
	title([dsl_sub_cmd_name], 'Interpreter', 'None');
end


if (process_deltaQLN)
	% 	This takes two aruments, nDirection and nDeltDataType, but only 1
	% 	for nDeltDataType
	dsl_sub_cmd_string = 'g997dqlng';
	
	% find dsl_sub_cmd_string in subcmd_list and get the nmae from the matching position in subcmd_names_list
	dsl_sub_cmd_name = subcmd_names_list{find(strcmp(dsl_sub_cmd_string, subcmd_list))};
	
	for i_dir = 1:length(direction_list)
		cur_dir = direction_list(i_dir);
		cur_dir_string = [num2str(cur_dir)];
		[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string])] = ...
			fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, [cur_dir_string, ' 1']);
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data_orig = current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data;
		% mask out the FF/255 bins, as these are not used for each
		% respective direction
		FF_idx = find(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data == 255);
		%current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data(FF_idx) = 0;
		
		% T-REC-G.997.1-201902: 7.5.1.27.3 Downstream QLN(f) (QLNpsds)
		% This parameter is an array of real values in decibels with reference to 1 mW per hertz for 
		% downstream QLN(f). Each array entry represents the QLN(f = i × QLNGds × ?f) value for a particular 
		% subcarrier group index i, ranging from 0 to MIN(NSds,511). The QLN(f) is represented as (?23 ? n(i)/2), where
		% n(i) is an unsigned integer in the range from 0 to 254. A special value indicates that no measurement could 
		% be done for this subcarrier group because it is out of the passband or that the noise PSD is out of range to be represented. 
		% The same QLNpsds format shall be applied to ITU-T G.992.3 and ITU-T G.992.5 Annex C FEXT QLNpsds and NEXT QLNpsds.		
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data = -23 - (current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data / 2);
		
		current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string]).Data(FF_idx) = NaN;
	end
	
	g997dqlng_fh = figure('Name', dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	%bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data, 'EdgeColor', bit_color_up, 'FaceColor', bit_color_up);
	plot(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data, 'Color', bit_color_up);
	hold on
	%bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data, 'EdgeColor', bit_color_down, 'FaceColor', bit_color_down);
	plot(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data, 'Color', bit_color_down);

	hold off
	%set(gca(), 'YLim', [0 16]);
	set(gca(), 'XLim', [0 511]);
	ylabel(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data_name);
	xlabel('Bin');
	title([dsl_sub_cmd_name], 'Interpreter', 'None');
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
			% there is no trailing double quote, might be a bug
			disp(['Trailling double quote missing: ', unprocessed_string]);
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
% ideally this can be turned into evaluating in_format instead of hard
% coding it, but for today...

%TODO add the proper x_vec, deal with grouped/aggregate data


out_struct = in_struct;
cur_value = in_value;
switch in_Format
	case {'nBit(hex)', 'nGain(hex)', 'nSnr(hex)'}
		% convert into cell array anf then convert each cell from hex to decimal
		[out_struct.Data_name, rem] = strtok(in_Format, '(');
		out_struct.Data_type = rem(2:end-1);
		
		value_list = strsplit(strtrim(cur_value));
		switch out_struct.Data_type
			case 'hex'
				out_struct.Data = hex2dec(value_list)';
			otherwise
				error(['Encountered unknown Data_type: ', out_struct.Data_type]);
		end
		out_struct.Data_xvec = (1:1:length(out_struct.Data)) - 1;
		
	case {'(nGroupIndex(dec),nSnr(dec))', '(nToneIndex(dec),nHlog(dec))', ...
			'(nToneIndex(dec),nBit(hex))', '(nToneIndex(dec),nQln(dec))', ...
			'(nToneIndex(dec),nGain(hex))'}
		% extract the Format information
		[first, second] = strtok(in_Format, ',');
		[out_struct.Data_xvec_name, proto_type] = strtok(first(2:end), '(');
		out_struct.Data_xvec_type = proto_type(2:end-1);
		[out_struct.Data_name, proto_type] = strtok(second(2:end), '(');
		out_struct.Data_type = proto_type(2:end-2);
		
		value_list = strsplit(strtrim(cur_value));
		out_struct.Data = zeros(size(value_list));
		out_struct.Data_xvec = zeros(size(value_list));
		for i_val = 1: length(value_list)
			cur_val = value_list{i_val}(2:end-1);
			[tmp_xvec, tmp_data] = strtok(cur_val, ',');
			switch out_struct.Data_xvec_type
				case 'dec'
					out_struct.Data_xvec(i_val) = str2num(tmp_xvec);
				otherwise
					error(['Encountered unknown Data_xvex_type: ', out_struct.Data_xvec_type]);
			end
			
			switch out_struct.Data_type
				case 'dec'
					out_struct.Data(i_val) = str2num(tmp_data(2:end));
				case 'hex'
					out_struct.Data(i_val) = hex2dec(tmp_data(2:end));
				otherwise
					error(['Encountered unknown Data_type: ', out_struct.Data_type]);
			end
		end
		% 
		if isfield(out_struct, 'GroupSize')
			% grouped data is basically binned, so return the center bin
			% for each group
			out_struct.Data_xvec_orig = out_struct.Data_xvec;
			out_struct.Data_xvec_groupcentered = (out_struct.Data_xvec * out_struct.GroupSize) + (out_struct.GroupSize * 0.5);
			out_struct.Data_xvec = out_struct.Data_xvec_groupcentered;
		end
		
	otherwise
		error(['Encountered unhandled format string: ', in_Format]);
end

return
end



function [ quoted_string ] = fn_single_quote_string( string )
% wrap a string in single quotes...

quoted_string = [' '' ', string, ' '' '];

return
end

function [ ssh_status, dsl_cmd_output_string, parsed_dsl_output_struct ] = fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg_struct, dsl_sub_cmd_string, dsl_sub_cmd_arg_string )

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
[ssh_status, dsl_cmd_output_string] = system([ssh_dsl_cfg_struct.ssh_command_stem, ' ', fn_single_quote_string([ssh_dsl_cfg_struct.lantig_dsl_cmd_prefix, ' ', dsl_sub_cmd_string, ' ', dsl_sub_cmd_arg_string])]);

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
parsed_dsl_output_struct.Data_orig = parsed_dsl_output_struct.Data;
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

		
		
	otherwise
end	


return
end
