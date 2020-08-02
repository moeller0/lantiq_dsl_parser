function [ current_dsl_struct ] = lantiq_dsl_parser(data_source, data_fqn)
%LANTIQ_DSL_PARSER Summary of this function goes here
%   Detailed explanation goes here
% This works with matlab and octave (modulo the combining of existing
% plots)
% see LICENSE_lantiq in the root folder for licensing information
% Summary:
% This source code is distributed under a dual license of GPL and BSD (2-clause).
% Please choose the appropriate license for your intended usage.

% TODO:
%	scale the x_vecs correctly, by evaluating nGroupSize (WIP)
%		still needs for for the fixed 512 value sets?
%	add textual summary and error statistics page
%	allow to read from precanned text captures of dsl_cmd output?
%	collect statistics over collected per bin data (min, max, mode, ...)
%	refactor plotting into its own function
%	refactor the code to extract based on sub_cmd with the correct
%	arguments into a single function
%	allow to select multiple .mat files or a full directory and load all
%	files for history generation.

% the following two will make my lantiq router/modem reboot, probably bug
% in driver or fimware
%   g997dhling,    G997_DeltHLINGet
%   g997dhlinsg,   G997_DeltHLINScaleGet
% potentially promlematic: g997lpmcg

% dsl_cmd acs 2 : enforce resync
% . /lib/functions/lantiq_dsl.sh ; dsl_cmd acs 2
% ssh root@192.168.100.1 '. /lib/functions/lantiq_dsl.sh ; dsl_cmd acs 2'
% ssh root@192.168.100.1 '/etc/init.d/dsl_control status'

%#change SNR -2dbm (25=2,5dbm 40=4dbm etc.)
%locs 0 -20
%#force resynchronization
%acs 2"


if ~(isoctave)
	dbstop if error;
end
timestamps.(mfilename).start = tic;
fq_mfilename = mfilename('fullpath');
mfilepath = fileparts(fq_mfilename);

disp(mfilepath);


% either collect, store and process data, or load and process data

% data_source_string: dsl_cmd, load_single, load_all

if (~exist('data_source', 'var') || isempty(data_source)) && ((~exist('data_fqn', 'var') || isempty(data_fqn)))
	data_source = 'dsl_cmd';
	disp(['Defaulting to data_source ', data_source]);
else
	disp(['Requested data_source: ', data_source]);
end

if (~exist('data_fqn', 'var') || isempty(data_fqn))
	data_fqn = [];
end

% check sub_cmd for existence?
check_sub_cmd_exists = 1;

%
process_bitallocation = 0;
process_bitallocation2 = 1;
process_gainallocation = 0;
process_gainallocation2 = 1;
process_snrallocation = 0;
process_snrallocation2 = 1;
process_deltaSNR = 1;
process_deltaHLOG = 1;
process_deltaQLN = 1;

% plotting related configuration
plot_combined = 1;
DefaultPaperSizeType = 'A4_landscape';
output_rect_fraction = 1/2.54; % matlab's print will interpret values as INCH even for PaperUnit centimeter specified figures...
output_rect_fraction = 1;	% 2019a seems to have this fixed?

close_figures_at_end = 1;
InvisibleFigures = 0;
if (InvisibleFigures)
	figure_visibility_string = 'off';
else
	figure_visibility_string = 'on';
end

% most commands require specification of the direction
direction_list = [1, 0];	% 0: upload, 1: download
updir = 0;
updir_string = num2str(updir);
downdir = 1;
downdir_string = num2str(downdir);

deltdatatype_list = [1]; % zero seems to be not in use
deltdatatype_string = num2str(deltdatatype_list(1));

channel_list = [0];
%channel_string = num2str(channel_list(1));
HistoryInterval_list = [0, 1, 2];
DslMode_list = [0];

% COLORS
bit_color_up = [0 1 0];
bit_color_down = [0 0 1];
snr_color_up = [0 0.8 0];
snr_color_down = [254 233 23]/255;

out_format = 'pdf';
%out_format = 'png';

mat_prefix = 'lantiq_dsl_data';
out_dir = fullfile(mfilepath, out_format);
if ~isdir(out_dir)
	mkdir(out_dir);
end
mat_save_dir = fullfile(mfilepath, 'dsl_cmd_run_data');
if ~isdir(mat_save_dir)
	mkdir(mat_save_dir);
end


%ssh root@192.168.100.1 '. /lib/functions/lantiq_dsl.sh ; dsl_cmd g997racg 0 0'
ssh_dsl_cfg.lantiq_IP = '192.168.100.1';
ssh_dsl_cfg.lantig_user = 'root';
ssh_dsl_cfg.lantig_dsl_cmd_prefix = '. /lib/functions/lantiq_dsl.sh ; dsl_cmd';
ssh_dsl_cfg.ssh_command_stem = ['ssh ', ssh_dsl_cfg.lantig_user, '@', ssh_dsl_cfg.lantiq_IP];
dsl_sub_cmd_arg_string = [];

% make octave write disp/error output to screen immediately
if isoctave()
	more off
end

% for quick and dirty testing just call fn_call_dsl_cmd_via_ssh manually
%[ssh_status, dsl_cmd_output ] = fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, 'lsg', dsl_sub_cmd_arg_string );
%[ssh_status, dsl_cmd_output ] = fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, 'g997lig', dsl_sub_cmd_arg_string );

% restrict the data collection to a subset of the available sub-commands,
% if empty, collect all.
% just a small enough subset for quick and dirty monitoring
collect_sub_cmd_subset = {'g997bang', 'g997gang', 'g997sang', 'g997dsnrg', 'g997dhlogg', 'g997dqlng', 'ptsg', 'g997listrg', 'rtsg', 'osg'};
% everything
collect_sub_cmd_subset = {};
%collect_sub_cmd_subset = {'rtsg', 'osg', 'g997lig77'};
%collect_sub_cmd_subset = {'g997lig77'};


