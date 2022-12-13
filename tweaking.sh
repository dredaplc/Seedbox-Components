#!/bin/sh

## CPU
function CPU_Tweaking {
    normal_1; echo "Optimizing CPU"; normal_2
    apt-get -qqy install tuned
    warn_2
    mkdir /etc/tuned/profile
    touch /etc/tuned/profile/tuned.conf
    cat << EOF >/etc/tuned/profile/tuned.conf
[main]
#CPU & Scheduler Optimization
[cpu]
governor=performance
energy_perf_bias=performance
min_perf_pct=100

[disk]
readahead=4096

[bootloader]
cmdline=skew_tick=1
EOF

    tuned-adm profile profile
}


## Network
#NIC Config
function NIC_Tweaking {
    normal_1; echo "Optimizing NIC Configuration"
    warn_1; echo "Some Configurations might not be supported by the NIC"; warn_2
    interface=$(ip -o -4 route show to default | awk '{print $5}')
    ethtool -K $interface tso on gso off
    sleep 1
}
function Network_Other_Tweaking {
    normal_1; echo "Doing other Network Tweaking"; warn_2
    #Other 1
    apt-get -qqy install net-tools
    ifconfig $interface txqueuelen 10000
    sleep 1
    #Other 2
    iproute=$(ip -o -4 route show to default)
    ip route change $iproute initcwnd 25 initrwnd 25
}


## Drive
#Scheduler
function Scheduler_Tweaking {
    normal_1; echo "Changing I/O Scheduler"; warn_2
    i=1
    drive=()
    disk=$(lsblk -nd --output NAME)
    diskno=$(echo $disk | awk '{print NF}')
    while [ $i -le $diskno ]
    do
	    device=$(echo $disk | awk -v i=$i '{print $i}')
	    drive+=($device)
	    i=$(( $i + 1 ))
    done
    i=1
    x=0
    disktype=$(cat /sys/block/sda/queue/rotational)
    if [ "${disktype}" == 0 ]; then
	    while [ $i -le $diskno ]
	    do
		    diskname=$(eval echo ${drive["$x"]})
		    echo kyber > /sys/block/$diskname/queue/scheduler
		    i=$(( $i + 1 ))
		    x=$(( $x + 1 ))
	    done
    else
	    while [ $i -le $diskno ]
	    do
		    diskname=$(eval echo ${drive["$x"]})
		    echo mq-deadline > /sys/block/$diskname/queue/scheduler
		    i=$(( $i + 1 ))
		    x=$(( $x + 1 ))
	    done
    fi
}


## File Open Limit
function file_open_limit_Tweaking {
    normal_1; echo "Configuring File Open Limit"; warn_2
    cat << EOF >>/etc/security/limits.conf
## Hard limit for max opened files
$username        hard nofile 1048576
## Soft limit for max opened files
$username        soft nofile 1048576
EOF
}


## BBR
function Tweaked_BBR {
    wget https://raw.githubusercontent.com/jerry048/Seedbox-Components/main/Miscellaneous/BBR/BBR.sh && chmod +x BBR.sh
    ## Install tweaked BBR automatically on reboot
    cat << EOF > /etc/systemd/system/bbrinstall.service
[Unit]
Description=BBRinstall
After=network.target

[Service]
Type=oneshot
ExecStart=/root/BBR.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
    systemctl enable bbrinstall.service && bbrx=1
}


## Deluge

#Deluge Libtorrent Config
function Deluge_libtorrent {
    normal_1; echo "Configuring Deluge Libtorrent Settings"; warn_2
    systemctl stop deluged@$username
    cat << EOF >/home/$username/.config/deluge/ltconfig.conf
{
  "file": 1, 
  "format": 1
}{
  "apply_on_start": true, 
  "settings": {
    "default_cache_min_age": 10, 
    "connection_speed": 500, 
    "connections_limit": 500000, 
    "guided_read_cache": true, 
    "max_rejects": 100, 
    "inactivity_timeout": 120, 
    "active_seeds": -1, 
    "max_failcount": 20, 
    "allowed_fast_set_size": 0, 
    "max_allowed_in_request_queue": 10000, 
    "enable_incoming_utp": false, 
    "unchoke_slots_limit": -1, 
    "peer_timeout": 120, 
    "peer_connect_timeout": 30,
    "handshake_timeout": 30,
    "request_timeout": 5, 
    "allow_multiple_connections_per_ip": true, 
    "use_parole_mode": false, 
    "piece_timeout": 5, 
    "tick_interval": 100, 
    "active_limit": -1, 
    "connect_seed_every_n_download": 50, 
    "file_pool_size": 5000, 
    "cache_expiry": 300, 
    "seed_choking_algorithm": 1, 
    "max_out_request_queue": 10000, 
    "send_buffer_watermark": 10485760, 
    "send_buffer_watermark_factor": 200, 
    "active_tracker_limit": -1, 
    "send_buffer_low_watermark": 3145728, 
    "mixed_mode_algorithm": 0, 
    "max_queued_disk_bytes": 10485760, 
    "min_reconnect_time": 2,  
    "aio_threads": 4, 
    "write_cache_line_size": 256, 
    "torrent_connect_boost": 100, 
    "listen_queue_size": 3000, 
    "cache_buffer_chunk_size": 256, 
    "suggest_mode": 1, 
    "request_queue_time": 5, 
    "strict_end_game_mode": false, 
    "use_disk_cache_pool": true, 
    "predictive_piece_announce": 10, 
    "prefer_rc4": false, 
    "whole_pieces_threshold": 5, 
    "read_cache_line_size": 128, 
    "initial_picker_threshold": 10, 
    "enable_outgoing_utp": false, 
    "cache_size": $Cache1, 
    "low_prio_disk": false
  }
}
EOF
    systemctl start deluged@$username
}

