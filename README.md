# lantiq_dsl_parser
Simple parser for the output of intel/lantiq dsl modem diagnostics/statistics

The idea is to use ssh to execute dsl_pipe (or dsl_cmd on OpenWrt hosts) to collect diagnostic and statistics data from lantiq/intel dsl modems, store the data, and create simple overview plots, like SNR, HLog, QLN per frequency bin as well as bitloading per frequency. This uses matlab or octave expects that the modem device is accesible via passwordless ssh.

Before running this, please edit the following section:
```
ssh_dsl_cfg.lantiq_IP = '192.168.100.1';
ssh_dsl_cfg.lantig_user = 'root';
ssh_dsl_cfg.lantig_dsl_cmd_prefix = '. /lib/functions/lantiq_dsl.sh ; dsl_cmd';
ssh_dsl_cfg.ssh_command_stem = ['ssh ', ssh_dsl_cfg.lantig_user, '@', ssh_dsl_cfg.lantiq_IP];
```
to reflect your own situation.


Please note that without passwordless ssh access configured between collection host and modem host, this will ask for the modem-host's password for every collection item, which effectively makes this unusable.
Testing so far:

OS: 
macosx, Linux

Link Type: 
VDSL2 (G993.5, VDSL2 Vectoring)

Software: 
Matlab 2016a, Octave (5.1.0, 4.2.2)


See https://github.com/moeller0/lantiq_dsl_parser/wiki for examples