current_dsl_struct_list = {};
switch data_source
	case 'dsl_cmd'
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
		
		run_sub_cmd = 1;
		if check_sub_cmd_exists && ~isempty(collect_sub_cmd_subset)
			known_sub_cmd_ldx = ones(size(collect_sub_cmd_subset));
			for i_current_sub_cmd = 1 : length(collect_sub_cmd_subset)
				if ~(sum((ismember(current_dsl_struct.subcmd_list, collect_sub_cmd_subset{i_current_sub_cmd}))))
					disp(['Requested sub command: ', collect_sub_cmd_subset{i_current_sub_cmd}, ' seems not supported by ds_cmd/dsl_pipe, skipping.']);
					known_sub_cmd_ldx(i_current_sub_cmd) = 0;
				end
			end
			if (sum(known_sub_cmd_ldx))
				collect_sub_cmd_subset = {collect_sub_cmd_subset{find(known_sub_cmd_ldx)}};
			else
				run_sub_cmd = 0;
			end
		end
		
		if (run_sub_cmd)
			% DATA collection
			% zero ARG commands: dsmstatg cause issues, , 'g997dfr'
			zero_arg_sub_cmd_string_list = {'acog', 'asecg', 'asg', 'aufg', 'bpstg', 'bpsg', 'vig', 'vpcg', 'ptsg', 'dsmsg', 'dsmcg', 'pmcg', 'pmlictg', 'llcg', 'lsg', ...
				'meipocg', 'nsecg', 'g997xtusesg', 'g997xtusecg', 'g997upbosg', ...
				'rusg', 'sisg', 'tmsg', 'isg', 'lecg', ...
				'dbgmdg', 'dsmmcg', 'dsmstatg', 'fdsg', 'g997lacg', 'g997ltsg', 'g997lpmcg', 'g997pmsg', 'g997lisg'};
			current_sub_cmd_string_list = zero_arg_sub_cmd_string_list;
			if ~isempty(collect_sub_cmd_subset)
				%ismember(zero_arg_sub_cmd_string_list, collect_sub_cmd_subset)
				current_sub_cmd_string_list = current_sub_cmd_string_list(ismember(current_sub_cmd_string_list, collect_sub_cmd_subset));
			end
			%'t1413xtuorg', 't1413xtuovrg', 't1413xturrg', 't1413xturvrg' ???
			for i_zero_arg_sub_cmd_string = 1 : length(current_sub_cmd_string_list)
				dsl_sub_cmd_string = current_sub_cmd_string_list{i_zero_arg_sub_cmd_string};
				[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string)] = ...
					fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, []);
				if ~isempty(find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list)))
					current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name = current_dsl_struct.subcmd_names_list{find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list))};
				end
			end
			
			
			% commands with one argument: DslMode
			single_arg_sub_cmd_string_list = {'rccg', 'sicg', 'alig', 'locg'};
			% alig, locg,  really do not use DslMode, but require one parameter
			current_sub_cmd_string_list = single_arg_sub_cmd_string_list;
			if ~isempty(collect_sub_cmd_subset)
				%ismember(zero_arg_sub_cmd_string_list, collect_sub_cmd_subset)
				current_sub_cmd_string_list = current_sub_cmd_string_list(ismember(current_sub_cmd_string_list, collect_sub_cmd_subset));
			end
			for i_single_arg_sub_cmd_string = 1 : length(current_sub_cmd_string_list)
				dsl_sub_cmd_string = current_sub_cmd_string_list{i_single_arg_sub_cmd_string};
				for i_DslMode = 1:length(DslMode_list)
					cur_DslMode = DslMode_list(i_DslMode);
					cur_DslMode_string = [num2str(cur_DslMode)];
					[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['DslMode_', cur_DslMode_string])] = ...
						fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, cur_DslMode_string);
				end
				if ~isempty(find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list)))
					current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name = current_dsl_struct.subcmd_names_list{find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list))};
				end
			end
			
			
			% commands with one argument: HistoryInterval
			single_arg_sub_cmd_string_list = {'pmlicsg', 'pmlic1dg', 'pmlic15mg'};
			current_sub_cmd_string_list = single_arg_sub_cmd_string_list;
			if ~isempty(collect_sub_cmd_subset)
				%ismember(zero_arg_sub_cmd_string_list, collect_sub_cmd_subset)
				current_sub_cmd_string_list = current_sub_cmd_string_list(ismember(current_sub_cmd_string_list, collect_sub_cmd_subset));
			end
			for i_single_arg_sub_cmd_string = 1 : length(current_sub_cmd_string_list)
				dsl_sub_cmd_string = current_sub_cmd_string_list{i_single_arg_sub_cmd_string};
				for i_HistoryInterval = 1:length(HistoryInterval_list)
					cur_HistoryInterval = HistoryInterval_list(i_HistoryInterval);
					cur_HistoryInterval_string = [num2str(cur_HistoryInterval)];
					[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['HistoryInterval_', cur_HistoryInterval_string])] = ...
						fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, cur_HistoryInterval_string);
				end
				if ~isempty(find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list)))
					current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name = current_dsl_struct.subcmd_names_list{find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list))};
				end
			end
			
			
			% commands with one argument: Direction
			single_arg_sub_cmd_string_list = {'osg', 'g997bansg', 'g997bang', 'g997gansg', 'g997gang', 'g997sansg', 'g997sang', 'lfsg', 'g997lspbg', ...
				'g997lig', 'g997ansg', 'g997listrg', 'g997rasg', 'pmlsctg', 'pmlesctg', 'g997amlfcg', 'g997lfsg', 'rtsg', 'pmrtctg'};
			current_sub_cmd_string_list = single_arg_sub_cmd_string_list;
			if ~isempty(collect_sub_cmd_subset)
				%ismember(zero_arg_sub_cmd_string_list, collect_sub_cmd_subset)
				current_sub_cmd_string_list = current_sub_cmd_string_list(ismember(current_sub_cmd_string_list, collect_sub_cmd_subset));
			end
			for i_single_arg_sub_cmd_string = 1 : length(current_sub_cmd_string_list)
				dsl_sub_cmd_string = current_sub_cmd_string_list{i_single_arg_sub_cmd_string};
				for i_dir = 1:length(direction_list)
					cur_dir = direction_list(i_dir);
					cur_dir_string = [num2str(cur_dir)];
					[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', cur_dir_string])] = ...
						fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, cur_dir_string);
				end
				if ~isempty(find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list)))
					current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name = current_dsl_struct.subcmd_names_list{find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list))};
				end
			end
			
			% commands with two arguments: Direction and DeltDataType
			dual_arg_sub_cmd_string_list = {'g997dsnrg', 'g997dhlogg', 'g997dqlng', 'g997lsg','dsnrg'};
			current_sub_cmd_string_list = dual_arg_sub_cmd_string_list;
			if ~isempty(collect_sub_cmd_subset)
				%ismember(zero_arg_sub_cmd_string_list, collect_sub_cmd_subset)
				current_sub_cmd_string_list = current_sub_cmd_string_list(ismember(current_sub_cmd_string_list, collect_sub_cmd_subset));
			end
			for i_dual_arg_sub_cmd_string = 1 : length(current_sub_cmd_string_list)
				dsl_sub_cmd_string = current_sub_cmd_string_list{i_dual_arg_sub_cmd_string};
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
				if ~isempty(find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list)))
					current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name = current_dsl_struct.subcmd_names_list{find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list))};
				end
			end
			
			
			% commands with two arguments: Direction and HistoryInterval
			dual_arg_sub_cmd_string_list = {'pmlscsg', 'pmlsc1dg', 'pmlsc15mg', 'pmlescsg', 'pmlesc1dg', 'pmlesc15mg', 'pmrtc15mg', 'pmrtc1dg', 'pmrtcsg'};
			current_sub_cmd_string_list = dual_arg_sub_cmd_string_list;
			if ~isempty(collect_sub_cmd_subset)
				%ismember(zero_arg_sub_cmd_string_list, collect_sub_cmd_subset)
				current_sub_cmd_string_list = current_sub_cmd_string_list(ismember(current_sub_cmd_string_list, collect_sub_cmd_subset));
			end
			for i_dual_arg_sub_cmd_string = 1 : length(current_sub_cmd_string_list)
				dsl_sub_cmd_string = current_sub_cmd_string_list{i_dual_arg_sub_cmd_string};
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
				if ~isempty(find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list)))
					current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name = current_dsl_struct.subcmd_names_list{find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list))};
				end
			end
			
			
			% commands with two arguments: Channel and Direction
			dual_arg_sub_cmd_string_list = {'g997fpsg', 'g997csg', 'fpsg', 'g997cdrtcg', 'pmcctg', 'pmdpctg', 'g997amdpfcg', 'g997dpfsg'};
			current_sub_cmd_string_list = dual_arg_sub_cmd_string_list;
			if ~isempty(collect_sub_cmd_subset)
				%ismember(zero_arg_sub_cmd_string_list, collect_sub_cmd_subset)
				current_sub_cmd_string_list = current_sub_cmd_string_list(ismember(current_sub_cmd_string_list, collect_sub_cmd_subset));
			end
			for i_dual_arg_sub_cmd_string = 1 : length(current_sub_cmd_string_list)
				dsl_sub_cmd_string = current_sub_cmd_string_list{i_dual_arg_sub_cmd_string};
				
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
				if ~isempty(find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list)))
					current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name = current_dsl_struct.subcmd_names_list{find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list))};
				end
			end
			
			
			% commands with two arguments: DslMode and Direction
			dual_arg_sub_cmd_string_list = {'g997racg', 'lfcg'};
			current_sub_cmd_string_list = dual_arg_sub_cmd_string_list;
			if ~isempty(collect_sub_cmd_subset)
				%ismember(zero_arg_sub_cmd_string_list, collect_sub_cmd_subset)
				current_sub_cmd_string_list = current_sub_cmd_string_list(ismember(current_sub_cmd_string_list, collect_sub_cmd_subset));
			end
			for i_dual_arg_sub_cmd_string = 1 : length(current_sub_cmd_string_list)
				dsl_sub_cmd_string = current_sub_cmd_string_list{i_dual_arg_sub_cmd_string};
				for i_DslMode = 1:length(DslMode_list)
					cur_DslMode = DslMode_list(i_DslMode);
					cur_DslMode_string = [num2str(cur_DslMode)];
					for i_dir = 1:length(direction_list)
						cur_dir = direction_list(i_dir);
						cur_dir_string = [num2str(cur_dir)];
						[ssh_status, dsl_cmd_output, current_dsl_struct.(dsl_sub_cmd_string).(['DslMode_', cur_DslMode_string]).(['Direction_', cur_dir_string])] = ...
							fn_call_dsl_cmd_via_ssh( ssh_dsl_cfg, dsl_sub_cmd_string, [cur_DslMode_string, ' ', cur_dir_string]);
					end
					
				end
				if ~isempty(find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list)))
					current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name = current_dsl_struct.subcmd_names_list{find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list))};
				end
			end
			
			
			% commands with three arguments: Channel and Direction and HistoryInterval
			triple_arg_sub_cmd_string_list = {'pmdpcsg', 'pmdpc1dg', 'pmdpc15mg', 'pmccsg', 'pmcc1dg', 'pmcc15mg'};
			current_sub_cmd_string_list = triple_arg_sub_cmd_string_list;
			if ~isempty(collect_sub_cmd_subset)
				%ismember(zero_arg_sub_cmd_string_list, collect_sub_cmd_subset)
				current_sub_cmd_string_list = current_sub_cmd_string_list(ismember(current_sub_cmd_string_list, collect_sub_cmd_subset));
			end
			for i_dual_arg_sub_cmd_string = 1 : length(current_sub_cmd_string_list)
				dsl_sub_cmd_string = current_sub_cmd_string_list{i_dual_arg_sub_cmd_string};
				
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
				if ~isempty(find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list)))
					current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name = current_dsl_struct.subcmd_names_list{find(strcmp(dsl_sub_cmd_string, current_dsl_struct.subcmd_list))};
				end
			end
			
			% save data out
			disp(['Saving data to ', fullfile(mat_save_dir, [mat_prefix, '.', current_datetime, '.mat'])]);
			
			if isoctave()
				save(fullfile(mat_save_dir, [mat_prefix, '.', current_datetime, '.mat']), 'current_dsl_struct', '-mat7-binary');
			else
				save(fullfile(mat_save_dir, [mat_prefix, '.', current_datetime, '.mat']), 'current_dsl_struct');
			end
		end
		
	case 'load_single'
		%TODO: consider multi file picker?
		if exist('data_fqn', 'file')
			% file exists, just load it
			disp(['Loading requested file: ', data_fqn]);
			[lantiq_dsl_data_file_name, lantiq_dsl_data_file_dir] = fileparts(data_fqn);
		else
			if ~isempty(data_fqn)
				disp(['Requested data_fqn (', data_fqn,')is not a file, offering file selection dialog instead.']);
			end
			% load data instead
			[lantiq_dsl_data_file_name, lantiq_dsl_data_file_dir] = uigetfile({[mat_prefix, '.*.mat']}, 'Select the lantig dsl data file');
			if (lantiq_dsl_data_file_name == 0)
				disp('No lantiq dsl data file selected, exiting');
				return
			end
		end
		lantiq_dsl_data_file_FQN = fullfile(lantiq_dsl_data_file_dir, lantiq_dsl_data_file_name);
		disp(['Loading ', lantiq_dsl_data_file_FQN]);
		load(lantiq_dsl_data_file_FQN);
		
		
	case 'load_all'
		if exist('data_fqn', 'file')
			% file exists, just load it
			disp(['Requested data_fqn is a file not a directory: ', data_fqn, ' just taking the directory part']);
			[~, data_fqn] = fileparts(data_fqn);
		end
		if isdir(data_fqn)
			% file exists, just load it
			disp(['Loading all files from requested dir: ', data_fqn]);
			lantiq_dsl_data_file_dir = data_fqn;
		else
			% load data instead
			lantiq_dsl_data_file_dir = uigetdir(mat_save_dir, 'Select the lantig dsl data dir');
			if (lantiq_dsl_data_file_dir == 0)
				disp('No lantiq dsl data directory selected, exiting');
				return
			end
		end
		dsl_parser_mat_file_list = dir(fullfile(lantiq_dsl_data_file_dir, [mat_prefix, '*.mat']));
		if ~isempty(dsl_parser_mat_file_list)
			current_dsl_struct_list = cell(size(dsl_parser_mat_file_list));
			for i_file = 1 : length(dsl_parser_mat_file_list);
				lantiq_dsl_data_file_FQN = fullfile(lantiq_dsl_data_file_dir, dsl_parser_mat_file_list(i_file).name);
				disp(['Loading ', lantiq_dsl_data_file_FQN]);
				load(lantiq_dsl_data_file_FQN);
				current_dsl_struct_list{i_file} = current_dsl_struct;
			end
		else
			disp(['No proper lantiq_dsl_parser mat-file(s) (', mat_prefix, '*.mat) found, exiting.']);
			return
		end
	otherwise
		disp(['Encountered unhandled data_source: ', data_source, '; exiting.'])
		return
