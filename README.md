# lantiq_dsl_parser
Simple parser for the output of intel/lantiq dsl modem diagnostics/statistics

The idea is to use ssh to execute dsl_pipe (or dsl_cmd on OpenWrt hosts) to collect diagnostic and statistics data from lantiq/intel dsl modems, store the data, and create simple overview plots, like SNR, HLog, QLN per frequency bin as well as bitloading per frequency. This uses matlab or octave expects that the modem device is accesible via passwordless ssh.
