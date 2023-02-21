create_project -in memory
set_property part xc7z020clg484-1 [current_project]
read_ip charLib.xci
upgrade_ip [get_ips charLib]