end

% make sure we have a proper list of current_dsl_structs even for the
% single session cases
if isempty(current_dsl_struct_list) && ~isempty(current_dsl_struct)
	current_dsl_struct_list{1} = current_dsl_struct;
end

% TODO check each sub_cmd for existence before trying to plot it...
dsl_sub_cmd_string = 'g997bansg';
if (process_bitallocation) && isfield(current_dsl_struct, dsl_sub_cmd_string)
	% g997bansg DIRECTION: 997_BitAllocationNscShortGet
	
	n_bits_download = sum(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).Data);
	n_bits_upload = sum(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).Data);
	
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


dsl_sub_cmd_string = 'g997bang';
if (process_bitallocation2) && isfield(current_dsl_struct, dsl_sub_cmd_string)
	% g997bansg DIRECTION: 997_BitAllocationNscShortGet
	
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


dsl_sub_cmd_string = 'g997gansg';
if (process_gainallocation) && isfield(current_dsl_struct, dsl_sub_cmd_string)
	
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


dsl_sub_cmd_string = 'g997gang';
if (process_gainallocation2) && isfield(current_dsl_struct, dsl_sub_cmd_string)
	
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


dsl_sub_cmd_string = 'g997sansg';
if (process_snrallocation) && isfield(current_dsl_struct, dsl_sub_cmd_string)
	% 	onlt 512 bins, but covering the whole frequency range (so one value for every 8 sub-carriers)
	
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


dsl_sub_cmd_string = 'g997sang';
if (process_snrallocation2) && isfield(current_dsl_struct, dsl_sub_cmd_string)
	% 	onlt 512 bins, but covering the whole frequency range (so one value for every 8 sub-carriers)
	
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

dsl_sub_cmd_string = 'g997dsnrg';
if (process_deltaSNR) && isfield(current_dsl_struct, dsl_sub_cmd_string)
	% 	This takes two aruments, nDirection and nDeltDataType, but only 1
	% 	for nDeltDataType
	
	g997dsnrg_fh = figure('Name', current_dsl_struct.(dsl_sub_cmd_string).dsl_sub_cmd_name);
	%TODO refactor plotting code to function
	% plot the bit allocations over bin, green for upload, blue for download (just copy the colors from AVM)
	ARG2 = ['DeltDataType_', deltdatatype_string];
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).(ARG2).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', updir_string]).(ARG2).Data, 'EdgeColor', snr_color_up, 'FaceColor', snr_color_up);
	hold on
	bar(current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data_xvec, current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).Data, 'EdgeColor', snr_color_down, 'FaceColor', snr_color_down);
	% plot pilot?
	current_dsl_struct.(dsl_sub_cmd_string).(['Direction_', downdir_string]).(ARG2).GroupSize
	if isfield(current_dsl_struct, 'ptsg') && isfield(current_dsl_struct.ptsg, 'PilotIndex')
		pilot_xvec_list = current_dsl_struct.ptsg.PilotIndex;
		disp('Size of pilot_xvec_list');
		disp(size(pilot_xvec_list));
		plot([pilot_xvec_list(1), pilot_xvec_list(1)], [-70 70], 'Color', [1 0 0]);
		%plot([pilot_xvec_list(2), pilot_xvec_list(2)], [-70 70], 'Color', [1 0 0]);
	end
	
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


dsl_sub_cmd_string = 'g997dhlogg';
if (process_deltaHLOG) && isfield(current_dsl_struct, dsl_sub_cmd_string)
	% 	This takes two aruments, nDirection and nDeltDataType, but only 1
	% 	for nDeltDataType
	
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


dsl_sub_cmd_string = 'g997dqlng';
if (process_deltaQLN) && isfield(current_dsl_struct, dsl_sub_cmd_string)
	% 	This takes two aruments, nDirection and nDeltDataType, but only 1
	% 	for nDeltDataType
	
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
if (plot_combined) && ~isoctave()
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


timestamps.(mfilename).end = toc(timestamps.(mfilename).start);
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end), ' seconds.']);

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
		if (strcmp(cur_struct_key(2), '_'))
			cur_struct_key(1) = 'N';
		else
			cur_struct_key(1) = [];
		end
	end
	% get rid of taboo characters in the key name so that the key can be
	% turned into a matlab structure fieldname
	cur_struct_key = sanitize_name_for_matlab(cur_struct_key);
	
	% remove the now trailing key_value_separator
	if strcmp(unprocessed_string(1), key_value_separator)
		unprocessed_string(1) = [];
	end
	
	%g997listrg results can contain spaces/char(10) inside the string values
	% nReturn=0 nDirection=1 G994VendorID="..BDCM.." SystemVendorID="..BDCM.."
	% VersionNumber="v12.03.90      " SerialNumber="eq nr port:33  oemid softwarerev" SelfTestResult=0 XTSECapabilities=(00,00,00,00,00,00,00,02)
	if ismember(cur_key, {'G994VendorID', 'SystemVendorID', 'VersionNumber', 'SerialNumber'}) && strcmp(unprocessed_string(1), '"')
		quote_idx = strfind(unprocessed_string, '"');
		return_struct.(cur_struct_key) = strtrim(unprocessed_string(quote_idx(1)+1:quote_idx(2)-1));
		unprocessed_string = unprocessed_string(quote_idx(2)+1:end);
		continue
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
		if isfield(return_struct, 'Format')
			return_struct = fn_convert_and_add_nData_to_struct(return_struct, cur_value, return_struct.Format);
		elseif isfield(return_struct, 'Length')
			% special case 'alig', which returns 8 values as nData
			return_struct.Data = str2num(strtrim(cur_value));
			return_struct.Data_name = 'alig';
		end
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

%TODO check ssh status!
if (ssh_status ~= 0)
	disp(['ssh exited with errors:', ssh_status, '; returning']);
	return
end

parsed_dsl_output_struct.dsl_sub_cmd_string = dsl_sub_cmd_string;
parsed_dsl_output_struct.dsl_sub_cmd_arg_string = dsl_sub_cmd_arg_string;

