create_project -in memory
set_property part xc7z020clg484-1 [current_project]
read_ip init_sequence_rom.xci
upgrade_ip [get_ips init_sequence_rom]