% this currently is incompatible with the parser
% if strcmp(dsl_sub_cmd_string, 'g997listrg')
% 	parsed_dsl_output_struct.input_string = dsl_cmd_output_string;
% 	disp('g997listrg: parser incompatible, just returning the dsl_cmd_output_string as .input_string for now');
% 	return
% end


parsed_dsl_output_struct = fn_parse_lantiqdsl_cmd_output(dsl_cmd_output_string);

% check nReturn, if not 0 display error message
if isfield(parsed_dsl_output_struct, 'Return')
	ret_val = parsed_dsl_output_struct.Return;
	return_code = fn_find_error_name_by_value(ret_val);
	parsed_dsl_output_struct.return_code = return_code;
	
	if (ret_val ~= 0)
		disp(['Calling ', lantig_dsl_cmd_string, ' resulted in return code: ', num2str(ret_val), ': ', return_code]);
		if ~isempty(regexp(dsl_cmd_output_string, 'wrong number of parameters'))
			disp(dsl_cmd_output_string);
		end
	end
else
	% the help command does not return nReturn
	if ~strcmp(dsl_sub_cmd_string, 'help')
		%error(['No return value from dsl_cmd received, FIXME.']);
		disp(['No return value from dsl_cmd received, FIXME.']);
		return
	end
end

% dsl_sub_cmd_string specific processing
switch dsl_sub_cmd_string
	case 'lsg'
		% get a human readable name for the LineState
		if isfield(parsed_dsl_output_struct, 'LineState') && (sum(isnan(parsed_dsl_output_struct.LineState)) == 0)
			parsed_dsl_output_struct.LineState_name = fn_find_dsl_state_name_by_value( parsed_dsl_output_struct.LineState );
		else
			disp('ERROR: Expected parsed_dsl_output_struct.LineState field does not seem to exist or is NaN');
			parsed_dsl_output_struct
		end
	case 'g997lig'
		% the string version of this, g997listrg does not carry T.35 code
		% or Vendor specific indformation, but '2E'/46 values at those
		% positions instead
		% see 9.3.3.1 Vendor ID information block in
		% ITU-T G.994.1 "Handshake procedures for digital subscriber line
		% transceivers"
		% G994VendorID: first two bytes/chars ITU T.35 country code, next 4
		% byte vendor code, fnal two bytes vendor specific information
		G994VendorID_code = parsed_dsl_output_struct.G994VendorID;
		parsed_dsl_output_struct.G994VendorID_T35Code_hexstring = G994VendorID_code(2:6); % if the first byte is not all zero, the second byte has to be all zero
		parsed_dsl_output_struct.G994VendorID_VendorCode_hexstring = G994VendorID_code(8:18);
		parsed_dsl_output_struct.G994VendorID_VendorCode_string = fn_convert_string_of_hex_to_string(G994VendorID_code(8:18), ',');
		parsed_dsl_output_struct.G994VendorID_VendorSpecificInformation_hexstring = G994VendorID_code(20:end-1);
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
			parsed_dsl_output_struct.Data_name = parsed_dsl_output_struct.Data_name(1:end);
			
		case {'g997sansg', 'g997sang', 'g997dsnrg'}
			% mask out the FF/255 bins, as FF is the "no measurement could be done" marker
			parsed_dsl_output_struct.ignore_bin_marker = 255;
			parsed_dsl_output_struct.ignore_bin_idx = find(parsed_dsl_output_struct.Data == parsed_dsl_output_struct.ignore_bin_marker);
			
			% T-REC-G.997.1-201902: 7.5.1.28.3 Downstream SNR(f) (SNRpsds)
			% This parameter is an array of real values in decibels for downstream SNR(f). Each array entry represents
			% the SNR(f = i � SNRGds � ?f) value for a particular subcarrier group index i, ranging from 0 to MIN(NSds,511).
			% The SNR(f) is represented as (?32 + snr(i)/2), where snr(i) is an unsigned integer in the range from 0 to 254.
			% A special value indicates that no measurement could be done for this subcarrier group because it is out of the
			% passband or that the SNR is out of range to be represented. The same SNRpsds format shall be applied to ITU-T G.992.3
			% and ITU-T G.992.5 Annex C FEXT SNRpsds and NEXT SNRpsds.
			parsed_dsl_output_struct.Data = (parsed_dsl_output_struct.Data * 0.5) - 32;
			parsed_dsl_output_struct.Data(parsed_dsl_output_struct.ignore_bin_idx) = 0;
			parsed_dsl_output_struct.Data_name = [parsed_dsl_output_struct.Data_name(1:end), ' [dB]'];
			
		case 'g997dhlogg'
			parsed_dsl_output_struct.ignore_bin_marker = 1023;
			parsed_dsl_output_struct.ignore_bin_idx = find(parsed_dsl_output_struct.Data == parsed_dsl_output_struct.ignore_bin_marker);
			
			% T-REC-G.997.1-201902: 7.5.1.26.6 Downstream H(f) logarithmic representation (HLOGpsds)
			% This parameter is an array of real values in decibels for downstream Hlog(f). Each array entry represents
			% the real Hlog(f = i � HLOGGds � ?f) value for a particular subcarrier group subcarrier index i, ranging
			% from 0 to MIN(NSds,511). The real Hlog(f) value is represented as (6 ? m(i)/10), where m(i) is an
			% unsigned integer in the range from 0 to 1 022. A special value indicates that no measurement could be
			% done for this subcarrier group because it is out of the passband or that the attenuation is out of range to be represented.
			parsed_dsl_output_struct.Data = 6 - (parsed_dsl_output_struct.Data / 10);
			parsed_dsl_output_struct.Data(parsed_dsl_output_struct.ignore_bin_idx) = NaN;
			parsed_dsl_output_struct.Data_name = [parsed_dsl_output_struct.Data_name(1:end), ' [dB]'];
			
		case 'g997dqlng'
			parsed_dsl_output_struct.ignore_bin_marker = 255;
			parsed_dsl_output_struct.ignore_bin_idx = find(parsed_dsl_output_struct.Data == parsed_dsl_output_struct.ignore_bin_marker);
			
			% T-REC-G.997.1-201902: 7.5.1.27.3 Downstream QLN(f) (QLNpsds)
			% This parameter is an array of real values in decibels with reference to 1 mW per hertz for
			% downstream QLN(f). Each array entry represents the QLN(f = i � QLNGds � ?f) value for a particular
			% subcarrier group index i, ranging from 0 to MIN(NSds,511). The QLN(f) is represented as (?23 ? n(i)/2), where
			% n(i) is an unsigned integer in the range from 0 to 254. A special value indicates that no measurement could
			% be done for this subcarrier group because it is out of the passband or that the noise PSD is out of range to be represented.
			% The same QLNpsds format shall be applied to ITU-T G.992.3 and ITU-T G.992.5 Annex C FEXT QLNpsds and NEXT QLNpsds.
			parsed_dsl_output_struct.Data = -23 - (parsed_dsl_output_struct.Data / 2);
			parsed_dsl_output_struct.Data(parsed_dsl_output_struct.ignore_bin_idx) = NaN;
			parsed_dsl_output_struct.Data_name = [parsed_dsl_output_struct.Data_name(1:end), ' [dB, ref 1mW/Hz]'];
			
			
		case {'g997bang', 'g997bansg'}
			parsed_dsl_output_struct.Data_name = parsed_dsl_output_struct.Data_name(1:end);
			
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
if (ismember(version('-release'), {'2016a', '2019a'}))
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
		
	case 'A4_landscape'
		left_edge_cm = 0.05;
		bottom_edge_cm = 0.05;
		A4_h_cm = 21.0;
		A4_w_cm = 29.7;
		rect_w = (A4_w_cm - 2*left_edge_cm) * fraction;
		rect_h = ((A4_h_cm * 610/987) - 2*bottom_edge_cm) * fraction; % 610/987 approximates the golden ratio
		output_rect = [left_edge_cm bottom_edge_cm rect_w rect_h];	% left, bottom, width, height
		%output_rect = [1.0 2.0 27.7 12.0];
		set(gcf_h, 'PaperSize', [rect_w+2*left_edge_cm*fraction rect_h+2*bottom_edge_cm*fraction], 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters');
		
		
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

function in = isoctave()
persistent inout;

if isempty(inout),
	inout = exist('OCTAVE_VERSION','builtin') ~= 0;
end;
in = inout;

return;
end


function [ dsl_state_name, line_state_struct ] = fn_find_dsl_state_name_by_value( dsl_state_value )
% These are defined in drv_dsl_cpe_api.h
% dsl_state_value: can be either a string like 801 or 0x801 or a decimal
% value
orig_dsl_state_value = dsl_state_value;

if ischar(dsl_state_value)
	if strcmp(dsl_state_value(2), 'x')
		dsl_state_value = dsl_state_value(3:end);
	end
	dsl_state_value = hex2dec(dsl_state_value);
	
end

line_state_struct = [];

% /******************************************************************************
%
%                               Copyright (c) 2014
%                             Lantiq Deutschland GmbH
%
%   For licensing information, see the file 'LICENSE_lantiq' in the root folder of
%   this software module.
%
% ******************************************************************************/
%
%    /** Line State is not initialized!
%        This state only exists within software. During link activation procedure
%        it will be set initially before any DSL firmware response was received
%        within FW download sequence. */
linestate_strings.DSL_LINESTATE_NOT_INITIALIZED = '0x00000000';
%    /** Line State: EXCEPTION.
%        Entered upon an initialization or showtime failure or whenever a regular
%        state transition cannot be followed.
%        Corresponds to the following device specific state
%        - Modem Status: FAIL_STATE */
linestate_strings.DSL_LINESTATE_EXCEPTION = '0x00000001';
%    /** Line State: NOT_UPDATED.
%        Internal line state that indicates that the autoboot thread is
%        stopped. */
linestate_strings.DSL_LINESTATE_NOT_UPDATED = '0x00000010';
%    /** Line State: DISABLED.
%        This line state indicates that the line has been deactivated for one of
%        the following reasons
%        - line "tear down" has been performed within context of activated on-chip
%          bonding handling (currently only valid for XWAY(TM) VRX200 or XWAY(TM)
%          VRX300). DSL firmware was started in dual-port mode but the CO
%          indicated that bonding is not used (remote PAF_Enable status is false).
%        - line was manually disabled by the user via following command
%          \ref DSL_FIO_AUTOBOOT_CONTROL_SET with nCommand equals
%          \ref DSL_AUTOBOOT_CTRL_DISABLE. */
linestate_strings.DSL_LINESTATE_DISABLED = '0x00000020';
%    /** Line State: IDLE_REQUEST.
%        Interim state between deactivation of line and the time this user request
%        is acknowledged by the firmware. */
linestate_strings.DSL_LINESTATE_IDLE_REQUEST = '0x000000FF';
%    /** Line State: IDLE.
%        Corresponds to the following device specific state
%        - Modem Status: RESET_STATE */
linestate_strings.DSL_LINESTATE_IDLE = '0x00000100';
%    /** Line State: SILENT_REQUEST.
%        Interim state between activation of line and the time this user request
%        is acknowledged by the firmware. */
linestate_strings.DSL_LINESTATE_SILENT_REQUEST = '0x000001FF';
%    /** Line State: SILENT
%        First State after a link initiation has been triggered. The CPE is
%        sending handshake tones (silence from CO side).
%        Corresponds to the following device specific state
%        - Modem status: READY_STATE */
linestate_strings.DSL_LINESTATE_SILENT = '0x00000200';
%    /** Line State: HANDSHAKE
%        Entered upon detection of a far-end GHS signal.
%        Corresponds to the following device specific state
%        - Modem status: GHS_STATE */
linestate_strings.DSL_LINESTATE_HANDSHAKE = '0x00000300';
%    /** Line State: BONDING_CLR
%        Entered for the preparation and sending of a CLR message in case of
%        bonding. The related bonding handshake primitives are implemented within
%        dsl_cpe_control.
%        Corresponds to the following device specific state
%        - ADSL only patforms: Not supported
%        - XWAY(TM) VRX200 and XWAY(TM) VRX300: Modem status:
%          GHS_BONDING_CLR_STATE */
linestate_strings.DSL_LINESTATE_BONDING_CLR = '0x00000310';
%    /** Line State: T1413.
%        Entered upon detection of a far-end ANSI T1.413 signal.
%        Corresponds to the following device specific state
%        - Modem status: T1413_STATE */
linestate_strings.DSL_LINESTATE_T1413 = '0x00000370';
%    /** Line State: FULL_INIT.
%        Entered upon entry into the training phase of initialization following
%        GHS start-up.
%        Corresponds to the following device specific state
%        - Modem status: FULLINIT_STATE */
linestate_strings.DSL_LINESTATE_FULL_INIT = '0x00000380';
%    /** Line State: SHORT INIT. */
linestate_strings.DSL_LINESTATE_SHORT_INIT_ENTRY = '0x000003C0';
%    /** Line State: DISCOVERY.
%        This state is a substate of FULL_INIT and is not reported */
linestate_strings.DSL_LINESTATE_DISCOVERY = '0x00000400';
%    /** Line State: TRAINING.
%        This state is a substate of FULL_INIT and is not reported */
linestate_strings.DSL_LINESTATE_TRAINING = '0x00000500';
%    /** Line State: ANALYSIS.
%        This state is a substate of FULL_INIT and is not reported */
linestate_strings.DSL_LINESTATE_ANALYSIS = '0x00000600';
%    /** Line State: EXCHANGE.
%        This state is a substate of FULL_INIT and is not reported */
linestate_strings.DSL_LINESTATE_EXCHANGE = '0x00000700';
%    /** Line State: SHOWTIME_NO_SYNC.
%        Showtime is reached but TC-Layer is not in sync.
%        Corresponds to the following device specific state
%        - Modem status: STEADY_STATE_TC_NOSYNC */
linestate_strings.DSL_LINESTATE_SHOWTIME_NO_SYNC = '0x00000800';
%    /** Line State: SHOWTIME_TC_SYNC.
%        Showtime is reached and TC-Layer is in sync. Modem is fully
%        operational.
%        Corresponds to the following device specific state
%        - Modem status: STEADY_STATE_TC_SYNC */
linestate_strings.DSL_LINESTATE_SHOWTIME_TC_SYNC = '0x00000801';
%    /** Line State: ORDERLY_SHUTDOWN_REQUEST.
%       Interim state between request (from API) to deactivation the line and
%       acknowledgment from the DSL Firmware by indicating 'orderly local
%       shutdown' or fail respective exception state.
%       \note Due to timing limitations on updating the DSL Firmware line state the
%             possible next line state could be whether "orderly shutdown"
%             acknowledge (\ref DSL_LINESTATE_ORDERLY_SHUTDOWN) or directly the
%             final fail/exception state (\ref DSL_LINESTATE_EXCEPTION) */
linestate_strings.DSL_LINESTATE_ORDERLY_SHUTDOWN_REQUEST = '0x0000085F';
%    /** Line State: ORDERLY_SHUTDOWN.
%       This status is indicated by the DSL Firmware during orderly local link
%       shutdown sequence. DSL link is down in this state and the next expected
%       line state will be fail respective exception state (\ref
%    linestate_strings.DSL_LINESTATE_EXCEPTION).
%       Corresponds to the following device specific state
%        - ADSL only platforms: Currently not supported
%        - XWAY(TM) VRX200 and XWAY(TM) VRX300: Modem status: PRE_FAIL_STATE */
linestate_strings.DSL_LINESTATE_ORDERLY_SHUTDOWN = '0x00000860';
%    /** Line State: FASTRETRAIN.
%        Currently not supported. */
linestate_strings.DSL_LINESTATE_FASTRETRAIN = '0x00000900';
%    /** Line State: LOWPOWER_L2. */
linestate_strings.DSL_LINESTATE_LOWPOWER_L2 = '0x00000A00';
%    /** Line State: DIAGNOSTIC ACTIVE. */
linestate_strings.DSL_LINESTATE_LOOPDIAGNOSTIC_ACTIVE = '0x00000B00';
%    /** Line State: DIAGNOSTIC_DATA_EXCHANGE. */
linestate_strings.DSL_LINESTATE_LOOPDIAGNOSTIC_DATA_EXCHANGE = '0x00000B10';
%    /** This status is used if the DELT data is already available within the
%        firmware but has to be updated within the DSL API data elements. If
%        the line is within this state the data within a DELT element is NOT
%        consistent and shall be NOT read out by the upper layer software.  */
linestate_strings.DSL_LINESTATE_LOOPDIAGNOSTIC_DATA_REQUEST = '0x00000B20';
%    /** Line State: DIAGNOSTIC COMPLETE */
linestate_strings.DSL_LINESTATE_LOOPDIAGNOSTIC_COMPLETE = '0x00000C00';
%    /** Line State: RESYNC. */
linestate_strings.DSL_LINESTATE_RESYNC            = '0x00000D00';
%    /* *********************************************************************** */
%    /* *** Line States that may bundle various sates that are not handled  *** */
%    /* *** in detail at the moment                                         *** */
%    /* *********************************************************************** */
%    /** Line State: TEST.
%        Common test status may include various test states */
linestate_strings.DSL_LINESTATE_TEST = '0x01000000';
%    /** Line State: any loop activated. */
linestate_strings.DSL_LINESTATE_TEST_LOOP = '0x01000001';
%    /** Line State: TEST_REVERB. */
linestate_strings.DSL_LINESTATE_TEST_REVERB = '0x01000010';
%    /** Line State: TEST_MEDLEY. */
linestate_strings.DSL_LINESTATE_TEST_MEDLEY = '0x01000020';
%    /** Line State: TEST_SHOWTIME_LOCK. */
linestate_strings.DSL_LINESTATE_TEST_SHOWTIME_LOCK = '0x01000030';
%    /** Line State: TEST_QUIET. */
linestate_strings.DSL_LINESTATE_TEST_QUIET = '0x01000040';
%    /** Line State: FILTERDETECTION_ACTIVE. */
linestate_strings.DSL_LINESTATE_TEST_FILTERDETECTION_ACTIVE = '0x01000050';
%    /** Line State: FILTERDETECTION_COMPLETE. */
linestate_strings.DSL_LINESTATE_TEST_FILTERDETECTION_COMPLETE = '0x01000060';
%     /** Line State: LOWPOWER_L3. */
linestate_strings.DSL_LINESTATE_LOWPOWER_L3 = '0x02000000';
%    /** Line State: All line states that are not assigned at the moment */
linestate_strings.DSL_LINESTATE_UNKNOWN = '0x03000000';

line_state_struct.linestate_strings = linestate_strings;

% create two list of state_name and state_value (in decimal)


line_states_list = fieldnames(linestate_strings);
state_name_list = cell(size(line_states_list));
state_value_list = zeros(size(line_states_list));

for i_state = 1 : length(line_states_list)
	cur_state_name_string = line_states_list{i_state};
	cur_state_name = regexprep(cur_state_name_string, '^DSL_LINESTATE_', '');
	state_name_list{i_state} = cur_state_name;
	state_value_list(i_state) = hex2dec(linestate_strings.(cur_state_name_string)(3:end)); % 0xNNN chop off the leading 0x string before conversion
	
	if (dsl_state_value == state_value_list(i_state))
		dsl_state_name = cur_state_name;
	end
end
line_state_struct.state_name_list = state_name_list;
line_state_struct.state_value_list = state_value_list;

return
end


function [ error_name ] = fn_find_error_name_by_value( error_value )
persistent error_code_struct

% default to the hopefully common case
error_name = 'DSL_SUCCESS';
if (error_value == 0)
	return
end

if isempty(error_code_struct)
	error_code_struct = fn_get_dsl_error_code_struct();
end

% now find error_name and error_desription
error_idx = find(error_code_struct.error_value_list == error_value);

if isempty(error_idx)
	disp(['ERROR: Unknown error value (', num2str(error_value),') encountered.']);
	error_code_struct.error_value_list(end+1) = error_value;
	error_code_struct.error_name_list{end+1} = "Unknown error value";
end

if (length(error_idx) > 1)
	error(['Error value (', num2str(error_value),') not unique.']);
end
error_name = error_code_struct.error_name_list{error_idx};

return
end


function [ error_code_struct ] = fn_get_dsl_error_code_struct()

error_code_struct = [];

error_name_list = [];
error_value_list = [];


% /******************************************************************************
%
%                               Copyright (c) 2014
%                             Lantiq Deutschland GmbH
%
%   For licensing information, see the file 'LICENSE_lantiq' in the root folder of
%   this software module.
%
% ******************************************************************************/
%
% /**
%    Defines all possible error codes.
%    Error codes are negative, warning codes are positive and success has the
%    value 0.
%    \note If there are more than one warnings during processing of one DSL CPE API
%          call the warning with the lowest value will be returned
% */
%    /* *********************************************************************** */
%    /* *** Error Codes Start here !                                        *** */
%    /* *********************************************************************** */
%
%    /* *********************************************************************** */
%    /* *** Error Codes for bonding functionality                           *** */
%    /* *********************************************************************** */
%    /** Command/feature can not be performed because only one line can be in
%        showtime in case of disabled bonding on the CO side. This line has been
%        disabled because the other line has reached a line state that is equal
%        or bigger than \ref DSL_LINESTATE_FULL_INIT.
%        To activate this line again please do one of the following actions
%        - in case of *on-chip* bonding scenario, use command
%          \ref DSL_FIO_AUTOBOOT_CONTROL_SET with nCommand equals
%          \ref DSL_AUTOBOOT_CTRL_RESTART_FULL on any line (CLI: "acs [x] 6").
%          This will start both lines.
%        - use command \ref DSL_FIO_AUTOBOOT_CONTROL_SET with nCommand equals
%          \ref DSL_AUTOBOOT_CTRL_DISABLE on the other line (that is not
%          disabled, CLI: "acs [x] 4").
%          Afterwards both lines are disabled and can be enabled again
%          1) individually by using command \ref DSL_FIO_AUTOBOOT_CONTROL_SET with
%          nCommand equals \ref DSL_AUTOBOOT_CTRL_ENABLE or
%          \ref DSL_AUTOBOOT_CTRL_RESTART (CLI: "acs [x] 5" or "acs [x] 2")
%          2) all togther by using command \ref DSL_FIO_AUTOBOOT_CONTROL_SET with
%          nCommand equals \ref DSL_AUTOBOOT_CTRL_RESTART_FULL on any line
%          (CLI: "acs [x] 6"), only in case of *on-chip* bonding.
%        \note The value [x] includes the optional line/device parameter that is
%              used only in case of bonding. */
error_name_list{end+1} = 'DSL_ERR_BND_REMOTE_PAF_DISABLED';
error_value_list(end+1) = -502;
%    /** Command/feature is only supported if bonding functionality is enabled.
%        Please use the command \ref DSL_FIO_BND_CONFIG_SET with bPafEnable
%        equals DSL_TRUE to enable bonding functionality. */
error_name_list{end+1} = 'DSL_ERR_BND_ONLY_SUPPORTED_WITH_BONDING_ENABLED';
error_value_list(end+1) = -501;
%    /** Command/feature can not be performed because the firmware does not
%        support bonding functionality. */
error_name_list{end+1} = 'DSL_ERR_BND_NOT_SUPPORTED_BY_FIRMWARE';
error_value_list(end+1) = -500;

%    /* *********************************************************************** */
%    /* *** Error Codes for configuration parameter consistency check       *** */
%    /* *********************************************************************** */
%    /** The configuration of the TC-Layer does not fit to the bonding
%        configuration. Due to the fact that PAF bonding is only supported within
%        PTM/EFM TC-Layer please note that it is not allowed to select only the
%        \ref DSL_TC_ATM TC-Layer in case of bonding is enabled
%        (CLI: "BND_ConfigSet"/"bndcs").
%        This error will occur in case of bonding is enabled and user
%        configuration of \ref DSL_TC_ATM is applied or vice versa. The
%        configuration is rejected, means that the original configuration will
%        be kept. */
error_name_list{end+1} = 'DSL_ERR_CONFIG_BND_VS_TCLAYER';
error_value_list(end+1) = -401;
%    /** parameter out of range */
error_name_list{end+1} = 'DSL_ERR_PARAM_RANGE';
error_value_list(end+1) = -400;
%
%    /* *********************************************************************** */
%    /* *** Error Codes for EOC handler                                     *** */
%    /* *********************************************************************** */
%    /** transmission error */
error_name_list{end+1} = 'DSL_ERR_CEOC_TX_ERR';
error_value_list(end+1) = -300;
%
%    /* *********************************************************************** */
%    /* *** Error Codes for modem handling                                  *** */
%    /* *********************************************************************** */
%    /** Modem is not ready */
error_name_list{end+1} = 'DSL_ERR_MODEM_NOT_READY';
error_value_list(end+1) = -201;
%
%    /* *********************************************************************** */
%    /* *** Error Codes for Autoboot handler                                *** */
%    /* *********************************************************************** */
%    /** Autoboot handling has been disabled.
%        \note Also refer to description of \ref DSL_LINESTATE_DISABLED */
error_name_list{end+1} = 'DSL_ERR_AUTOBOOT_DISABLED';
error_value_list(end+1) = -103;
%    /** Autoboot thread is not started yet */
error_name_list{end+1} = 'DSL_ERR_AUTOBOOT_NOT_STARTED';
error_value_list(end+1) = -102;
%    /** Autoboot thread is busy */
error_name_list{end+1} = 'DSL_ERR_AUTOBOOT_BUSY';
error_value_list(end+1) = -101;
%
%    /* *********************************************************************** */
%    /* *** Error Codes for IOCTL handler                                   *** */
%    /* *********************************************************************** */
%    /** An error occurred during execution of a low level (MEI BSP) driver
%        function */
error_name_list{end+1} = 'DSL_ERR_LOW_LEVEL_DRIVER_ACCESS';
error_value_list(end+1) = -32;
%    /** Invalid parameter is passed */
error_name_list{end+1} = 'DSL_ERR_INVALID_PARAMETER';
error_value_list(end+1) = -31;
%
%    /* *********************************************************************** */
%    /* *** Common Error Codes                                              *** */
%    /* *********************************************************************** */
% from https://dev.iopsys.eu/intel/drv_dsl_cpe_api/blob/master/src/include/drv_dsl_cpe_api_error.h
%    /** The command is not allowed in current autoboot state. */
error_name_list{end+1} = 'DSL_ERR_NOT_SUPPORTED_IN_CURRENT_AUTOBOOT_STATE';
error_value_list(end+1) = -46;
%    /** The requested values are not supported in the upstream
%       (US) direction */
error_name_list{end+1} = 'DSL_ERR_NOT_SUPPORTED_IN_US_DIRECTION';
error_value_list(end+1) = -45;
%    /** The requested values are not supported in the downstream
%       (DS) direction */
error_name_list{end+1} = 'DSL_ERR_NOT_SUPPORTED_IN_DS_DIRECTION';
error_value_list(end+1) = -44;

%    /** invalid DSL mode */
error_name_list{end+1} = 'DSL_ERR_NO_FIRMWARE_LOADED';
error_value_list(end+1) = -43;
%    /** Data is currently not available.
%        Update handling for the relevant interval was not completed before and
%        is just in progress. Please request the data at a later point in time
%        again and/or wait for the according "data available" event, for
%        example \ref DSL_EVENT_S_FE_TESTPARAMS_AVAILABLE */
error_name_list{end+1} = 'DSL_ERR_DATA_UPDATE_IN_PROGRESS';
error_value_list(end+1) = -42;
%    /** invalid DSL mode */
error_name_list{end+1} = 'DSL_ERR_DSLMODE';
error_value_list(end+1) = -41;
%    /** The requested values are not supported in the current VDSL mode */
error_name_list{end+1} = 'DSL_ERR_NOT_SUPPORTED_IN_CURRENT_VDSL_MODE';
error_value_list(end+1) = -40;
%    /** Real time trace unavailable */
error_name_list{end+1} = 'DSL_ERR_RTT_NOT_AVAILABLE';
error_value_list(end+1) = -39;
%    /** Feature unavailable in case of disabled retransmission.
%        This error can happen in the following cases
%        - The retransmission feature is not enabled on CPE side.
%          The feature can be enabled by using configuration parameter
%          'bReTxEnable' within context of ioctl
%          \ref DSL_FIO_LINE_FEATURE_CONFIG_SET
%        - The feature is enabled on CPE side but the CO side does not support it
%          or has not enabled it.
%          This state can be checked by getting retransmission status value
%          'bReTxEnable' within context of ioctl
%          \ref DSL_FIO_LINE_FEATURE_STATUS_GET that needs to be called in
%          showtime. */
error_name_list{end+1} = 'DSL_ERR_RETRANSMISSION_DISABLED';
error_value_list(end+1) = -38;
%    /** CPE triggered L3 request has been rejected by the CO side,
%        reason - not desired*/
error_name_list{end+1} = 'DSL_ERR_L3_REJECTED_NOT_DESIRED';
error_value_list(end+1) = -37;
%    /** ioctl not supported by DSL CPE API.
%        The reason might be because of current configure options. */
error_name_list{end+1} = 'DSL_ERR_IOCTL_NOT_SUPPORTED';
error_value_list(end+1) = -36;
%    /** Feature or functionality is not defined by standards. */
error_name_list{end+1} = 'DSL_ERR_NOT_SUPPORTED_BY_DEFINITION';
error_value_list(end+1) = -35;
%    /** DSL CPE API not initialized yet*/
error_name_list{end+1} = 'DSL_ERR_NOT_INITIALIZED';
error_value_list(end+1) = -34;
%    /** The requested values are not supported in the current
%        ADSL mode or Annex*/
error_name_list{end+1} = 'DSL_ERR_NOT_SUPPORTED_IN_CURRENT_ADSL_MODE_OR_ANNEX';
error_value_list(end+1) = -33;
%    /** The DELT data is not available within DSL CPE API.
%        Whether the diagnostic complete state was never reached (no successful
%        completion of DELT measurement) or the DELT data was already deleted
%        by using ioctl \ref DSL_FIO_G997_DELT_FREE_RESOURCES */
error_name_list{end+1} = 'DSL_ERR_DELT_DATA_NOT_AVAILABLE';
error_value_list(end+1) = -30;
%    /** The event that should be processed are not active for the current
%        instance */
error_name_list{end+1} = 'DSL_ERR_EVENTS_NOT_ACTIVE';
error_value_list(end+1) = -29;
%    /** During CPE triggered L3 request an error occurred that could not be
%        classified more in detail. Please check if the L3 entry is allowed on
%        the CO side.*/
error_name_list{end+1} = 'DSL_ERR_L3_UNKNOWN_FAILURE';
error_value_list(end+1) = -28;
%    /** CPE triggered L3 request timed out */
error_name_list{end+1} = 'DSL_ERR_L3_NOT_IN_L0';
error_value_list(end+1) = -27;
%    /** During CPE triggered L3 request the CO side has returned the error
%        that the line is not in L0 state. */
error_name_list{end+1} = 'DSL_ERR_L3_TIMED_OUT';
error_value_list(end+1) = -26;
%    /** CPE triggered L3 request has been rejected by the CO side. */
error_name_list{end+1} = 'DSL_ERR_L3_REJECTED';
error_value_list(end+1) = -25;
%    /** failed to get low level driver handle */
error_name_list{end+1} = 'DSL_ERR_LOWLEVEL_DRIVER_HANDLE';
error_value_list(end+1) = -24;
%    /** invalid direction */
error_name_list{end+1} = 'DSL_ERR_DIRECTION';
error_value_list(end+1) = -23;
%    /** invalid channel number is passed */
error_name_list{end+1} = 'DSL_ERR_CHANNEL_RANGE';
error_value_list(end+1) = -22;
%    /** function available only in the Showtime state */
error_name_list{end+1} = 'DSL_ERR_ONLY_AVAILABLE_IN_SHOWTIME';
error_value_list(end+1) = -21;
%    /** Device has no data for application */
error_name_list{end+1} = 'DSL_ERR_DEVICE_NO_DATA';
error_value_list(end+1) = -20;
%    /** Device is busy */
error_name_list{end+1} = 'DSL_ERR_DEVICE_BUSY';
error_value_list(end+1) = -19;
%    /** The answer from the device does not return within the specifies timeout */
error_name_list{end+1} = 'DSL_ERR_FUNCTION_WAITING_TIMEOUT';
error_value_list(end+1) = -18;
%    /** Last operation is supported if debug is enabled only error */
error_name_list{end+1} = 'DSL_ERR_ONLY_SUPPORTED_WITH_DEBUG_ENABLED';
error_value_list(end+1) = -17;
%    /** Semaphore lock error */
error_name_list{end+1} = 'DSL_ERR_SEMAPHORE_GET';
error_value_list(end+1) = -16;
%    /** Common error on send message and wait for answer handling */
error_name_list{end+1} = 'DSL_ERR_FUNCTION_WAITING';
error_value_list(end+1) = -15;
%    /** Message exchange error */
error_name_list{end+1} = 'DSL_ERR_MSG_EXCHANGE';
error_value_list(end+1) = -14;
%    /** Not implemented error */
error_name_list{end+1} = 'DSL_ERR_NOT_IMPLEMENTED';
error_value_list(end+1) = -13;
%    /** Internal error */
error_name_list{end+1} = 'DSL_ERR_INTERNAL';
error_value_list(end+1) = -12;
%    /** Feature or functionality not supported by device */
error_name_list{end+1} = 'DSL_ERR_NOT_SUPPORTED_BY_DEVICE';
error_value_list(end+1) = -11;
%    /** Feature or functionality not supported by firmware */
error_name_list{end+1} = 'DSL_ERR_NOT_SUPPORTED_BY_FIRMWARE';
error_value_list(end+1) = -10;
%    /** Feature or functionality not supported by DSL CPE API */
error_name_list{end+1} = 'DSL_ERR_NOT_SUPPORTED';
error_value_list(end+1) = -9;
%    /** function returned with timeout */
error_name_list{end+1} = 'DSL_ERR_TIMEOUT';
error_value_list(end+1) = -8;
%    /** invalid pointer */
error_name_list{end+1} = 'DSL_ERR_POINTER';
error_value_list(end+1) = -7;
%    /** invalid memory */
error_name_list{end+1} = 'DSL_ERR_MEMORY';
error_value_list(end+1) = -6;
%    /** file open failed */
error_name_list{end+1} = 'DSL_ERR_FILE_OPEN';
error_value_list(end+1) = -5;
%    /** file write failed */
error_name_list{end+1} = 'DSL_ERR_FILE_WRITE';
error_value_list(end+1) = -4;
%    /** file reading failed */
error_name_list{end+1} = 'DSL_ERR_FILE_READ';
error_value_list(end+1) = -3;
%    /** file close failed */
error_name_list{end+1} = 'DSL_ERR_FILE_CLOSE';
error_value_list(end+1) = -2;
%    /** Common error */
error_name_list{end+1} = 'DSL_ERROR';
error_value_list(end+1) = -1;
%    /** Success */
error_name_list{end+1} = 'DSL_SUCCESS';
error_value_list(end+1) = 0;
%    /* *********************************************************************** */
%    /* *** Warning Codes Start here !                                      *** */
%    /* *********************************************************************** */
%
%    /* *********************************************************************** */
%    /* *** Common Warning Codes                                            *** */
%    /* *********************************************************************** */
%    /** One or more parameters are truncated to min./max or next possible value */
error_name_list{end+1} = 'DSL_WRN_CONFIG_PARAM_TRUNCATED';
error_value_list(end+1) = 1;
%    /** DSL CPE API already initialized*/
error_name_list{end+1} = 'DSL_WRN_ALREADY_INITIALIZED';
error_value_list(end+1) = 2;
%    /** XTSE settings consist of unsupported bits. All unsupported bits removed,
%       configuration applied*/
error_name_list{end+1} = 'DSL_WRN_INCONSISTENT_XTSE_CONFIGURATION';
error_value_list(end+1) = 3;
%    /** One or more parameters are ignored */
error_name_list{end+1} = 'DSL_WRN_CONFIG_PARAM_IGNORED';
error_value_list(end+1) = 4;
%    /** This warning is used in case of an event was lost.
%    This could happen due to the following reasons
%    - polling cycle within polling based event handling is to slow
%    - system overload respective improper priorities within interrupt based
%      event handling
%    Also refer to "Event Handling" chapter within UMPR to get all the details. */
error_name_list{end+1} = 'DSL_WRN_EVENT_FIFO_OVERFLOW';
error_value_list(end+1)  = 5;
%    /** The ioctl function that has been used is deprecated.
%    Please do not use this function anymore. Refer to the according documentation
%    (release notes and/or User's Manual Programmer's Reference [UMPR]) of
%    the DSL CPE API to find the new function that has to be used. */
error_name_list{end+1} = 'DSL_WRN_DEPRECATED';
error_value_list(end+1)  = 6;
%    /** This warning occurs if the firmware did not accept the last message.
%       This may occur if the message is unknown or not allowed in the current
%       state. */
error_name_list{end+1} = 'DSL_WRN_FIRMWARE_MSG_DENIED';
error_value_list(end+1) = 9;
%    /** This warning occurs if no data available from the device. */
error_name_list{end+1} = 'DSL_WRN_DEVICE_NO_DATA';
error_value_list(end+1) = 10;
%    /** The requested functionality is not supported due to build configuration.
%        Please refer to the documentation for "Configure options for the DSL CPE
%        API Driver" */
error_name_list{end+1} = 'DSL_WRN_NOT_SUPPORTED_DUE_TO_BUILD_CONFIG';
error_value_list(end+1) = 13;
%    /** The performed API interface access is not allowed within current autoboot
%        state. */
error_name_list{end+1} = 'DSL_WRN_NOT_ALLOWED_IN_CURRENT_STATE';
error_value_list(end+1) = 14;
%    /** This warning occurs if there was a request of status information but not
%        all returned values includes updated data.
%        For example the ioctl \ref DSL_FIO_G997_LINE_STATUS_GET includes six
%        parameters that are returned and three of them are requested from far end
%        side via overhead channel. If this is not possible because of a not
%        responding CO this warning is returned and the according value will have
%        its special value.
%        The higher layer application shall check all returned values according
%        to its special value if this warning is returned. */
error_name_list{end+1} = 'DSL_WRN_INCOMPLETE_RETURN_VALUES';
error_value_list(end+1) = 15;
%    /** Some (or all) of the requested values are not supported in the current
%        ADSL mode or Annex*/
error_name_list{end+1} = 'DSL_WRN_NOT_SUPPORTED_IN_CURRENT_ADSL_MODE_OR_ANNEX';
error_value_list(end+1) = 16;
%    /** Not defined ADSL MIB flags detected*/
error_name_list{end+1} = 'DSL_WRN_INCONSISTENT_ADSL_MIB_FLAGS';
error_value_list(end+1) = 17;
%    /** Common warning to indicate some incompatibility in the used SW, FW or HW
%        versions*/
error_name_list{end+1} = 'DSL_WRN_VERSION_INCOMPATIBLE';
error_value_list(end+1) = 18;
%    /** Warning to indicate violation between Band Limits and actual borders*/
error_name_list{end+1} = 'DSL_WRN_FW_BB_STANDARD_VIOLATION';
error_value_list(end+1) = 19;
%    /** Warning to indicate not recommended configuration*/
error_name_list{end+1} = 'DSL_WRN_NOT_RECOMMENDED_CONFIG';
error_value_list(end+1) = 20;

%    /* *********************************************************************** */
%    /* *** PM related warning Codes                                        *** */
%    /* *********************************************************************** */
%    /** Performance Monitor thread was not able to receive showtime related
%        counter (TR-98) */
error_name_list{end+1} = 'DSL_WRN_PM_NO_SHOWTIME_DATA';
error_value_list(end+1) = 100;
%    /** Requested functionality not supported in the current PM Sync mode*/
error_name_list{end+1} = 'DSL_WRN_PM_NOT_ALLOWED_IN_CURRENT_SYNC_MODE';
error_value_list(end+1) = 101;
%    /** Previous External Trigger is not handled*/
error_name_list{end+1} = 'DSL_WRN_PM_PREVIOUS_EXTERNAL_TRIGGER_NOT_HANDLED';
error_value_list(end+1) = 102;
%
%    /** PM poll cycle not updated due to the active Burnin Mode. Poll cycle
%        configuration changes will be loaded automatically after disabling
%        Burnin Mode*/
error_name_list{end+1} = 'DSL_WRN_PM_POLL_CYCLE_NOT_UPDATED_IN_BURNIN_MODE';
error_value_list(end+1) = 103;

%    /* *********************************************************************** */
%    /* *** SNMP/EOC related warning Codes                                 *** */
%    /* *********************************************************************** */
%    /** CEOC Rx SNMP fifo of DSL CPE API is empty or firmware does not provide
%        any data with interrupt. */
error_name_list{end+1} = 'DSL_WRN_SNMP_NO_DATA';
error_value_list(end+1) = 200;
%    /** Currently the only protocol that is handled by the DSL CPE API is
%        SNMP (0x814C) */
error_name_list{end+1} = 'DSL_WRN_EOC_UNSUPPORTED_PROTOCOLL_ID';
error_value_list(end+1) = 201;

%    /* *********************************************************************** */
%    /* *** Warning Codes for configuration parameter consistency check     *** */
%    /* *********************************************************************** */
%    /** This warning code is not used anymore. */
error_name_list{end+1} = 'DSL_WRN_CONFIG_BND_VS_RETX';
error_value_list(end+1) = 400;
%    /** The configuration of the TC-Layer does not fit to the bonding
%        configuration. Due to the fact that PAF bonding is only supported
%        within PTM/EFM TC-Layer please note that in case of enabled bonding
%        support (CLI: "BND_ConfigSet"/"bndcs") the TC-Layer configuration (of the
%        DSL Firmware) will be set to fixed PTM/EFM operation.
%        This warning will occur in case of bonding is enabled and user
%        configuration of \ref DSL_TC_AUTO is applied or vice versa. The
%        configuration is accepted but during link configuration only PTM/EFM
%        is enabled. */
error_name_list{end+1} = 'DSL_WRN_CONFIG_BND_VS_TCLAYER';
error_value_list(end+1) = 401;
%    /** The configuration parameter for upstream (US) direction can be only
%        enabled if according downstream (DS) value is enabled. In this case
%        the configuration to enable upstream RTX was discared. Please enable
%        RTX for downstream first! */
error_name_list{end+1} = 'DSL_WRN_CONFIG_RTX_US_ONLY_SUPPORTED_WITH_DS_ENABLED';
error_value_list(end+1) = 402;
%    /* *********************************************************************** */
%    /* *** Bonding functionality related warning codes                     *** */
%    /* *********************************************************************** */
%    /** The DSL PHY Firmware does not support bonding but bonding is required
%        from DSL CPE API compilation and configuration point of view.
%        In this case the DSL CPE API is compiled for bonding and one of the
%        following cases apply
%        - bonding is enabled while changing the firmware binary which does not
%          support bonding (related CLI command: "alf")
%        - a firmware is running that does not support bonding and a
%          configuration change to enable bonding will be done (related CLI
%          command: "bndcs")
%        In both above cases bonding is *not* activated within firmware
%        configuration handling. This means that the bonding enable configuration
%        is ignored.
%        In case of on-chip bonding the firmware is started in single port mode
%        and only line 0 is accessible. */
error_name_list{end+1} = 'DSL_WRN_BND_NOT_SUPPORTED_BY_FIRMWARE';
error_value_list(end+1) = 500;

% %    /* Last warning code marker */
% error_name_list{end+1} = 'DSL_WRN_LAST';
% error_value_list(end+1) = 10000;

% % FIXME these are error codes not described in the lantiq
% % drv_dsl_cpe_api_error.h file but encountered from the driver
% % to make this still run, manually add the respective error/warning codes
% % with the appropriate DSL_ERR/DSL_WRN prefixes
% % -45 added in the correct fashion
% %error_name_list{end+1} = 'DSL_ERR_ERRORCODE_UNKNOWN_IN_OLD_API_DOCUMENTATION';
% %error_value_list(end+1) = -45;

error_code_struct.error_name_list = error_name_list;
error_code_struct.error_value_list = error_value_list;

return
end

function [ string_from_hex_char_string ] = fn_convert_string_of_hex_to_string( hex_char_string, delimiter )

string_from_hex_char_string = '';

processed_hex_char_string = [delimiter, hex_char_string];

while length(processed_hex_char_string) > 0
	[current_hex_char, processed_hex_char_string] = strtok(processed_hex_char_string(2:end), delimiter);
	
	string_from_hex_char_string = [string_from_hex_char_string, char(hex2dec(current_hex_char))];
end

return
end
